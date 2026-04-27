-- ═══════════════════════════════════════════════════════════
-- MIGRATION: Allow anon to SELECT own table's active orders
-- DESCRIPTION: QR menu customers need to see previously ordered
-- items at their table. Scoped to unpaid, active orders only.
-- ═══════════════════════════════════════════════════════════

CREATE POLICY "anon_read_active_orders" ON orders
  FOR SELECT
  USING (
    auth.role() = 'anon'
    AND payment_status = 'unpaid'
    AND status IN ('pending', 'processing')
    AND deleted_at IS NULL
  );
