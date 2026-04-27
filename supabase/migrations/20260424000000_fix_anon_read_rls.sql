-- ============================================================================
-- SECURITY FIX: Chặn anon đọc products, categories, transactions
-- Tạo view categories_public cho web QR menu (giống products_public đã có)
-- ============================================================================

-- ─── PRODUCTS: Chặn anon, chỉ cho authenticated ─────────────────────────────
DO $$
DECLARE pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'products' AND cmd = 'SELECT'
    LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.products', pol.policyname);
    END LOOP;
END $$;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "products_select_authenticated"
    ON public.products FOR SELECT TO authenticated USING (true);

-- ─── CATEGORIES: Chặn anon, tạo view cho QR menu ────────────────────────────
DO $$
DECLARE pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'categories' AND cmd = 'SELECT'
    LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.categories', pol.policyname);
    END LOOP;
END $$;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categories_select_authenticated"
    ON public.categories FOR SELECT TO authenticated USING (true);

-- View cho anon (web QR menu)
CREATE OR REPLACE VIEW public.categories_public AS
    SELECT id, store_id, name, emoji, color
    FROM public.categories
    WHERE deleted_at IS NULL;

GRANT SELECT ON public.categories_public TO anon;

-- ─── TRANSACTIONS: Chặn anon ────────────────────────────────────────────────
DO $$
DECLARE pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'transactions' AND cmd = 'SELECT'
    LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.transactions', pol.policyname);
    END LOOP;
END $$;

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "transactions_select_authenticated"
    ON public.transactions FOR SELECT TO authenticated USING (true);

NOTIFY pgrst, 'reload schema';
