-- Thêm cột đơn vị tính vào bảng products
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS "unit" text DEFAULT '' NOT NULL;

-- Thêm cột mô tả vào bảng categories
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS "description" text DEFAULT '' NOT NULL;
