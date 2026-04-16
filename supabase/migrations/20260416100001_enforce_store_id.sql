-- ═══════════════════════════════════════════════════════════
-- ENFORCE STORE_ID — Chống INSERT/UPDATE với store_id khác tenant
-- ═══════════════════════════════════════════════════════════

-- Hàm dùng chung: Ép store_id = get_my_store_uuid() cho authenticated users
-- Anon users (khách QR) được phép insert orders với bất kỳ store_id nào (vì họ không login)
CREATE OR REPLACE FUNCTION public.enforce_store_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    my_store text;
BEGIN
    -- Bỏ qua cho anon users (khách đặt qua QR menu)
    IF auth.role() = 'anon' OR auth.uid() IS NULL THEN
        -- Đảm bảo store_id không rỗng
        IF NEW.store_id IS NULL OR NEW.store_id = '' THEN
            RAISE EXCEPTION 'store_id không được để trống';
        END IF;
        RETURN NEW;
    END IF;

    my_store := public.get_my_store_uuid();

    -- Không cho insert/update record với store_id khác tenant của mình
    IF my_store IS NOT NULL AND my_store != '' THEN
        IF NEW.store_id IS NULL OR NEW.store_id = '' THEN
            -- Auto-fill nếu bỏ trống
            NEW.store_id := my_store;
        ELSIF NEW.store_id != my_store THEN
            RAISE EXCEPTION 'Không thể thao tác dữ liệu của cửa hàng khác';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Áp dụng trigger cho các bảng chính
-- 1. orders
DROP TRIGGER IF EXISTS trg_enforce_store_id_orders ON public.orders;
CREATE TRIGGER trg_enforce_store_id_orders
    BEFORE INSERT OR UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_store_id();

-- 2. products
DROP TRIGGER IF EXISTS trg_enforce_store_id_products ON public.products;
CREATE TRIGGER trg_enforce_store_id_products
    BEFORE INSERT OR UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_store_id();

-- 3. categories
DROP TRIGGER IF EXISTS trg_enforce_store_id_categories ON public.categories;
CREATE TRIGGER trg_enforce_store_id_categories
    BEFORE INSERT OR UPDATE ON public.categories
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_store_id();

-- 4. transactions (thu chi)
DROP TRIGGER IF EXISTS trg_enforce_store_id_transactions ON public.transactions;
CREATE TRIGGER trg_enforce_store_id_transactions
    BEFORE INSERT OR UPDATE ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_store_id();

-- 5. transaction_categories
DROP TRIGGER IF EXISTS trg_enforce_store_id_txn_cats ON public.transaction_categories;
CREATE TRIGGER trg_enforce_store_id_txn_cats
    BEFORE INSERT OR UPDATE ON public.transaction_categories
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_store_id();
