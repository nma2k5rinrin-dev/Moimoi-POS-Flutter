-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: AUTH MIGRATION & RLS
-- DESCRIPTION: Refactors the plain-text password system
-- to use Supabase Auth native with fake emails.
-- ═══════════════════════════════════════════════════════════

-- LƯU Ý: Chạy file này với quyền postgres/supabase_admin (Mặc định trong SQL Editor là được)

-- 1. THÊM CỘT ID VÀO public.users
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- Tạo index cho id
CREATE INDEX IF NOT EXISTS users_id_idx ON public.users(id);

-- 2. HÀM TẠO NHÂN VIÊN DÀNH CHO ADMIN (Tránh bị logout khi dùng signUp trên client)
-- Chạy bằng SECURITY DEFINER để có quyền insert vào auth.users
CREATE OR REPLACE FUNCTION public.admin_create_user(
    p_username text,
    p_password text,
    p_role text,
    p_fullname text,
    p_phone text,
    p_created_by text
) RETURNS uuid AS $$
DECLARE
    new_user_id uuid;
    fake_email text;
BEGIN
    -- Chỉ admin/sadmin mới có quyền gọi hàm này
    IF (SELECT role FROM public.users WHERE id = auth.uid()) NOT IN ('admin', 'sadmin') THEN
        RAISE EXCEPTION 'Chỉ chủ cửa hàng mới được quyền tạo nhân viên';
    END IF;

    -- Kiểm tra trùng lặp
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RAISE EXCEPTION 'Tên đăng nhập đã tồn tại';
    END IF;

    new_user_id := gen_random_uuid();
    fake_email := p_username || '@moimoi.local';

    -- Insert vào auth.users (Tạo tài khoản gốc)
    -- Hàm crypt() cần extension pgcrypto (Supabase đã bật sẵn trong auth schema)
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, 
        created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', new_user_id, 'authenticated', 'authenticated', fake_email, public.crypt(p_password, public.gen_salt('bf')), 
        now(), now(), now(), '', '', 
        now(), now(), '', '', '', ''
    );

    -- Insert vào public.users (Tạo hồ sơ)
    INSERT INTO public.users (
        id, username, pass, role, fullname, phone, created_by, is_premium, 
        show_vip_expired, show_vip_congrat, created_at
    ) VALUES (
        new_user_id, p_username, p_password, p_role, p_fullname, p_phone, p_created_by, false, 
        false, false, now()
    );

    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. HÀM ĐỔI MẬT KHẨU (Dành cho admin hoặc chính chủ)
CREATE OR REPLACE FUNCTION public.update_user_password(
    p_username text,
    p_new_password text
) RETURNS void AS $$
DECLARE
    target_id uuid;
    caller_role text;
BEGIN
    SELECT id INTO target_id FROM public.users WHERE username = p_username;
    
    SELECT role INTO caller_role FROM public.users WHERE id = auth.uid();
    
    -- Chỉ chính chủ hoặc Admin/Sadmin mới được đổi
    IF auth.uid() != target_id AND caller_role NOT IN ('admin', 'sadmin') THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi mật khẩu của người này';
    END IF;

    -- Update trong auth.users
    UPDATE auth.users 
    SET encrypted_password = public.crypt(p_new_password, public.gen_salt('bf'))
    WHERE id = target_id;

    -- Update lại dòng pass (tuỳ ý giữ lại pass plain text nếu bạn muốn tương thích code cũ, 
    -- nhưng MẠNH MẼ KHUYẾN CÁO nên bỏ. Ở đây cứ sửa tạm để app ko lỗi)
    UPDATE public.users SET pass = p_new_password WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3.5. HÀM XÓA NHÂN VIÊN (Dành cho Admin)
CREATE OR REPLACE FUNCTION public.admin_delete_user(
    p_username text
) RETURNS void AS $$
DECLARE
    target_id uuid;
    caller_role text;
    target_role text;
BEGIN
    SELECT id, role INTO target_id, target_role FROM public.users WHERE username = p_username;
    IF target_id IS NULL THEN RETURN; END IF;
    
    SELECT role INTO caller_role FROM public.users WHERE id = auth.uid();
    
    IF caller_role NOT IN ('admin', 'sadmin') THEN
        RAISE EXCEPTION 'Bạn không có quyền xóa nhân viên';
    END IF;

    IF caller_role = 'admin' AND target_role IN ('admin', 'sadmin') THEN
        RAISE EXCEPTION 'Admin không thể xóa Admin khác hoặc Sadmin';
    END IF;

    -- Delete from auth.users (Tự động cascade sang public.users)
    DELETE FROM auth.users WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. BẬT LẠI RLS VỚI UUID CHUẨN (id = auth.uid())

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_infos ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE thu_chi_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE upgrade_requests ENABLE ROW LEVEL SECURITY;

-- Helper Roles dựa vào bảng users đã liên kết UUID
CREATE OR REPLACE FUNCTION public.get_my_role_uuid()
RETURNS text AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_store_uuid()
RETURNS text AS $$
  SELECT CASE 
    WHEN role = 'admin' THEN username 
    WHEN role = 'sadmin' THEN 'sadmin'
    ELSE created_by 
  END
  FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Xóa Policies cũ của bản nháp trước
DROP POLICY IF EXISTS sadmin_all_users ON users;
DROP POLICY IF EXISTS admin_staff_read_users ON users;
DROP POLICY IF EXISTS self_read_user ON users;
DROP POLICY IF EXISTS admin_write_users ON users;
DROP POLICY IF EXISTS sadmin_all_stores ON store_infos;
DROP POLICY IF EXISTS tenant_read_store ON store_infos;
DROP POLICY IF EXISTS admin_write_store ON store_infos;

-- POLICIES: USERS (Dùng UUID)
CREATE POLICY "sadmin_all_users" ON users FOR ALL
USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');

CREATE POLICY "admin_staff_read_users" ON users FOR SELECT
USING (auth.role() = 'authenticated' 
  AND (username = public.get_my_store_uuid() OR created_by = public.get_my_store_uuid())
  AND role != 'sadmin');

CREATE POLICY "self_read_user" ON users FOR SELECT
USING (id = auth.uid());

CREATE POLICY "self_insert_user" ON users FOR INSERT
WITH CHECK (id = auth.uid());

CREATE POLICY "admin_write_users" ON users FOR ALL
USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'admin' AND created_by = public.get_my_store_uuid() AND role != 'sadmin');

-- POLICIES: STORE_INFOS
CREATE POLICY "sadmin_all_stores" ON store_infos FOR ALL
USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');

CREATE POLICY "tenant_read_store" ON store_infos FOR SELECT
USING (auth.role() = 'authenticated' AND store_id = public.get_my_store_uuid());

CREATE POLICY "tenant_write_store" ON store_infos FOR UPDATE
USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'admin' AND store_id = public.get_my_store_uuid());

CREATE POLICY "tenant_insert_store" ON store_infos FOR INSERT
WITH CHECK (auth.role() = 'authenticated'); -- Because they just signed up, they can insert their first store.

-- POLICIES: OTHERS
DROP POLICY IF EXISTS sadmin_all_orders ON orders;
DROP POLICY IF EXISTS tenant_all_orders ON orders;
CREATE POLICY "sadmin_all_orders" ON orders FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');
CREATE POLICY "tenant_all_orders" ON orders FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store_uuid());

DROP POLICY IF EXISTS sadmin_all_thuchi ON thu_chi_transactions;
DROP POLICY IF EXISTS tenant_all_thuchi ON thu_chi_transactions;
CREATE POLICY "sadmin_all_thuchi" ON thu_chi_transactions FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');
CREATE POLICY "tenant_all_thuchi" ON thu_chi_transactions FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store_uuid());

DROP POLICY IF EXISTS sadmin_all_products ON products;
DROP POLICY IF EXISTS tenant_all_products ON products;
CREATE POLICY "sadmin_all_products" ON products FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');
CREATE POLICY "tenant_all_products" ON products FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store_uuid());

DROP POLICY IF EXISTS sadmin_all_categories ON categories;
DROP POLICY IF EXISTS tenant_all_categories ON categories;
CREATE POLICY "sadmin_all_categories" ON categories FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');
CREATE POLICY "tenant_all_categories" ON categories FOR ALL USING (auth.role() = 'authenticated' AND store_id = public.get_my_store_uuid());

DROP POLICY IF EXISTS sadmin_all_upgrades ON upgrade_requests;
DROP POLICY IF EXISTS admin_all_upgrades ON upgrade_requests;
CREATE POLICY "sadmin_all_upgrades" ON upgrade_requests FOR ALL USING (auth.role() = 'authenticated' AND public.get_my_role_uuid() = 'sadmin');
CREATE POLICY "admin_all_upgrades" ON upgrade_requests FOR ALL USING (
  auth.role() = 'authenticated' 
  AND (
    username = (SELECT u.username FROM public.users u WHERE u.id = auth.uid())
  )
);
