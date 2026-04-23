-- Chuyển store_id và role vào trong raw_app_meta_data của auth.users
-- Bước này giúp RLS đọc dữ liệu trực tiếp từ JWT thay vì tốn công truy vấn vào bảng public.users

-- 1. Backfill dữ liệu vào JWT claim cho toàn bộ users đang có
DO $$
DECLARE
  r RECORD;
  computed_store text;
BEGIN
  FOR r IN SELECT * FROM public.users
  LOOP
    IF r.role = 'sadmin' THEN
      computed_store := 'sadmin';
    ELSIF r.role = 'admin' THEN
      computed_store := r.username;
    ELSE
      computed_store := r.created_by;
    END IF;

    UPDATE auth.users
    SET raw_app_meta_data = jsonb_set(
          jsonb_set(
            COALESCE(raw_app_meta_data, '{}'::jsonb),
            '{store_id}',
            to_jsonb(computed_store)
          ),
          '{app_role}',
          to_jsonb(r.role)
        )
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- 2. Đảm bảo mọi user TƯƠNG LAI cập nhật cũng sẽ tự động add JWT claim
CREATE OR REPLACE FUNCTION public.update_user_jwt_claims()
RETURNS TRIGGER AS $$
DECLARE
  computed_store text;
BEGIN
  -- Logic y hệt get_my_store()
  IF NEW.role = 'sadmin' THEN
    computed_store := 'sadmin';
  ELSIF NEW.role = 'admin' THEN
    computed_store := NEW.username;
  ELSE
    computed_store := NEW.created_by;
  END IF;

  UPDATE auth.users
  SET raw_app_meta_data = jsonb_set(
        jsonb_set(
          COALESCE(raw_app_meta_data, '{}'::jsonb),
          '{store_id}',
          to_jsonb(computed_store)
        ),
        '{app_role}',
        to_jsonb(NEW.role)
      )
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_user_jwt_claims ON public.users;
CREATE TRIGGER trigger_update_user_jwt_claims
AFTER INSERT OR UPDATE OF role, username, created_by 
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.update_user_jwt_claims();

-- 3. Viết lại tất cả Helper Functions của RLS
-- Lọc từ JWT token TỐC ĐỘ CAO trước, nếu vì lý do nào đó JWT bị thiếu (token cũ) thì mới Fallback lại query chậm.

-- A) get_my_role_uuid()
CREATE OR REPLACE FUNCTION public.get_my_role_uuid()
RETURNS text AS $$
DECLARE
  jwt_val text;
  db_val text;
BEGIN
  -- Bước 1: 99% trường hợp sẽ RETURN ngay tại đây mà không tốn Disk IO
  jwt_val := current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role';
  IF jwt_val IS NOT NULL THEN
    RETURN jwt_val;
  END IF;

  -- Bước 2: Fallback (Chậm)
  SELECT role INTO db_val FROM public.users WHERE id = auth.uid() LIMIT 1;
  RETURN db_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- B) get_my_store_uuid()
CREATE OR REPLACE FUNCTION public.get_my_store_uuid()
RETURNS text AS $$
DECLARE
  jwt_val text;
  db_val text;
BEGIN
  jwt_val := current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'store_id';
  IF jwt_val IS NOT NULL THEN
    RETURN jwt_val;
  END IF;

  SELECT CASE 
    WHEN role = 'admin' THEN username 
    WHEN role = 'sadmin' THEN 'sadmin'
    ELSE created_by 
  END INTO db_val
  FROM public.users WHERE id = auth.uid() LIMIT 1;

  RETURN db_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- C) get_my_role() (Legacy function dựa trên user_metadata/username nếu có dùng)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
DECLARE
  jwt_val text;
  db_val text;
BEGIN
  jwt_val := current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'app_role';
  IF jwt_val IS NOT NULL THEN
    RETURN jwt_val;
  END IF;

  SELECT role INTO db_val FROM public.users WHERE username = (auth.jwt() ->> 'username')::text LIMIT 1;
  RETURN db_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- D) get_my_store() (Legacy function dựa trên user_metadata/username)
CREATE OR REPLACE FUNCTION public.get_my_store()
RETURNS text AS $$
DECLARE
  jwt_val text;
  db_val text;
BEGIN
  jwt_val := current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'store_id';
  IF jwt_val IS NOT NULL THEN
    RETURN jwt_val;
  END IF;

  SELECT CASE 
    WHEN role = 'admin' THEN username 
    WHEN role = 'sadmin' THEN 'sadmin'
    ELSE created_by 
  END INTO db_val
  FROM public.users WHERE username = (auth.jwt() ->> 'username')::text LIMIT 1;

  RETURN db_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Nạp lại schema cache của PostgREST
NOTIFY pgrst, 'reload schema';
