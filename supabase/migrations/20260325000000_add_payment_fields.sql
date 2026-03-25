-- Add new columns to upgrade_requests table for payment flow
-- Run this in Supabase SQL Editor

ALTER TABLE upgrade_requests
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS transfer_content text DEFAULT '',
  ADD COLUMN IF NOT EXISTS amount integer DEFAULT 0;
