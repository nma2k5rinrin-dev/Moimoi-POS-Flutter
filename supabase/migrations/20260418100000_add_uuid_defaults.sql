-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Add UUID defaults to all tables missing them
-- Tables: orders, transactions, products, categories,
--         notifications, premium_payments
-- Strategy: keep column type as TEXT (backward compat)
--           just add DEFAULT gen_random_uuid()::text
-- ═══════════════════════════════════════════════════════════

-- ORDERS
ALTER TABLE orders
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

-- TRANSACTIONS (thu_chi)
ALTER TABLE transactions
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

-- PRODUCTS
ALTER TABLE products
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

-- CATEGORIES
ALTER TABLE categories
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

-- NOTIFICATIONS
ALTER TABLE notifications
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

-- PREMIUM PAYMENTS (if exists)
ALTER TABLE premium_payments
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
