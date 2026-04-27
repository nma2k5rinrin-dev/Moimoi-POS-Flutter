-- ============================================================================
-- SECURITY FIX: Block anon users from reading `users` and `transactions`
-- The pentest revealed that `anon` could read users and transactions.
-- We explicitly drop any public policies and enforce strict authenticated access.
-- ============================================================================

-- Force ENABLE RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- ─── DROP ALL SELECT POLICIES THAT GRANT ACCESS TO EVERYONE OR ANON ───
DO $$
DECLARE pol RECORD;
BEGIN
    -- users table
    FOR pol IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'users' 
          AND cmd IN ('SELECT', 'ALL') 
          AND (roles @> ARRAY['public'::name] OR roles @> ARRAY['anon'::name])
    LOOP 
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.users', pol.policyname);
    END LOOP;

    -- transactions table
    FOR pol IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'transactions' 
          AND cmd IN ('SELECT', 'ALL') 
          AND (roles @> ARRAY['public'::name] OR roles @> ARRAY['anon'::name])
    LOOP 
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.transactions', pol.policyname);
    END LOOP;
END $$;

-- If there are any stray "using (true)" policies that apply to public, we should recreate them strictly to authenticated only.
DROP POLICY IF EXISTS "Public read access" ON public.users;
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;

CREATE POLICY "users_select_authenticated"
    ON public.users FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "transactions_select_public" ON public.transactions;
DROP POLICY IF EXISTS "transactions_select_authenticated" ON public.transactions;

CREATE POLICY "transactions_select_authenticated"
    ON public.transactions FOR SELECT TO authenticated USING (true);

NOTIFY pgrst, 'reload schema';
