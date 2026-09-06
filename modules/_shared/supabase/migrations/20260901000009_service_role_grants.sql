-- ⚠️ 重要：這個 migration 修正一個實際卡關過的問題。
-- 之前建表時，service_role 對 public schema 的任何表完全沒有 GRANT 權限，
-- 導致 GAS 用正確的 service_role key 呼叫 Supabase API 時，
-- 一律回傳 42501 permission denied，即使 RLS 設定完全正確也一樣會擋下來。
-- 這個 migration 務必在所有表建立「之後」執行，且新環境部署時一定要記得跑，
-- 否則會重演同樣的卡關過程。
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT USAGE ON SCHEMA public TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;

GRANT USAGE ON SCHEMA public TO anon, authenticated;
