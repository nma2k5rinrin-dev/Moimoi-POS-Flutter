-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Allow anonymous users (QR customers) to insert orders
-- DESCRIPTION: QR web app customers are not authenticated. They use
-- the Supabase anon key to place orders. Without this policy, RLS
-- blocks their INSERT and the POS never receives QR orders.
-- ═══════════════════════════════════════════════════════════

-- 1. Allow anonymous to INSERT orders (QR menu customers)
CREATE POLICY "anon_insert_orders" ON orders
  FOR INSERT
  WITH CHECK (auth.role() = 'anon');

-- 2. Allow anonymous to SELECT products (QR menu needs to show products)
CREATE POLICY "anon_read_products" ON products
  FOR SELECT
  USING (auth.role() = 'anon');

-- 3. Allow anonymous to SELECT categories (QR menu needs categories)
CREATE POLICY "anon_read_categories" ON categories
  FOR SELECT
  USING (auth.role() = 'anon');

-- 4. Allow anonymous to SELECT store_infos (QR menu needs store name)
CREATE POLICY "anon_read_store_infos" ON store_infos
  FOR SELECT
  USING (auth.role() = 'anon');
