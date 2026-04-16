-- ═══════════════════════════════════════════════════════════
-- CHỐNG NÂNG QUYỀN (ROLE ESCALATION PREVENTION)
-- Admin không được tạo/gán role >= admin
-- ═══════════════════════════════════════════════════════════

-- 1. Cập nhật admin_create_user: Chặn tạo user với role admin/sadmin
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
    caller_role text;
BEGIN
    -- Kiểm tra quyền tạo nhân viên
    IF NOT public.has_role_permission('settings_users') THEN
        RAISE EXCEPTION 'Bạn không có quyền thêm nhân viên';
    END IF;

    -- Lấy role của người gọi
    SELECT role INTO caller_role FROM public.users WHERE id = auth.uid();

    -- ══ CHỐNG ESCALATION ══
    -- Chỉ sadmin mới tạo được admin. Không ai tạo được sadmin.
    IF p_role = 'sadmin' THEN
        RAISE EXCEPTION 'Không thể tạo tài khoản Super Admin';
    END IF;

    IF p_role = 'admin' AND caller_role != 'sadmin' THEN
        RAISE EXCEPTION 'Chỉ Super Admin mới có thể tạo tài khoản Admin';
    END IF;

    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RAISE EXCEPTION 'Tên đăng nhập đã tồn tại';
    END IF;

    new_user_id := gen_random_uuid();
    fake_email := p_username || '@moimoi.local';

    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, 
        created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', new_user_id, 'authenticated', 'authenticated', fake_email, public.crypt(p_password, public.gen_salt('bf')), 
        now(), now(), now(), '', '', 
        now(), now(), '', '', '', ''
    );

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


-- 2. Trigger BEFORE UPDATE trên users: Chặn tự escalate role
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_role text;
BEGIN
    -- Nếu role không bị thay đổi, cho qua
    IF NEW.role = OLD.role THEN
        RETURN NEW;
    END IF;

    SELECT role INTO caller_role FROM public.users WHERE id = auth.uid();

    -- Không ai được tự gán mình thành sadmin
    IF NEW.role = 'sadmin' THEN
        RAISE EXCEPTION 'Không thể nâng quyền lên Super Admin';
    END IF;

    -- Chỉ sadmin mới gán được quyền admin
    IF NEW.role = 'admin' AND caller_role != 'sadmin' THEN
        RAISE EXCEPTION 'Chỉ Super Admin mới có thể gán quyền Admin';
    END IF;

    -- Không cho hạ quyền admin/sadmin nếu mình không phải sadmin
    IF OLD.role IN ('admin', 'sadmin') AND caller_role != 'sadmin' THEN
        RAISE EXCEPTION 'Không thể thay đổi quyền của Admin hoặc Super Admin';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_role_escalation
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_role_escalation();
