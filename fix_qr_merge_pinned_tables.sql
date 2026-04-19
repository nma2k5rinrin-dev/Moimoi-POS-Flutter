-- =========================================================================
-- BẢN VÁ LỖI GỘP ĐƠN & GỘP MÓN (CẬP NHẬT MỚI NHẤT)
-- Trigger đang hoạt động trên hệ thống của bạn là fn_merge_qr_orders_after_insert
-- =========================================================================

-- Thay thế trigger hiện tại để tránh gộp số lượng (x2) và tách biệt bàn ghim (★)
CREATE OR REPLACE FUNCTION public.fn_merge_qr_orders_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_order RECORD;
BEGIN
  -- 1. Bỏ qua gộp đơn nếu tên bàn bắt đầu bằng ký tự ngôi sao ★ (Ghim bàn)
  IF NEW.table_name IS NOT NULL 
     AND trim(NEW.table_name) != '' 
     AND trim(NEW.table_name) NOT LIKE '★%' 
     AND NEW.payment_status = 'unpaid' 
     AND NEW.status = 'pending' THEN

    -- Tìm đơn gần nhất của bàn này đang ở trạng thái pending/processing
    SELECT * INTO existing_order
    FROM public.orders
    WHERE store_id = NEW.store_id
      AND table_name = NEW.table_name
      AND payment_status = 'unpaid'
      AND status IN ('pending', 'processing')
      AND id != NEW.id
    ORDER BY time DESC
    LIMIT 1;

    -- Nếu tìm thấy đơn, thực hiện nối mảng items (KHÔNG CỘNG SUM SỐ LƯỢNG)
    IF FOUND THEN
      UPDATE public.orders
      SET 
        -- Transform new items to include "isNewlyAdded": true, then concatenate
        items = COALESCE(existing_order.items, '[]'::jsonb) || (
          SELECT COALESCE(jsonb_agg(item || '{"isNewlyAdded": true}'::jsonb), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(NEW.items, '[]'::jsonb)) AS item
        ),
        total_amount = existing_order.total_amount + NEW.total_amount,
        time = NEW.time
      WHERE id = existing_order.id;

      IF existing_order.status = 'processing' THEN
        INSERT INTO public.notifications (user_id, title, message, type, time)
        VALUES (
          NEW.store_id, 
          'Khách đặt thêm sản phẩm', 
          'Bàn ' || NEW.table_name || ' vừa gọi thêm sản phẩm mới!', 
          'order_update', 
          NEW.time
        );
      END IF;

      -- Xóa phần xác đơn vừa tạo (đã được nối vào đơn gốc)
      DELETE FROM public.orders WHERE id = NEW.id;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

-- Cập nhật lại trigger cho chắc chắn đang refer đúng hàm
-- XÓA TẤT CẢ CÁC TRIGGER VÀ HÀM CŨ NẾU CÓ (tránh bị nối item 2 lần do dính 2 trigger)
DROP TRIGGER IF EXISTS trigger_merge_qr_orders_after_insert ON public.orders;
DROP TRIGGER IF EXISTS trigger_merge_qr_order_after_insert ON public.orders;
DROP FUNCTION IF EXISTS public.merge_qr_order_after_insert() CASCADE;

CREATE TRIGGER trigger_merge_qr_orders_after_insert
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.fn_merge_qr_orders_after_insert();
