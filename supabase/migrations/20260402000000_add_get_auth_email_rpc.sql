-- LƯU Ý: Chạy file này trên SQL Editor của Supabase để khởi tạo tiện ích đăng nhập bằng Username

CREATE OR REPLACE FUNCTION public.get_auth_email(p_username text)
RETURNS text AS $$
DECLARE
    found_email text;
BEGIN
    SELECT a.email INTO found_email
    FROM auth.users a
    JOIN public.users p ON a.id = p.id
    WHERE p.username = p_username
    LIMIT 1;
    
    RETURN found_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
