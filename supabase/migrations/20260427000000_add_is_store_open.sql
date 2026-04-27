-- ============================================================================
-- FEATURE: Thêm trạng thái Đóng/Mở cửa chủ động bằng tay
-- ============================================================================

ALTER TABLE public.store_infos
  ADD COLUMN IF NOT EXISTS is_store_open BOOLEAN DEFAULT true;

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
