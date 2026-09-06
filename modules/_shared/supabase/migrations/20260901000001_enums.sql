-- 確保 uuid_generate_v4() 可用（新專案有可能預設沒開這個 extension）
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- 自定義型別
CREATE TYPE staff_role AS ENUM ('工讀生', '正職');
CREATE TYPE enrollment_status AS ENUM ('試聽', '正式', '退出', '結業');
