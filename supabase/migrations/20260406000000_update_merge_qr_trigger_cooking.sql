-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Update Auto-merge QR orders for cooking status
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.merge_qr_order_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_order RECORD;
BEGIN
  -- Only attempt to merge if the inserted order has a specific table
  -- and its status indicates it's an unpaid, pending order from QR
  IF NEW.table_name IS NOT NULL AND trim(NEW.table_name) != '' 
     AND NEW.payment_status = 'unpaid' 
     AND NEW.status = 'pending' THEN

    -- Find the most recent existing open order for this store & table
    SELECT * INTO existing_order
    FROM public.orders
    WHERE store_id = NEW.store_id
      AND table_name = NEW.table_name
      AND payment_status = 'unpaid'
      AND status IN ('pending', 'cooking') -- Include 'cooking' ("đang sử dụng") so new items merge!
      AND id != NEW.id -- exclude the newly inserted row itself
    ORDER BY time DESC
    LIMIT 1;

    -- If we found an existing order, append the items and total_amount, then delete the duplicate
    IF FOUND THEN
      UPDATE public.orders
      SET 
        items = COALESCE(existing_order.items, '[]'::jsonb) || COALESCE(NEW.items, '[]'::jsonb),
        total_amount = existing_order.total_amount + NEW.total_amount,
        -- status is NOT changed here: it remains as existing_order.status (e.g. 'cooking')
        time = NEW.time -- Bump the updated order to the newest time
      WHERE id = existing_order.id;

      -- Determine notification text based on the existing status
      -- If it's cooking, we explicitly let them know the customer added more items.
      IF existing_order.status = 'cooking' THEN
        INSERT INTO public.notifications (user_id, title, message, type, time)
        VALUES (
          NEW.store_id, 
          'Khách đặt thêm sản phẩm', 
          'Bàn ' || NEW.table_name || ' vừa gọi thêm sản phẩm mới!', 
          'order_update', 
          NEW.time
        );
      END IF;

      -- Delete the newly inserted duplicate order
      DELETE FROM public.orders WHERE id = NEW.id;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

