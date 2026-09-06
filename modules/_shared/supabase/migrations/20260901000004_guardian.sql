-- 家長表（v2：去重複，一位家長只存一筆，不因多個小孩重複建檔）
CREATE TABLE public.guardian (
    guardian_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name text NOT NULL,
    phone text,
    line_id text,
    email text,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.guardian IS '家長本人資料（去重複，一位家長只存一筆，不因多個小孩而重複建檔）';
ALTER TABLE public.guardian ENABLE ROW LEVEL SECURITY;

-- 學生與家長的多對多關聯中間表
CREATE TABLE public.student_guardian (
    id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    student_id uuid NOT NULL REFERENCES public.student(student_id),
    guardian_id uuid NOT NULL REFERENCES public.guardian(guardian_id),
    relationship text NOT NULL,
    is_primary boolean NOT NULL DEFAULT false,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, guardian_id)
);
COMMENT ON TABLE public.student_guardian IS '學生與家長的多對多關聯中間表。relationship/is_primary 存在這裡而非 guardian 表，因為同一位家長對不同學生的關係可能不同（例如混合家庭）';
ALTER TABLE public.student_guardian ENABLE ROW LEVEL SECURITY;
