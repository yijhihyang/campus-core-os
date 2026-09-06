-- 餐點 / 訂餐 / 到校打卡
-- ⚠️ 這 4 張表目前 RLS 未啟用，正式上線前必須先設計好 policy 才能啟用，
-- 否則任何拿到 anon key 的人都能直接讀寫所有資料
CREATE TABLE public.meals (
    meal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    price numeric NOT NULL,
    available_date date NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.meals IS '每日可供選擇的餐點';

CREATE TABLE public.meal_orders (
    order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.student(student_id) ON DELETE CASCADE,
    order_date date NOT NULL,
    meal_id uuid REFERENCES public.meals(meal_id),
    final_price numeric,
    picked_up boolean NOT NULL DEFAULT false,
    picked_at timestamptz,
    note text,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.meal_orders IS '學生訂餐與取餐紀錄';

CREATE TABLE public.attendance (
    attendance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.student(student_id) ON DELETE CASCADE,
    date date NOT NULL,
    punched_at timestamptz,
    status text NOT NULL DEFAULT 'absent',
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, date)
);
COMMENT ON TABLE public.attendance IS '學生到校打卡紀錄';

CREATE TABLE public.scan_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid REFERENCES public.student(student_id),
    student_name text,
    grade text,
    has_order boolean DEFAULT false,
    order_id uuid REFERENCES public.meal_orders(order_id),
    scanned_at timestamptz DEFAULT now()
);
