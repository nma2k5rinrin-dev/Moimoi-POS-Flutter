-- Add show_total_products column to store_infos table
ALTER TABLE public.store_infos
ADD COLUMN IF NOT EXISTS show_total_products BOOLEAN NOT NULL DEFAULT true;
