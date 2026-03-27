-- Add sadmin management columns to store_infos table
-- Run this in Supabase SQL Editor

ALTER TABLE store_infos
  ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS premium_activated_at timestamptz,
  ADD COLUMN IF NOT EXISTS premium_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS total_offline_days integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
