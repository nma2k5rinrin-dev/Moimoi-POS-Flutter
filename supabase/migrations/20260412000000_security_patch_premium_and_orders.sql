-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: Security Patch - Premium Bypass & Order Spoofing
-- ═══════════════════════════════════════════════════════════

-- ============================================================================
-- 1. FIX HACK PREMIUM BYPASS
-- Triggers on `store_infos` to prevent non-sadmin from altering `is_premium` & `premium_expires_at`
-- ============================================================================

CREATE OR REPLACE FUNCTION public.protect_premium_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_role text;
BEGIN
    -- Lấy role thực sự của tài khoản đang update
    SELECT role INTO user_role FROM public.users WHERE id = auth.uid() LIMIT 1;
    
    -- Nếu không phải sadmin, ép trả lại giá trị is_premium / expires_at về như cũ 
    -- mặc cho client gửi payload gì lên để hòng thay đổi.
    IF user_role IS NULL OR user_role != 'sadmin' THEN
        NEW.is_premium = OLD.is_premium;
        NEW.premium_expires_at = OLD.premium_expires_at;
        NEW.premium_activated_at = OLD.premium_activated_at;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_premium_status ON public.store_infos;
CREATE TRIGGER trg_protect_premium_status
    BEFORE UPDATE ON public.store_infos
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_premium_status();


-- ============================================================================
-- 2. FIX FREE FOOD EXPLOIT (ORDER SPOOFING)
-- Triggers on `orders` to dynamically calculate `total_amount` based on `items`
-- Prevents anon/customer from submitting a fake total_amount = 0
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_real_order_total()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    calculated_total numeric := 0;
    item record;
    item_price numeric;
    item_qty int;
BEGIN
    -- Chỉ tính lại nếu có Items truyền lên
    IF NEW.items IS NOT NULL AND jsonb_typeof(NEW.items) = 'array' THEN
        
        -- Lặp qua từng item trong mảng items jsonb
        FOR item IN SELECT * FROM jsonb_array_elements(NEW.items)
        LOOP
            -- Ép kiểu cẩn thận để tránh lỗi parse khi user cố ý lách luật truyền text 
            BEGIN
                item_price := (item.value->>'price')::numeric;
                item_qty := (item.value->>'quantity')::int;
                
                -- Ngăn ngừa truyền quantity hoặc price âm
                IF item_price < 0 THEN item_price := 0; END IF;
                IF item_qty < 0 THEN item_qty := 0; END IF;

                calculated_total := calculated_total + (item_price * item_qty);
            EXCEPTION WHEN OTHERS THEN
                -- Nếu parse lỗi (kẻ gian cố tình truyền rác), bỏ qua món đó hoặc gán 0
                CONTINUE;
            END;
        END LOOP;
        
        -- Ghi đè bắt buộc giá trị total_amount từ client
        NEW.total_amount := calculated_total; 
    END IF;
    
    RETURN NEW;
END;
$$;

-- Chạy Trigger này BEFORE CẢ insert và update
DROP TRIGGER IF EXISTS trg_calculate_real_order_total ON public.orders;
CREATE TRIGGER trg_calculate_real_order_total
    BEFORE INSERT OR UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.calculate_real_order_total();

-- ============================================================================
-- 3. FIX COST PRICE LEAK FOR ANONYMOUS USERS
-- Loại bỏ các trường nhạy cảm khỏi mắt Anon users (Cost_price, quantity)
-- Cách an toàn nhất là xoá bỏ READ products RLS policy cho role ANON, và thay
-- bằng 1 Supabase postgres View.
-- TUY NHIÊN: Đổi sang View có thể phá vỡ Offline-First drift sync trên app Flutter
-- DO ĐÓ CHÚNG TA DÙNG PHƯƠNG PHÁP: TẠO RPC FUNCTION CHO KHÁCH LẤY MENU.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_public_menu(p_store_id text)
RETURNS TABLE (
    id text,
    name text,
    price numeric,
    image text,
    category text,
    description text,
    is_out_of_stock boolean,
    is_hot boolean
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    -- Lấy thông tin sản phẩm và ẩn đi quantity, cost_price, deleted_at, is_synced
    SELECT 
        id, 
        name, 
        price, 
        image, 
        category, 
        description, 
        is_out_of_stock, 
        is_hot
    FROM public.products
    WHERE store_id = p_store_id
      AND deleted_at IS NULL;
$$;
