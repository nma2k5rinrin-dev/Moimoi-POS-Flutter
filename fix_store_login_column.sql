-- Chạy lệnh này trên Supabase SQL Editor để fix lỗi missing column
ALTER TABLE store_infos 
ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
