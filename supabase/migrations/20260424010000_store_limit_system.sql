-- ============================================================================
-- STORE LIMIT SYSTEM: Giới hạn số lượng cửa hàng, sadmin có thể điều chỉnh
-- ============================================================================

-- 1. Bảng cấu hình hệ thống
CREATE TABLE IF NOT EXISTS public.system_config (
    key text PRIMARY KEY,
    value text NOT NULL,
    updated_at timestamptz DEFAULT now()
);

-- Giá trị mặc định: 100 stores
INSERT INTO public.system_config (key, value)
VALUES ('max_stores', '20')
ON CONFLICT (key) DO NOTHING;

-- RLS: chỉ sadmin được UPDATE, tất cả authenticated được đọc
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "system_config_select_authenticated"
    ON public.system_config FOR SELECT TO authenticated USING (true);

CREATE POLICY "system_config_select_anon"
    ON public.system_config FOR SELECT TO anon USING (true);

CREATE POLICY "system_config_update_sadmin"
    ON public.system_config FOR UPDATE TO authenticated
    USING (
        current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role' = 'sadmin'
    );

-- 2. Trigger chặn tạo store khi vượt giới hạn + tự động gửi notification cho sadmin
CREATE OR REPLACE FUNCTION public.enforce_store_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_count int;
    max_count int;
BEGIN
    -- Chỉ check khi tạo admin mới (= store mới)
    IF NEW.role != 'admin' THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO current_count FROM public.users WHERE role = 'admin';
    SELECT COALESCE(value::int, 20) INTO max_count FROM public.system_config WHERE key = 'max_stores';

    IF current_count >= max_count THEN
        -- Gửi notification cho sadmin
        INSERT INTO public.notifications (id, user_id, title, message, time, read)
        VALUES (
            gen_random_uuid()::text,
            'sadmin',
            'Hệ thống đạt giới hạn cửa hàng',
            'Có người cố đăng ký nhưng đã đạt giới hạn ' || max_count || ' cửa hàng. Username: ' || NEW.username || ', Email đăng ký: ' || COALESCE(NEW.email, 'N/A'),
            now()::text,
            false
        );

        RAISE EXCEPTION 'STORE_LIMIT_REACHED: Hệ thống đã đạt giới hạn % cửa hàng', max_count;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_store_limit ON public.users;
CREATE TRIGGER trg_enforce_store_limit
    BEFORE INSERT ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_store_limit();

-- 3. RPC để app kiểm tra nhanh trước khi đăng ký (tránh tốn signUp request)
CREATE OR REPLACE FUNCTION public.check_store_limit()
RETURNS jsonb AS $$
DECLARE
    current_count int;
    max_count int;
BEGIN
    SELECT count(*) INTO current_count FROM public.users WHERE role = 'admin';
    SELECT COALESCE(value::int, 20) INTO max_count FROM public.system_config WHERE key = 'max_stores';

    RETURN jsonb_build_object(
        'current', current_count,
        'max', max_count,
        'available', current_count < max_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

NOTIFY pgrst, 'reload schema';
