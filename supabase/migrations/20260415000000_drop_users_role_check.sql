-- 20260415000000_drop_users_role_check.sql
-- Drop the legacy CHECK constraint on users.role that only allows fixed string values.
-- With custom roles (app_roles table), the role column now stores UUID values,
-- so this constraint must be removed.

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
