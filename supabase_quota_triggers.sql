-- BỘ QUY TẮC BẢO MẬT QUOTA CHO GÓI CƠ BẢN (FREE TIER)
-- Thực thi đoạn mã này trong thẻ "SQL Editor" trên bảng điều khiển Supabase

-------------------------------------------------------
-- 1. Giới hạn Products (Tối đa 5 sản phẩm)
-------------------------------------------------------
CREATE OR REPLACE FUNCTION check_quota_products()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_product_count INT;
BEGIN
  -- Lấy trạng thái premium của cửa hàng
  SELECT is_premium INTO v_is_premium FROM store_infos WHERE store_id = NEW.store_id;
  
  IF v_is_premium = FALSE THEN
    -- Đếm số sản phẩm hiện hành (không tính các sản phẩm đã bị xóa mềm nếu có, hoặc đếm toàn bộ)
    SELECT COUNT(*) INTO v_product_count FROM products WHERE store_id = NEW.store_id AND deleted_at IS NULL;
    IF v_product_count >= 5 THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 5 sản phẩm. Vui lòng nâng cấp Premium.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_quota_products ON products;
CREATE TRIGGER trg_check_quota_products
BEFORE INSERT ON products
FOR EACH ROW
EXECUTE FUNCTION check_quota_products();

-------------------------------------------------------
-- 2. Giới hạn Categories (Tối đa 2 danh mục)
-------------------------------------------------------
CREATE OR REPLACE FUNCTION check_quota_categories()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_category_count INT;
BEGIN
  SELECT is_premium INTO v_is_premium FROM store_infos WHERE store_id = NEW.store_id;
  
  IF v_is_premium = FALSE THEN
    SELECT COUNT(*) INTO v_category_count FROM categories WHERE store_id = NEW.store_id AND deleted_at IS NULL;
    IF v_category_count >= 2 THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 2 danh mục. Vui lòng nâng cấp Premium.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_quota_categories ON categories;
CREATE TRIGGER trg_check_quota_categories
BEFORE INSERT ON categories
FOR EACH ROW
EXECUTE FUNCTION check_quota_categories();

-------------------------------------------------------
-- 3. Giới hạn Nhân viên (Tối đa 1 nhân viên phụ)
-------------------------------------------------------
CREATE OR REPLACE FUNCTION check_quota_users()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_staff_count INT;
BEGIN
  -- Chỉ kiểm tra khi tạo tài khoản nhân viên (được tạo bởi admin)
  IF NEW.created_by IS NOT NULL THEN
    SELECT is_premium INTO v_is_premium FROM store_infos WHERE store_id = NEW.created_by;
    
    IF v_is_premium = FALSE THEN
      SELECT COUNT(*) INTO v_staff_count FROM users WHERE created_by = NEW.created_by;
      IF v_staff_count >= 1 THEN
        RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 1 nhân viên. Vui lòng nâng cấp Premium.';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_quota_users ON users;
CREATE TRIGGER trg_check_quota_users
BEFORE INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION check_quota_users();

-------------------------------------------------------
-- 4. Giới hạn Đơn hàng (Tối đa 10 đơn mỗi ngày)
-------------------------------------------------------
CREATE OR REPLACE FUNCTION check_quota_orders()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_order_count INT;
BEGIN
  SELECT is_premium INTO v_is_premium FROM store_infos WHERE store_id = NEW.store_id;
  
  IF v_is_premium = FALSE THEN
    -- Đếm số hóa đơn của cửa hàng trong ngày hôm nay (theo UTC hoặc Local dựa trên server time)
    SELECT COUNT(*) INTO v_order_count 
    FROM orders 
    WHERE store_id = NEW.store_id 
    AND (time::timestamp >= CURRENT_DATE::timestamp);
    
    IF v_order_count >= 10 THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED: Gói Cơ bản chỉ cho phép tối đa 10 đơn/ngày. Vui lòng nâng cấp Premium.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_quota_orders ON orders;
CREATE TRIGGER trg_check_quota_orders
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION check_quota_orders();
