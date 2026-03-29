-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: ENABLE ROW LEVEL SECURITY (RLS) FOR MOIMOI POS
-- DESCRIPTION: Secures all raw tables from public read/writes
-- ═══════════════════════════════════════════════════════════

-- 1. Mở RLS cho TẤT CẢ các bảng quan trọng
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_infos ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE thu_chi_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE upgrade_requests ENABLE ROW LEVEL SECURITY;

-- Xóa các policy cũ để tránh đụng độ (nếu có)
DROP POLICY IF EXISTS "Public read access" ON users;
DROP POLICY IF EXISTS "Public read access" ON store_infos;

-- 2. TẠO HÀM TIỆN ÍCH LẤY VAI TRÒ VÀ NGƯỜI TẠO (store_id) HIỆN TẠI (Performance optimization)
-- Hàm này lấy 'role' và 'created_by' (store id gốc) của người dùng HIỆN ĐANG ĐĂNG NHẬP
-- Lưu ý hàm xài username match auth.uid() của auth supbase nếu có, hoặc dùng JWT claim (Tuỳ cách bạn login Supabase)
-- Giả sử bạn đang dùng JWT thì có thể thay ID = auth.uid() thành việc so sánh username
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
  -- Do bảng users dùng username/tên tài khoản thay cho UID mặc định:
  SELECT role FROM public.users WHERE username = (auth.jwt() ->> 'username')::text LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_store()
RETURNS text AS $$
  -- Trả về tên tài khoản (username) của CHỦ cửa hàng (Tức là store_id trong các bảng khác)
  SELECT CASE 
    WHEN role = 'admin' THEN username 
    WHEN role = 'sadmin' THEN 'sadmin'
    ELSE created_by -- Staff thì lấy created_by (username của admin tạo ra staff)
  END
  FROM public.users WHERE username = (auth.jwt() ->> 'username')::text LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ═══════════════════════════════════════════════════════════
-- 3. POLICIES CHO BẢNG: USERS
-- ═══════════════════════════════════════════════════════════

CREATE POLICY "sadmin_all_users" 
ON users FOR ALL
USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');

CREATE POLICY "admin_staff_read_users"
ON users FOR SELECT
USING (
  auth.role() = 'authenticated' 
  AND (
     username = public.get_my_store() -- store admin
     OR created_by = public.get_my_store() -- store staff
  )
  AND role != 'sadmin'
);

-- Người dùng thấy chính họ
CREATE POLICY "self_read_user"
ON users FOR SELECT
USING (username = (auth.jwt() ->> 'username')::text);

-- Admin tạo nhân viên
CREATE POLICY "admin_write_users"
ON users FOR ALL
USING (auth.role() = 'authenticated' AND public.get_my_role() = 'admin' AND created_by = public.get_my_store() AND role != 'sadmin');


-- ═══════════════════════════════════════════════════════════
-- 4. POLICIES CHO BẢNG: STORE_INFOS
-- ═══════════════════════════════════════════════════════════
CREATE POLICY "sadmin_all_stores" 
ON store_infos FOR ALL
USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');

CREATE POLICY "tenant_read_store"
ON store_infos FOR SELECT
USING (auth.role() = 'authenticated' AND store_id = public.get_my_store());

CREATE POLICY "admin_write_store"
ON store_infos FOR UPDATE
USING (auth.role() = 'authenticated' AND public.get_my_role() = 'admin' AND store_id = public.get_my_store());


-- ═══════════════════════════════════════════════════════════
-- 5. POLICIES CHO CÁC BẢNG DỮ LIỆU HOẠT ĐỘNG
-- ═══════════════════════════════════════════════════════════

-- ORDERS
CREATE POLICY "sadmin_all_orders" ON orders FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');
CREATE POLICY "tenant_all_orders" ON orders FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store());

-- THU CHI
CREATE POLICY "sadmin_all_thuchi" ON thu_chi_transactions FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');
CREATE POLICY "tenant_all_thuchi" ON thu_chi_transactions FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store());

-- PRODUCTS
CREATE POLICY "sadmin_all_products" ON products FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');
CREATE POLICY "tenant_all_products" ON products FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store());

-- CATEGORIES
CREATE POLICY "sadmin_all_categories" ON categories FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');
CREATE POLICY "tenant_all_categories" ON categories FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store());

-- UPGRADES
CREATE POLICY "sadmin_all_upgrades" ON upgrade_requests FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');
CREATE POLICY "admin_all_upgrades" ON upgrade_requests FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role() = 'admin' AND store_id = public.get_my_store());
