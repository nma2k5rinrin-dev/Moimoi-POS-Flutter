-- Create functions to handle account overlap checks and forgotten password blocked checks
-- File: e:\Moimoi-POS-Flutter\supabase\migrations\20260415000001_check_registration_and_forgot_password.sql

-- 1. Check if email, username, or phone already exist (including deleted ones)
CREATE OR REPLACE FUNCTION public.check_registration_overlap(
    p_username text,
    p_phone text,
    p_email text
) RETURNS boolean AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username OR phone = p_phone) THEN
        RETURN true;
    END IF;
    
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Check if the provided email belongs to an account that is already deleted
CREATE OR REPLACE FUNCTION public.check_deleted_email(
    p_email text
) RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users pu
        JOIN auth.users au ON pu.id = au.id
        WHERE au.email = p_email AND pu.deleted_at IS NOT NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
