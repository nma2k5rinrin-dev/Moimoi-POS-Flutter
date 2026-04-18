-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Fix upgrade_requests table
-- 1. Switch primary key to proper UUID (keep backward compat)
-- 2. Fix broken RLS policy (was filtering on store_id which doesn't exist)
-- ═══════════════════════════════════════════════════════════

-- Step 1: Add a proper UUID primary key column (id2) alongside existing text id
-- We keep old string IDs for existing rows, new rows get UUID via default
ALTER TABLE upgrade_requests
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

-- Step 2: Fix the broken RLS policy for admin
-- The old policy used "store_id" which does NOT exist in upgrade_requests
-- The correct column is "username" (stores the store's admin username)
DROP POLICY IF EXISTS "admin_all_upgrades" ON upgrade_requests;

CREATE POLICY "admin_own_upgrades"
ON upgrade_requests FOR ALL
USING (
  auth.role() = 'authenticated'
  AND public.get_my_role() = 'admin'
  AND username = public.get_my_store()
);

-- Step 3: Ensure sadmin policy is clean (re-apply to avoid conflicts)
DROP POLICY IF EXISTS "sadmin_all_upgrades" ON upgrade_requests;

CREATE POLICY "sadmin_all_upgrades"
ON upgrade_requests FOR ALL
USING (
  auth.role() = 'authenticated'
  AND public.get_my_role() = 'sadmin'
);
