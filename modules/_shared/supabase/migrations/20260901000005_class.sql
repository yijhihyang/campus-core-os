-- 班級表（含 class_code v2、class_type）
CREATE TABLE public.class (
    class_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    class_name text NOT NULL,
    teacher_id uuid NOT NULL REFERENCES public.teacher(teacher_id),
    classroom_id uuid REFERENCES public.classroom(classroom_id),
    academic_year text NOT NULL,
    semester text NOT NULL CHECK (semester = ANY (ARRAY['上','下','暑期','寒期'])),
    max_capacity integer,
    tuition_override numeric,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    standard_price numeric NOT NULL DEFAULT 3000,
    material_fee numeric NOT NULL DEFAULT 200,
    grade text NOT NULL REFERENCES public.config_class_grade(name),
    subject text NOT NULL REFERENCES public.config_subject(name),
    class_code text UNIQUE,
    class_type text REFERENCES public.config_class_type(name)
);

COMMENT ON COLUMN public.class.class_code IS '班級代碼，格式：學年度+年級代碼+科目代碼+"-"+班別字母+類型代碼，例如 115G7MATH-A01（115學年國一數學A班-進度班）。班別字母(A/B/C...)依「同學年度+同年級+同科目」組合，按建立時間先後自動編號，不綁定老師（老師異動時直接更新 teacher_id，不影響班別字母）。新增班級時若未指定 class_code 會自動產生，也可手動覆寫指定班別字母。';
COMMENT ON COLUMN public.class.class_type IS '班級類型：進度／總複習／輔導，對應 config_class_type';

ALTER TABLE public.class ENABLE ROW LEVEL SECURITY;

-- 新增班級時，若未指定 max_capacity，自動帶入該教室的容量上限
CREATE OR REPLACE FUNCTION public.fn_class_default_capacity()
RETURNS trigger AS $$
BEGIN
    IF NEW.max_capacity IS NULL THEN
        NEW.max_capacity := (
            SELECT capacity
            FROM classroom
            WHERE classroom_id = NEW.classroom_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_class_default_capacity
BEFORE INSERT ON public.class
FOR EACH ROW EXECUTE FUNCTION public.fn_class_default_capacity();

-- 自動產生 class_code（v2：學年度+年級代碼+科目代碼+"-"+班別字母+類型代碼）
CREATE OR REPLACE FUNCTION public.generate_class_code()
RETURNS trigger AS $$
DECLARE
  v_grade_code text;
  v_subject_code text;
  v_type_code text;
  v_seq int;
  v_letter text;
BEGIN
  IF NEW.class_code IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT grade_code INTO v_grade_code FROM public.config_class_grade WHERE name = NEW.grade;
  SELECT subject_code INTO v_subject_code FROM public.config_subject WHERE name = NEW.subject;

  IF v_grade_code IS NULL OR v_subject_code IS NULL THEN
    RAISE EXCEPTION '找不到對應的年級代碼或科目代碼，請確認 config_class_grade / config_subject 是否已設定 grade_code / subject_code';
  END IF;

  IF NEW.class_type IS NOT NULL THEN
    SELECT type_code INTO v_type_code FROM public.config_class_type WHERE name = NEW.class_type;
    IF v_type_code IS NULL THEN
      RAISE EXCEPTION '找不到對應的班級類型代碼，請確認 config_class_type 是否已設定 type_code';
    END IF;
  ELSE
    v_type_code := '00';
  END IF;

  -- 班別字母依「同學年度 + 同年級 + 同科目」分組，按建立時間先後編號，每學年重新從 A 起算
  -- （一個 class 列代表整學年的班級身份，學期中老師異動直接更新 teacher_id，
  --  不會產生新的 class 列，所以下一個學年度視為全新的一批班級）
  SELECT COUNT(*) + 1 INTO v_seq
  FROM public.class
  WHERE academic_year = NEW.academic_year AND grade = NEW.grade AND subject = NEW.subject;

  v_letter := chr(64 + v_seq);

  NEW.class_code := NEW.academic_year || v_grade_code || v_subject_code || '-' || v_letter || v_type_code;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.generate_class_code() IS 'v2：格式為 學年度+年級代碼+科目代碼+"-"+班別字母+類型代碼(例如115G7MATH-A01)。班別字母依(academic_year, grade, subject)分組，按建立時間排序自動編號，每學年重新從A起算，不綁定授課老師。';

CREATE TRIGGER trg_generate_class_code
BEFORE INSERT ON public.class
FOR EACH ROW EXECUTE FUNCTION public.generate_class_code();

-- 方便查詢的班級摘要視圖
CREATE VIEW public.v_class AS
SELECT c.class_id, c.created_at, c.grade, c.subject, c.teacher_id, t.name AS teacher_name,
       (c.grade || c.subject || t.name || '班') AS class_name
FROM public.class c
JOIN public.teacher t ON (c.teacher_id = t.teacher_id);
