-- 20260410000000_create_app_roles_and_permissions.sql
-- Create table for custom roles
CREATE TABLE IF NOT EXISTS public.app_roles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    store_id text NOT NULL,
    role_name text NOT NULL,
    permissions jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.app_roles ENABLE ROW LEVEL SECURITY;

-- Drop generic policies if they exist (for idempotency)
DROP POLICY IF EXISTS "sadmin_all_app_roles" ON public.app_roles;
DROP POLICY IF EXISTS "tenant_read_app_roles" ON public.app_roles;
DROP POLICY IF EXISTS "tenant_write_app_roles" ON public.app_roles;

-- Create policies
CREATE POLICY "sadmin_all_app_roles" ON public.app_roles FOR ALL USING (public.get_my_role_uuid() = 'sadmin');
CREATE POLICY "tenant_read_app_roles" ON public.app_roles FOR SELECT USING (store_id = public.get_my_store_uuid());
CREATE POLICY "tenant_write_app_roles" ON public.app_roles FOR ALL USING (public.get_my_role_uuid() = 'admin' AND store_id = public.get_my_store_uuid());

-- Create a helper function to check JSON permissions in RLS and RPC
CREATE OR REPLACE FUNCTION public.has_role_permission(p_permission text)
RETURNS boolean AS $$
DECLARE
    my_role text;
BEGIN
    SELECT role INTO my_role FROM public.users WHERE id = auth.uid();
    
    -- Admins and Sadmins always have all permissions
    IF my_role IN ('admin', 'sadmin') THEN
        RETURN true;
    END IF;
    
    -- Try to parse my_role as UUID (it references app_roles.id)
    BEGIN
        RETURN EXISTS (
            SELECT 1 FROM public.app_roles 
            WHERE id = my_role::uuid 
            AND permissions->>p_permission = 'true'
        );
    EXCEPTION WHEN OTHERS THEN
        -- If it's not a valid UUID (e.g. old string "staff"), it definitely doesn't have the custom permission
        RETURN false;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Update auth.users management policies and functions to support Custom Roles with "settings_users: true"

-- 1. admin_create_user
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
    -- Permit admin, sadmin, or ANY custom role granted "settings_users" permission
    IF NOT public.has_role_permission('settings_users') THEN
        RAISE EXCEPTION 'Bạn không có quyền thêm nhân viên';
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


-- 2. update_user_password (Allow custom roles to update passwords if they have settings_users)
CREATE OR REPLACE FUNCTION public.update_user_password(
    p_username text,
    p_new_password text
) RETURNS void AS $$
DECLARE
    target_id uuid;
    caller_role text;
BEGIN
    SELECT id INTO target_id FROM public.users WHERE username = p_username;
    
    -- Allow self-update or anyone with "settings_users"
    IF auth.uid() != target_id AND NOT public.has_role_permission('settings_users') THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi mật khẩu của người này';
    END IF;

    UPDATE auth.users 
    SET encrypted_password = public.crypt(p_new_password, public.gen_salt('bf'))
    WHERE id = target_id;

    UPDATE public.users SET pass = p_new_password WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. admin_delete_user
CREATE OR REPLACE FUNCTION public.admin_delete_user(
    p_username text
) RETURNS void AS $$
DECLARE
    target_id uuid;
    target_role text;
BEGIN
    SELECT id, role INTO target_id, target_role FROM public.users WHERE username = p_username;
    IF target_id IS NULL THEN RETURN; END IF;
    
    IF NOT public.has_role_permission('settings_users') THEN
        RAISE EXCEPTION 'Bạn không có quyền xóa nhân viên';
    END IF;

    -- Avoid standard staff / manager deleting admin/sadmin
    IF target_role IN ('admin', 'sadmin') AND public.get_my_role_uuid() != 'sadmin' THEN
        RAISE EXCEPTION 'Không thể xóa Admin hoặc Super Admin';
    END IF;

    DELETE FROM auth.users WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update the actual RLS on public.users
DROP POLICY IF EXISTS "admin_write_users" ON users;
CREATE POLICY "admin_write_users" ON users FOR ALL
USING (auth.role() = 'authenticated' AND public.has_role_permission('settings_users') AND created_by = public.get_my_store_uuid() AND role != 'sadmin');
