-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Auto-merge QR orders
-- DESCRIPTION: When a QR customer inserts a new order for a table that
-- already has a pending unpaid order, this trigger merges the new items
-- into the existing order and deletes the newly inserted duplicate row.
-- This keeps the table's active order unified instead of creating many
-- separate single-item orders each time the customer scans.
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
  -- and its status indicates it's an unpaid, pending order
  IF NEW.table_name IS NOT NULL AND trim(NEW.table_name) != '' 
     AND NEW.payment_status = 'unpaid' 
     AND NEW.status = 'pending' THEN

    -- Find the most recent existing open order for this store & table
    SELECT * INTO existing_order
    FROM public.orders
    WHERE store_id = NEW.store_id
      AND table_name = NEW.table_name
      AND payment_status = 'unpaid'
      AND status = 'pending'
      AND id != NEW.id -- exclude the newly inserted row itself
    ORDER BY time DESC
    LIMIT 1;

    -- If we found an existing order, append the items and total_amount, then delete the duplicate
    IF FOUND THEN
      UPDATE public.orders
      SET 
        items = COALESCE(existing_order.items, '[]'::jsonb) || COALESCE(NEW.items, '[]'::jsonb),
        total_amount = existing_order.total_amount + NEW.total_amount,
        time = NEW.time -- Bump the updated order to the newest time
      WHERE id = existing_order.id;

      -- Delete the newly inserted duplicate order
      -- Since it's an AFTER trigger, deleting it here works without breaking the initial INSERT request 
      -- for the QR web application.
      DELETE FROM public.orders WHERE id = NEW.id;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

-- Drop trigger if exists to allow safely re-running migration
DROP TRIGGER IF EXISTS trigger_merge_qr_order_after_insert ON public.orders;

-- Create the trigger
CREATE TRIGGER trigger_merge_qr_order_after_insert
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.merge_qr_order_after_insert();
