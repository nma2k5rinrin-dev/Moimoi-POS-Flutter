-- Supabase RPC Function for Egress Optimization: get_cashflow_summary
-- This function aggregates total income from `orders` and total income/expenses from `transactions` 
-- directly on the PostgreSQL server, returning a simple JSON object instead of thousands of rows.

CREATE OR REPLACE FUNCTION get_cashflow_summary(
    p_store_id text,
    p_start_date timestamp,
    p_end_date timestamp
) 
RETURNS json AS $$
DECLARE
    total_orders numeric;
    total_tx_income numeric;
    total_tx_expense numeric;
BEGIN
    -- 1. Tinh tong thu nhap tu bang orders (Da hoan thanh)
    SELECT COALESCE(SUM(total_amount), 0)
    INTO total_orders
    FROM public.orders
    WHERE store_id = p_store_id
      AND deleted_at IS NULL
      AND status = 'completed'
      AND time >= p_start_date
      AND time <= p_end_date;

    -- 2. Tinh tong thu nhap khac tu bang transactions
    SELECT COALESCE(SUM(amount), 0)
    INTO total_tx_income
    FROM public.transactions
    WHERE store_id = p_store_id
      AND deleted_at IS NULL
      AND type = 'income'
      AND time >= p_start_date
      AND time <= p_end_date;

    -- 3. Tinh tong chi phi tu bang transactions
    SELECT COALESCE(SUM(amount), 0)
    INTO total_tx_expense
    FROM public.transactions
    WHERE store_id = p_store_id
      AND deleted_at IS NULL
      AND type = 'expense'
      AND time >= p_start_date
      AND time <= p_end_date;

    -- Tra ve JSON ket qua
    RETURN json_build_object(
      'totalIncome', (total_orders + total_tx_income),
      'totalExpense', total_tx_expense
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
