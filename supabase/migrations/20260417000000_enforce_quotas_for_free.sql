-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: Enforce Quotas for Free Tier
-- ═══════════════════════════════════════════════════════════

-- 1. LIMIT PRODUCTS (Max 5)
CREATE OR REPLACE FUNCTION public.enforce_product_quota()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    is_vip boolean;
    current_count int;
BEGIN
    SELECT is_premium INTO is_vip FROM public.store_infos WHERE store_id = NEW.store_id;
    
    IF is_vip IS NULL OR is_vip = false THEN
        SELECT count(*) INTO current_count FROM public.products WHERE store_id = NEW.store_id AND deleted_at IS NULL;
        IF current_count >= 5 THEN
            RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 5 sản phẩm. Vui lòng nâng cấp Premium.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_product_quota ON public.products;
CREATE TRIGGER trg_enforce_product_quota
    BEFORE INSERT ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_product_quota();


-- 2. LIMIT CATEGORIES (Max 2)
CREATE OR REPLACE FUNCTION public.enforce_category_quota()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    is_vip boolean;
    current_count int;
BEGIN
    SELECT is_premium INTO is_vip FROM public.store_infos WHERE store_id = NEW.store_id;
    
    IF is_vip IS NULL OR is_vip = false THEN
        SELECT count(*) INTO current_count FROM public.categories WHERE store_id = NEW.store_id AND deleted_at IS NULL;
        IF current_count >= 2 THEN
            RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 2 danh mục. Vui lòng nâng cấp Premium.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_category_quota ON public.categories;
CREATE TRIGGER trg_enforce_category_quota
    BEFORE INSERT ON public.categories
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_category_quota();


-- 3. LIMIT STAFF (Max 1)
CREATE OR REPLACE FUNCTION public.enforce_staff_quota()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    is_vip boolean;
    current_count int;
BEGIN
    -- Only check if this is a staff user being added by a store owner
    IF NEW.role NOT IN ('admin', 'sadmin') AND NEW.created_by IS NOT NULL THEN
        SELECT is_premium INTO is_vip FROM public.store_infos WHERE store_id = NEW.created_by;
        
        IF is_vip IS NULL OR is_vip = false THEN
            SELECT count(*) INTO current_count FROM public.users WHERE created_by = NEW.created_by AND deleted_at IS NULL;
            IF current_count >= 1 THEN
                RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 1 nhân viên. Vui lòng nâng cấp Premium.';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_staff_quota ON public.users;
CREATE TRIGGER trg_enforce_staff_quota
    BEFORE INSERT ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_staff_quota();


-- 4. LIMIT ORDERS PER DAY (Max 10)
CREATE OR REPLACE FUNCTION public.enforce_order_quota()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    is_vip boolean;
    today_count int;
BEGIN
    SELECT is_premium INTO is_vip FROM public.store_infos WHERE store_id = NEW.store_id;
    
    IF is_vip IS NULL OR is_vip = false THEN
        -- Count orders created today based on the 'time' column
        SELECT count(*) INTO today_count FROM public.orders 
        WHERE store_id = NEW.store_id 
        AND date_trunc('day', time::timestamp) = date_trunc('day', now()::timestamp);
        
        IF today_count >= 10 THEN
            RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 10 đơn hàng/ngày. Vui lòng nâng cấp Premium.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_order_quota ON public.orders;
CREATE TRIGGER trg_enforce_order_quota
    BEFORE INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_order_quota();
