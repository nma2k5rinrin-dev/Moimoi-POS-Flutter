-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Fix RLS helper functions + Rename thu_chi_transactions → transactions
-- ═══════════════════════════════════════════════════════════

-- 1. FIX RLS HELPER FUNCTIONS (dùng auth.uid() thay vì auth.jwt()->>'username')

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_store()
RETURNS text AS $$
  SELECT CASE 
    WHEN role = 'admin' THEN username 
    WHEN role = 'sadmin' THEN 'sadmin'
    ELSE created_by
  END
  FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 2. RENAME TABLE thu_chi_transactions → transactions
ALTER TABLE IF EXISTS thu_chi_transactions RENAME TO transactions;

-- 3. UPDATE RLS POLICIES (drop old, create new with correct table name)
DROP POLICY IF EXISTS "sadmin_all_thuchi" ON transactions;
DROP POLICY IF EXISTS "tenant_all_thuchi" ON transactions;

CREATE POLICY "sadmin_all_transactions" ON transactions FOR ALL 
  USING (auth.role() = 'authenticated' AND public.get_my_role() = 'sadmin');

CREATE POLICY "tenant_all_transactions" ON transactions FOR ALL 
  USING (auth.role() = 'authenticated' AND store_id = public.get_my_store());
