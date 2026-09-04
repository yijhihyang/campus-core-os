-- ============================================================
-- 智慧取餐系統 Schema
-- 請在 Supabase SQL Editor 執行此檔案
-- ============================================================

-- Step 1: 在 student table 新增 card_uid 欄位
alter table student
  add column if not exists card_uid text unique;

comment on column student.card_uid is '讀卡機 HID 輸出的卡號字串';

-- Step 2: 建立 meals table（每日可選餐點）
create table if not exists meals (
  meal_id       uuid primary key default gen_random_uuid(),
  name          text not null,
  description   text,
  price         numeric(8,0) not null,
  available_date date not null,
  is_active     bool not null default true,
  created_at    timestamptz not null default now()
);

comment on table meals is '每日可供選擇的餐點';

create index if not exists meals_available_date_idx on meals(available_date);

-- Step 3: 建立 meal_orders table（訂餐與取餐紀錄）
create table if not exists meal_orders (
  order_id        uuid primary key default gen_random_uuid(),
  student_id      uuid not null references student(student_id) on delete cascade,
  order_date      date not null,
  meal_id         uuid references meals(meal_id),        -- 取餐當下才填入
  final_price     numeric(8,0),                          -- 取餐當下才填入
  picked_up       bool not null default false,
  picked_at       timestamptz,
  note            text,                                   -- 備註（代領等）
  created_at      timestamptz not null default now()
);

comment on table meal_orders is '學生訂餐與取餐紀錄';

create index if not exists meal_orders_date_idx      on meal_orders(order_date);
create index if not exists meal_orders_student_idx   on meal_orders(student_id);
create index if not exists meal_orders_picked_up_idx on meal_orders(picked_up);

-- Step 4: 建立 attendance table（到校打卡，供缺席通知使用）
create table if not exists attendance (
  attendance_id uuid primary key default gen_random_uuid(),
  student_id    uuid not null references student(student_id) on delete cascade,
  date          date not null,
  punched_at    timestamptz,                    -- null = 缺席
  status        text not null default 'absent', -- present / absent / leave
  note          text,
  created_at    timestamptz not null default now(),
  unique(student_id, date)
);

comment on table attendance is '學生到校打卡紀錄';

create index if not exists attendance_date_idx on attendance(date);

-- Step 5: 開啟 Supabase Realtime（取餐頁面即時更新用）
alter publication supabase_realtime add table meal_orders;
alter publication supabase_realtime add table meals;

-- ============================================================
-- 驗證用查詢（執行後確認 tables 建立成功）
-- ============================================================
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('meals','meal_orders','attendance')
order by table_name;
