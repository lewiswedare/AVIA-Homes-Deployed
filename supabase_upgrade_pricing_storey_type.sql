-- Migration: Add storey_type to upgrade_pricing table
-- This differentiates full spec range upgrade pricing between single and double storey homes.

ALTER TABLE upgrade_pricing ADD COLUMN IF NOT EXISTS storey_type TEXT DEFAULT 'single';
