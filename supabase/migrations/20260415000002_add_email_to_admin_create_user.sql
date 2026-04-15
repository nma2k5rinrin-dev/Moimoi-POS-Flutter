-- File: e:\Moimoi-POS-Flutter\supabase\migrations\20260415000002_add_email_to_admin_create_user.sql

-- Drop the old definition (since parameter list changed)
DROP FUNCTION IF EXISTS public.admin_create_user(text, text, text, text, text, text);

-- Create new definition with p_email
CREATE OR REPLACE FUNCTION public.admin_create_user(
    p_username text,
    p_password text,
    p_role text,
    p_fullname text,
    p_phone text,
    p_created_by text,
    p_email text
) RETURNS uuid AS $$
DECLARE
    new_user_id uuid;
BEGIN
    -- Permit admin, sadmin, or ANY custom role granted "settings_users" permission
    IF NOT public.has_role_permission('settings_users') THEN
        RAISE EXCEPTION 'Bạn không có quyền thêm nhân viên';
    END IF;

    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RAISE EXCEPTION 'Tên đăng nhập đã tồn tại';
    END IF;
    
    -- Option: check if email is already taken by auth.users
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email này đã tồn tại';
    END IF;

    new_user_id := gen_random_uuid();

    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, 
        created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', new_user_id, 'authenticated', 'authenticated', p_email, public.crypt(p_password, public.gen_salt('bf')), 
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
