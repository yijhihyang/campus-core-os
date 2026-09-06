-- 設定類小表：年級、科目、班級類型選項（含代碼欄位）
CREATE TABLE public.config_class_grade (
    id serial PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    name text NOT NULL UNIQUE,
    grade_code text NOT NULL UNIQUE
);
COMMENT ON COLUMN public.config_class_grade.grade_code IS '年級英文代碼，用於組成 class.class_code';
ALTER TABLE public.config_class_grade ENABLE ROW LEVEL SECURITY;

INSERT INTO public.config_class_grade (name, grade_code) VALUES
  ('小四', 'E4'), ('小五', 'E5'), ('小六', 'E6'),
  ('國一', 'G7'), ('國二', 'G8'), ('國三', 'G9'),
  ('高一', 'G10'), ('高二', 'G11'), ('高三', 'G12');

CREATE TABLE public.config_subject (
    id serial PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    name text NOT NULL UNIQUE,
    subject_code text NOT NULL UNIQUE
);
COMMENT ON COLUMN public.config_subject.subject_code IS '科目英文代碼，用於組成 class.class_code';
ALTER TABLE public.config_subject ENABLE ROW LEVEL SECURITY;

INSERT INTO public.config_subject (name, subject_code) VALUES
  ('國文', 'CHI'), ('英文', 'ENG'), ('數學', 'MATH'),
  ('生物', 'BIO'), ('理化', 'SCI'), ('地科', 'EARTH'), ('社會', 'SOC');

-- ⚠️ 目前 RLS 未啟用，正式上線前需評估是否啟用
CREATE TABLE public.config_class_type (
    id serial PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    name text NOT NULL UNIQUE,
    type_code text NOT NULL UNIQUE
);
COMMENT ON TABLE public.config_class_type IS '班級類型選項：進度課、總複習、輔導課等，用於區分同年級科目下不同性質的班級';
COMMENT ON COLUMN public.config_class_type.type_code IS '班級類型二碼代碼，用於組成 class.class_code 結尾兩碼';

INSERT INTO public.config_class_type (name, type_code) VALUES
  ('進度', '01'), ('輔導', '02'), ('總複習', '03');

-- 年級同義詞對照表（⚠️ 目前 RLS 未啟用）
CREATE TABLE public.config_grade_alias (
    id serial PRIMARY KEY,
    alias text NOT NULL UNIQUE,
    standard_grade text NOT NULL REFERENCES public.config_class_grade(name),
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.config_grade_alias IS '老師寫信時各種年級寫法的同義詞對照，用於將 email_message.parsed_course_text 標準化成 config_class_grade.name';

INSERT INTO public.config_grade_alias (alias, standard_grade) VALUES
  ('國一', '國一'), ('七年級', '國一'), ('7年級', '國一'), ('國1', '國一'), ('國七', '國一'), ('國7', '國一'),
  ('國二', '國二'), ('八年級', '國二'), ('8年級', '國二'), ('國2', '國二'), ('國八', '國二'), ('國8', '國二'),
  ('國三', '國三'), ('九年級', '國三'), ('9年級', '國三'), ('國3', '國三'), ('國九', '國三'), ('國9', '國三');

-- 科目同義詞對照表（⚠️ 目前 RLS 未啟用）
-- 所有單一字元同義詞（數/生/地/理/社/自）一律視為模糊，不自動判斷，避免「理」誤配到「物理」這類問題
CREATE TABLE public.config_subject_alias (
    id serial PRIMARY KEY,
    alias text NOT NULL UNIQUE,
    standard_subject text REFERENCES public.config_subject(name),
    is_ambiguous boolean NOT NULL DEFAULT false,
    note text,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.config_subject_alias IS '老師寫信時各種科目寫法的同義詞對照。is_ambiguous=true 代表無法唯一判斷對應科目，此類需交由人工在考卷檔案中心手動指定，不自動比對。';

INSERT INTO public.config_subject_alias (alias, standard_subject, is_ambiguous, note) VALUES
  ('國文', '國文', false, NULL),
  ('國語', '國文', false, NULL),
  ('語文', '國文', false, NULL),
  ('數學', '數學', false, NULL),
  ('生物', '生物', false, NULL),
  ('地球科學', '地科', false, NULL),
  ('地科', '地科', false, NULL),
  ('理化', '理化', false, NULL),
  ('社會', '社會', false, NULL),
  ('自然', NULL, true, '可能是生物、理化或地科，無法自動判斷，需人工確認'),
  ('數', NULL, true, '單一字元同義詞，容易與其他詞彙混淆，一律不自動判斷，需人工確認'),
  ('生', NULL, true, '單一字元同義詞，容易與其他詞彙混淆，一律不自動判斷，需人工確認'),
  ('地', NULL, true, '單一字元同義詞，容易與其他詞彙混淆，一律不自動判斷，需人工確認'),
  ('理', NULL, true, '單一字元同義詞，容易與其他詞彙混淆，一律不自動判斷，需人工確認'),
  ('社', NULL, true, '單一字元同義詞，容易與其他詞彙混淆，一律不自動判斷，需人工確認'),
  ('自', NULL, true, '單一字元同義詞，容易與其他詞彙混淆，一律不自動判斷，需人工確認');
