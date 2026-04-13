-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Add deleted_at for Soft Deletes Mechanism
-- ═══════════════════════════════════════════════════════════

-- 1. Add deleted_at column to primary tracking tables
ALTER TABLE public.orders ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
ALTER TABLE public.products ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
ALTER TABLE public.categories ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
ALTER TABLE public.transactions ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- 2. Optional: Index the new columns for faster "IS NULL" filtering
CREATE INDEX idx_orders_deleted_at ON public.orders(deleted_at);
CREATE INDEX idx_products_deleted_at ON public.products(deleted_at);
CREATE INDEX idx_categories_deleted_at ON public.categories(deleted_at);
CREATE INDEX idx_transactions_deleted_at ON public.transactions(deleted_at);
