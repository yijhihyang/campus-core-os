-- 班級排表 / 場次 / 報名
CREATE TABLE public.class_schedule (
    schedule_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    class_id uuid NOT NULL REFERENCES public.class(class_id) ON DELETE CASCADE,
    day_of_week text NOT NULL CHECK (day_of_week = ANY (ARRAY['一','二','三','四','五','六','日'])),
    start_time time NOT NULL,
    end_time time NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    date date
);
ALTER TABLE public.class_schedule ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.enrollment (
    enrollment_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    student_id uuid NOT NULL REFERENCES public.student(student_id),
    class_id uuid NOT NULL REFERENCES public.class(class_id),
    current_status enrollment_status NOT NULL DEFAULT '試聽',
    enroll_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, class_id)
);
COMMENT ON CONSTRAINT enrollment_student_id_class_id_key ON public.enrollment IS '同一學生對同一具體班級只能有一筆選課記錄。狀態變化透過更新 current_status 處理，不新增重複記錄；歷史軌跡見 enrollment_log。若學生選了不同學期/不同 class_id 的班級，因 class_id 不同不受此限制影響。';
ALTER TABLE public.enrollment ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.class_session (
    session_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    class_id uuid NOT NULL REFERENCES public.class(class_id),
    session_date date NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    progress text,
    homework text,
    next_exam text,
    created_by uuid REFERENCES public.teacher(teacher_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (class_id, session_date)
);
ALTER TABLE public.class_session ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.enrollment_log (
    history_id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    enrollment_id uuid NOT NULL REFERENCES public.enrollment(enrollment_id),
    status_type enrollment_status NOT NULL,
    change_at timestamptz NOT NULL DEFAULT now(),
    operator_id uuid REFERENCES public.staff(staff_id),
    remark text
);
ALTER TABLE public.enrollment_log ENABLE ROW LEVEL SECURITY;

-- 自動記錄選課狀態變化歷史：新增選課時記錄初始狀態；current_status 有變化時自動新增一筆
-- operator_id / remark 無法自動得知，需前端另外補上該筆記錄
CREATE OR REPLACE FUNCTION public.fn_log_enrollment_change()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO enrollment_log (enrollment_id, status_type)
        VALUES (NEW.enrollment_id, NEW.current_status);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.current_status IS DISTINCT FROM NEW.current_status THEN
        INSERT INTO enrollment_log (enrollment_id, status_type)
        VALUES (NEW.enrollment_id, NEW.current_status);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enrollment_log
AFTER INSERT OR UPDATE ON public.enrollment
FOR EACH ROW EXECUTE FUNCTION public.fn_log_enrollment_change();
