-- 1. Add deleted_at column to users table for soft-delete (account deletion)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON public.users(deleted_at);

-- 2. RPC function: allows a user to soft-delete their OWN account
-- If the caller is an admin, hard-deletes ALL store data and staff auth accounts.
-- Runs as SECURITY DEFINER to bypass RLS.
CREATE OR REPLACE FUNCTION public.soft_delete_own_account()
RETURNS void AS $$
DECLARE
    my_username text;
    my_role text;
    staff_record RECORD;
BEGIN
    SELECT username, role INTO my_username, my_role
    FROM public.users WHERE id = auth.uid();

    IF my_username IS NULL THEN
        RETURN;
    END IF;

    -- If admin, nuke all store data and staff accounts
    IF my_role = 'admin' THEN
        -- Delete all store data (hard delete)
        DELETE FROM public.orders WHERE store_id = my_username;
        DELETE FROM public.products WHERE store_id = my_username;
        DELETE FROM public.categories WHERE store_id = my_username;
        DELETE FROM public.transactions WHERE store_id = my_username;
        DELETE FROM public.transaction_categories WHERE store_id = my_username;
        DELETE FROM public.app_roles WHERE store_id = my_username;
        DELETE FROM public.store_infos WHERE store_id = my_username;

        -- Delete all staff auth accounts (cascade deletes public.users rows too)
        FOR staff_record IN
            SELECT id FROM public.users
            WHERE created_by = my_username AND id != auth.uid()
        LOOP
            DELETE FROM auth.users WHERE id = staff_record.id;
        END LOOP;
    END IF;

    -- Soft-delete the caller's own row
    UPDATE public.users
    SET deleted_at = now()
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
