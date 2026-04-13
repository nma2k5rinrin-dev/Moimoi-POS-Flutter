ALTER TABLE custom_transaction_categories
ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;
