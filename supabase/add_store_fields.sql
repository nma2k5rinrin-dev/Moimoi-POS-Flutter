ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS tax_id TEXT;
ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS open_hours TEXT DEFAULT '07:00 - 22:00';
ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS bank_id TEXT;
ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS bank_account TEXT;
ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS bank_owner TEXT;
ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS qr_image_url TEXT;
ALTER TABLE public.store_infos ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- Bắt buộc phải chạy lệnh này để Cập nhật lại cache cho postgrest API
NOTIFY pgrst, 'reload schema';
