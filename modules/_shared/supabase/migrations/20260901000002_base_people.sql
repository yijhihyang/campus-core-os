-- 基礎人員表：staff, teacher, student, classroom
CREATE TABLE public.staff (
    staff_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name text NOT NULL,
    email text UNIQUE,
    phone text,
    line_id text,
    role staff_role NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.teacher (
    teacher_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name text NOT NULL,
    email text UNIQUE,
    phone text,
    line_id text,
    avatar_url text,
    bio text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.teacher ENABLE ROW LEVEL SECURITY;

-- ⚠️ student 表目前 RLS 未啟用（見開發環境現況），正式上線前需設計好 policy 後啟用
CREATE TABLE public.student (
    student_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name text NOT NULL,
    email text UNIQUE,
    phone text,
    line_id text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    school_name text,
    entry_year integer,
    card_uid text UNIQUE
);
COMMENT ON COLUMN public.student.entry_year IS 'as you know the entrance_year of a student, you know his/her grade = this_year - entrance_year +1';
COMMENT ON COLUMN public.student.card_uid IS '讀卡機 HID 輸出的卡號字串';

CREATE TABLE public.classroom (
    classroom_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name text NOT NULL UNIQUE,
    capacity integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.classroom ENABLE ROW LEVEL SECURITY;
