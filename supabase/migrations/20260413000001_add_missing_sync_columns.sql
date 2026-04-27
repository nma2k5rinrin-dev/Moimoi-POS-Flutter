-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: FIX MISSING COLUMNS FOR OFFLINE DELTA SYNC
-- ═══════════════════════════════════════════════════════════

-- 1. Add created_at and updated_at to store_infos
ALTER TABLE "public"."store_infos" ADD COLUMN IF NOT EXISTS "created_at" timestamp with time zone DEFAULT now();
ALTER TABLE "public"."store_infos" ADD COLUMN IF NOT EXISTS "updated_at" timestamp with time zone DEFAULT now();

-- 2. Add created_at and updated_at to products
ALTER TABLE "public"."products" ADD COLUMN IF NOT EXISTS "created_at" timestamp with time zone DEFAULT now();
ALTER TABLE "public"."products" ADD COLUMN IF NOT EXISTS "updated_at" timestamp with time zone DEFAULT now();

-- 3. Add updated_at to categories
ALTER TABLE "public"."categories" ADD COLUMN IF NOT EXISTS "updated_at" timestamp with time zone DEFAULT now();

-- 4. Fix policy evaluating non-existent function from block_staff_exfiltration.sql
DROP POLICY IF EXISTS "tenant_all_thuchi" ON transactions;

CREATE POLICY "tenant_all_thuchi" 
ON transactions FOR ALL 
USING (
    auth.role() = 'authenticated' 
    AND store_id = public.get_my_store_uuid() 
    AND public.get_my_role_uuid() IN ('admin', 'sadmin')
);
