-- ═══════════════════════════════════════════════════════════
-- SQL SCRIPT: Pentest Patch - Prevent Negative Amounts & Egress Mitigation
-- DESCRIPTION: Patches the security flaws found in the QR Ordering system where attackers could send negative total_amount.
-- ═══════════════════════════════════════════════════════════

-- 1. Prevent Negative Total Amounts
ALTER TABLE public.orders ADD CONSTRAINT enforce_positive_total CHECK (total_amount >= 0);

-- 2. Optional: We can write a PostgreSQL JSON check to ensure prices >= 0, but checking total_amount >= 0 is usually enough to prevent negative revenue recording.

-- 3. To limit egress spamming on orders, we can implement an IP tracking or Token bucket, but since anon doesn't have an IP column by default in Supabase, we rely on Cloudflare/Supabase WAF for pure DDoS protection.
