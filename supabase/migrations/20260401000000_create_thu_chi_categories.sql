-- Migration: Create thu_chi_categories table
-- Dùng để lưu danh mục thu/chi cho từng cửa hàng phòng trường hợp rớt dữ liệu cục bộ

CREATE TABLE IF NOT EXISTS thu_chi_categories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    store_id text NOT NULL,
    type text NOT NULL CHECK (type IN ('thu', 'chi')),
    emoji text NOT NULL,
    label text NOT NULL,
    color integer NOT NULL,
    is_custom boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

-- Bật Row Level Security
ALTER TABLE thu_chi_categories ENABLE ROW LEVEL SECURITY;

-- Tạo Policy chỉ cho phép đọc/ghi theo store_id
CREATE POLICY "Cho phép truy cập dựa trên store_id" ON thu_chi_categories
    FOR ALL
    USING (store_id = current_setting('request.jwt.claims', true)::json->>'store_id');
