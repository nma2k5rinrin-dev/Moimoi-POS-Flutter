-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: MIGRATE OLD USERS TO SUPABASE AUTH
-- DESCRIPTION: Chuyển đổi hàng loạt user cũ vào hệ thống Auth
-- ═══════════════════════════════════════════════════════════

-- Bật pgcrypto trong schema public (nếu chưa có)
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;

DO $$
DECLARE
    r RECORD;
    new_uuid uuid;
BEGIN
    FOR r IN SELECT * FROM public.users WHERE id IS NULL LOOP
        new_uuid := gen_random_uuid();
        
        -- Insert vào Auth
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, 
            email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, 
            created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000', new_uuid, 'authenticated', 'authenticated', 
            (LOWER(REPLACE(r.username, ' ', '')) || '@moimoi.local'), 
            crypt(r.pass, gen_salt('bf')), 
            now(), now(), now(), '{}', '{}', 
            now(), now(), '', '', '', ''
        );

        -- Update lại ID trong public.users
        UPDATE public.users SET id = new_uuid WHERE username = r.username;
    END LOOP;
END;
$$;
