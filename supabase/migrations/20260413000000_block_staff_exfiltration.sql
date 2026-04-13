-- ═══════════════════════════════════════════════════════════
-- CẬP NHẬT RLS CHỐNG LỘ DỮ LIỆU SỔ QUỸ (EXFILTRATION) CHO STAFF
-- ═══════════════════════════════════════════════════════════

-- Xoá policy cũ mở toang cửa cho toàn bộ Staff của Quán
DROP POLICY IF EXISTS "tenant_all_thuchi" ON thu_chi_transactions;

-- Tạo policy mới: CHỈ CÓ ADMIN (hoặc SADMIN) mới được phép SELECT/INSERT/UPDATE Sổ Quỹ
CREATE POLICY "tenant_all_thuchi" 
ON thu_chi_transactions FOR ALL 
USING (
    auth.role() = 'authenticated' 
    AND store_id = public.get_my_store() 
    AND public.get_my_role() IN ('admin', 'sadmin')
);
