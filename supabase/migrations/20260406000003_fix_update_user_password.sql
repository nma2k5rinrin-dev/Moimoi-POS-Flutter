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
    SET encrypted_password = public.crypt(p_new_password, public.gen_salt('bf')),
        updated_at = now()
    WHERE id = target_id;

    -- Update trong public.users
    UPDATE public.users SET pass = p_new_password WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
