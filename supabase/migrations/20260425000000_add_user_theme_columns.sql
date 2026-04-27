-- Add theme preferences to users table for cross-device sync
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS app_theme integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_dark_mode boolean DEFAULT false;

COMMENT ON COLUMN public.users.app_theme IS 'Theme index: 0=emerald, 1=blue, 2=violet, 3=amber, 4=rose';
COMMENT ON COLUMN public.users.is_dark_mode IS 'Dark mode preference';
