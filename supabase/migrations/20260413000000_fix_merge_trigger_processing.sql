-- ═══════════════════════════════════════════════════════════
-- CLEANUP: Remove obsolete 'cooking' function & old migration trigger
-- The active trigger is fn_merge_qr_orders_after_insert() from FIX_DB_MERGE_V3
-- which already uses 'processing' correctly.
-- This script removes the orphaned function from the old migration.
-- ═══════════════════════════════════════════════════════════

-- Drop the OLD function that still references 'cooking' 
-- (created by 20260406 migration, no trigger calls it anymore)
DROP FUNCTION IF EXISTS public.merge_qr_order_after_insert() CASCADE;

-- Verify: the active trigger should be using fn_merge_qr_orders_after_insert()
-- You can check with:
-- SELECT tgname, tgfoid::regprocedure FROM pg_trigger WHERE tgrelid = 'public.orders'::regclass;
