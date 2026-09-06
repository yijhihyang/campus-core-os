-- 課前卷自動歸檔模組
CREATE TABLE public.email_message (
    id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    gmail_message_id text UNIQUE,
    raw_sender text,
    sender_email text,
    raw_subject text,
    parsed_date_text text,
    parsed_course_text text,
    received_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    normalized_grade text REFERENCES public.config_class_grade(name),
    normalized_subject text REFERENCES public.config_subject(name),
    subject_ambiguous boolean NOT NULL DEFAULT false,
    normalized_date date
);
COMMENT ON COLUMN public.email_message.normalized_grade IS '標準化後的年級，透過 config_grade_alias 比對 parsed_course_text 得出，比對用這個欄位，不要直接用 parsed_course_text';
COMMENT ON COLUMN public.email_message.normalized_subject IS '標準化後的科目，透過 config_subject_alias 比對得出；若比對到模糊詞（如「自然」）則為 NULL，見 subject_ambiguous';
COMMENT ON COLUMN public.email_message.subject_ambiguous IS 'true 代表科目無法自動判斷（例如信件寫「自然」），需人工在考卷檔案中心手動指定科目後才能完成比對';
COMMENT ON COLUMN public.email_message.normalized_date IS '標準化後的課程日期，從 raw_subject 解析多種格式（含民國年、中文日期、無分隔數字等）自動換算而來。原始文字不易讀，比對/查詢一律使用這個欄位。';
ALTER TABLE public.email_message ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.email_attachment (
    id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    email_message_id uuid NOT NULL REFERENCES public.email_message(id),
    drive_file_id text,
    original_filename text,
    mime_type text,
    created_at timestamptz NOT NULL DEFAULT now(),
    class_code text REFERENCES public.class(class_code)
);
COMMENT ON COLUMN public.email_attachment.class_code IS 'Resolve 比對後寫入，對應到具體班級。比對邏輯：email_message.sender_email 找到 teacher，再用 parsed_course_text 模糊比對 class.grade+subject，取得對應 class_code。⚠️ 此欄位目前尚未有任何自動寫入邏輯，Resolve 步驟還未實作。';
ALTER TABLE public.email_attachment ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.module_config (
    id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    module_name text NOT NULL UNIQUE,
    is_enabled boolean NOT NULL DEFAULT true,
    last_run_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.module_config ENABLE ROW LEVEL SECURITY;

INSERT INTO public.module_config (module_name, is_enabled) VALUES ('email_auto_archive', true);

-- 即時關聯視圖：不做快照儲存，避免資料脫節。session_date 目前用信件收件日期近似，
-- 待 Resolve 邏輯確定能精準比對到具體 class_session 後，應改為 JOIN class_session.session_date
CREATE VIEW public.v_email_attachment_detail AS
SELECT
  ea.id AS attachment_id,
  ea.email_message_id,
  ea.class_code,
  c.class_name,
  t.name AS teacher_name,
  em.received_at::date AS session_date,
  ea.original_filename,
  ea.drive_file_id,
  ea.mime_type,
  em.sender_email,
  em.raw_subject,
  em.parsed_course_text,
  em.parsed_date_text,
  em.received_at,
  ea.created_at
FROM public.email_attachment ea
JOIN public.email_message em ON em.id = ea.email_message_id
LEFT JOIN public.class c ON c.class_code = ea.class_code
LEFT JOIN public.teacher t ON t.teacher_id = c.teacher_id;

-- Resolve：寫入 email_message 時自動標準化年級/科目（token 完全比對優先，
-- 子字串比對排除長度1的同義詞，避免「理」誤配「物理」這類問題）
CREATE OR REPLACE FUNCTION public.resolve_normalized_grade_subject()
RETURNS trigger AS $$
DECLARE
  v_tokens text[];
  v_subject_standard text;
  v_subject_ambiguous boolean;
BEGIN
  v_tokens := regexp_split_to_array(trim(NEW.parsed_course_text), '\s+|,|、');

  SELECT standard_grade INTO NEW.normalized_grade
  FROM public.config_grade_alias
  WHERE alias = ANY(v_tokens)
  ORDER BY length(alias) DESC LIMIT 1;

  IF NEW.normalized_grade IS NULL THEN
    SELECT standard_grade INTO NEW.normalized_grade
    FROM public.config_grade_alias
    WHERE NEW.parsed_course_text ILIKE '%' || alias || '%' AND length(alias) >= 2
    ORDER BY length(alias) DESC LIMIT 1;
  END IF;

  SELECT standard_subject, is_ambiguous INTO v_subject_standard, v_subject_ambiguous
  FROM public.config_subject_alias
  WHERE alias = ANY(v_tokens)
  ORDER BY length(alias) DESC LIMIT 1;

  IF NOT FOUND THEN
    SELECT standard_subject, is_ambiguous INTO v_subject_standard, v_subject_ambiguous
    FROM public.config_subject_alias
    WHERE NEW.parsed_course_text ILIKE '%' || alias || '%' AND length(alias) >= 2
    ORDER BY length(alias) DESC LIMIT 1;
  END IF;

  IF FOUND THEN
    NEW.normalized_subject := v_subject_standard;
    NEW.subject_ambiguous := v_subject_ambiguous;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_resolve_grade_subject
BEFORE INSERT OR UPDATE OF parsed_course_text ON public.email_message
FOR EACH ROW EXECUTE FUNCTION public.resolve_normalized_grade_subject();

-- Resolve：從 raw_subject 解析出標準化日期，依序嘗試多種格式，
-- 第一個通過月份(1-12)/日期(1-31)合理範圍驗證的就採用
CREATE OR REPLACE FUNCTION public.resolve_normalized_date()
RETURNS trigger AS $$
DECLARE
  m text[];
  v_year int;
  v_month int;
  v_day int;
  v_received_year int;
BEGIN
  v_received_year := EXTRACT(YEAR FROM COALESCE(NEW.received_at, now()))::int;
  NEW.normalized_date := NULL;

  -- 1. 中文格式：（民國年or西元年）年 月 日，年可省略
  m := regexp_match(NEW.raw_subject, '(?:(\d{2,4})年)?(\d{1,2})月(\d{1,2})日');
  IF m IS NOT NULL THEN
    v_month := m[2]::int;
    v_day := m[3]::int;
    v_year := CASE
      WHEN m[1] IS NULL THEN v_received_year
      WHEN m[1]::int < 1000 THEN m[1]::int + 1911
      ELSE m[1]::int
    END;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  -- 2. 8 碼西元年 YYYYMMDD（限 19xx/20xx 開頭，避免誤判其他數字）
  m := regexp_match(NEW.raw_subject, '(20\d{2}|19\d{2})(\d{2})(\d{2})');
  IF m IS NOT NULL THEN
    v_year := m[1]::int; v_month := m[2]::int; v_day := m[3]::int;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  -- 3. 年/月/日 斜線或連字號分隔（西元4碼或民國3碼年）
  m := regexp_match(NEW.raw_subject, '(\d{3,4})[\/\-](\d{1,2})[\/\-](\d{1,2})(?!\d)');
  IF m IS NOT NULL THEN
    v_year := CASE WHEN m[1]::int < 1000 THEN m[1]::int + 1911 ELSE m[1]::int END;
    v_month := m[2]::int; v_day := m[3]::int;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  -- 4. 年/月日合併（例如 2026/0901、115/0901）
  m := regexp_match(NEW.raw_subject, '(\d{3,4})[\/\-](\d{4})(?!\d)');
  IF m IS NOT NULL THEN
    v_year := CASE WHEN m[1]::int < 1000 THEN m[1]::int + 1911 ELSE m[1]::int END;
    v_month := substring(m[2] from 1 for 2)::int;
    v_day := substring(m[2] from 3 for 2)::int;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  -- 5. 7 碼民國年 (3碼年)+MMDD，無分隔符
  m := regexp_match(NEW.raw_subject, '(?<!\d)(\d{3})(\d{2})(\d{2})(?!\d)');
  IF m IS NOT NULL THEN
    v_year := m[1]::int + 1911; v_month := m[2]::int; v_day := m[3]::int;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  -- 6. 月/日 無年份，斜線分隔（假設為收件年份）
  m := regexp_match(NEW.raw_subject, '(?<!\d)(\d{1,2})[\/\-](\d{1,2})(?!\d)');
  IF m IS NOT NULL THEN
    v_month := m[1]::int; v_day := m[2]::int;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_received_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  -- 7. 純 4 碼無分隔 MMDD（假設為收件年份，最後手段，最容易誤判故排最後）
  m := regexp_match(NEW.raw_subject, '(?<!\d)(\d{2})(\d{2})(?!\d)');
  IF m IS NOT NULL THEN
    v_month := m[1]::int; v_day := m[2]::int;
    IF v_month BETWEEN 1 AND 12 AND v_day BETWEEN 1 AND 31 THEN
      BEGIN
        NEW.normalized_date := make_date(v_received_year, v_month, v_day);
        RETURN NEW;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_resolve_date
BEFORE INSERT OR UPDATE OF raw_subject, received_at ON public.email_message
FOR EACH ROW EXECUTE FUNCTION public.resolve_normalized_date();
