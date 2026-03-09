-- ========================================
-- ACADEMIA - PHASE 2B (Option A: 2 tables)
-- Create app.marketplace_listings and prepare a safe migration path
-- - Keep existing app.opportunities untouched for now (Flutter compatibility)
-- - Backfill marketplace listings from opportunities where merchant_id is not null
-- - Add listing_id to app.opportunity_inquiries (nullable) + FK + backfill
-- ========================================

-- 1) New table: marketplace_listings
CREATE TABLE IF NOT EXISTS app.marketplace_listings (
  id UUID PRIMARY KEY,

  -- Ownership / governance
  merchant_id UUID NOT NULL,
  review_status TEXT NOT NULL DEFAULT 'draft',
  review_reason TEXT NULL,
  submitted_at TIMESTAMPTZ NULL,
  reviewed_at TIMESTAMPTZ NULL,
  reviewed_by UUID NULL,

  -- Shared content fields (kept for backwards compatibility with existing UI)
  title TEXT NOT NULL,
  short_description TEXT NOT NULL,
  description TEXT NULL,
  type TEXT NOT NULL,
  category TEXT NULL,
  organization_name TEXT NOT NULL,
  organization_logo_url TEXT NULL,
  country TEXT NOT NULL,
  city TEXT NOT NULL,

  -- Marketplace fields
  price_from NUMERIC NULL,
  price_to NUMERIC NULL,
  currency TEXT NULL,
  min_order_qty INTEGER NULL,
  lead_time_days INTEGER NULL,
  is_ready_to_ship BOOLEAN NOT NULL DEFAULT FALSE,

  -- Social counters (kept aligned later)
  reactions_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,

  -- Publication
  status TEXT NOT NULL DEFAULT 'draft',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_merchant_id
  ON app.marketplace_listings(merchant_id);

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_review_status
  ON app.marketplace_listings(review_status);

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_status_active
  ON app.marketplace_listings(status, is_active);

-- 2) RLS (safe defaults)
ALTER TABLE app.marketplace_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_published_marketplace_listings ON app.marketplace_listings;
CREATE POLICY public_select_published_marketplace_listings
  ON app.marketplace_listings
  FOR SELECT
  TO public
  USING (
    is_active = TRUE
    AND status = 'published'
    AND review_status = 'approved'
  );

DROP POLICY IF EXISTS merchant_select_own_marketplace_listings ON app.marketplace_listings;
CREATE POLICY merchant_select_own_marketplace_listings
  ON app.marketplace_listings
  FOR SELECT
  TO authenticated
  USING (merchant_id = auth.uid());

DROP POLICY IF EXISTS merchant_insert_own_marketplace_listings ON app.marketplace_listings;
CREATE POLICY merchant_insert_own_marketplace_listings
  ON app.marketplace_listings
  FOR INSERT
  TO authenticated
  WITH CHECK (merchant_id = auth.uid());

DROP POLICY IF EXISTS merchant_update_own_marketplace_listings ON app.marketplace_listings;
CREATE POLICY merchant_update_own_marketplace_listings
  ON app.marketplace_listings
  FOR UPDATE
  TO authenticated
  USING (merchant_id = auth.uid())
  WITH CHECK (merchant_id = auth.uid());

-- 3) Backfill listings from opportunities (marketplace rows only)
INSERT INTO app.marketplace_listings (
  id,
  merchant_id,
  review_status,
  review_reason,
  submitted_at,
  reviewed_at,
  reviewed_by,

  title,
  short_description,
  description,
  type,
  category,
  organization_name,
  organization_logo_url,
  country,
  city,

  price_from,
  price_to,
  currency,
  min_order_qty,
  lead_time_days,
  is_ready_to_ship,

  reactions_count,
  comments_count,

  status,
  is_active,
  is_featured,

  created_at,
  updated_at
)
SELECT
  o.id,
  o.merchant_id,
  o.review_status,
  o.review_reason,
  o.submitted_at,
  o.reviewed_at,
  o.reviewed_by,

  o.title,
  o.short_description,
  o.description,
  o.type,
  o.category,
  o.organization_name,
  o.organization_logo_url,
  o.country,
  o.city,

  o.price_from,
  o.price_to,
  o.currency,
  o.min_order_qty,
  o.lead_time_days,
  o.is_ready_to_ship,

  o.reactions_count,
  o.comments_count,

  o.status,
  o.is_active,
  o.is_featured,

  o.created_at,
  o.updated_at
FROM app.opportunities o
WHERE o.merchant_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM app.marketplace_listings l
    WHERE l.id = o.id
  );

-- 4) Prepare inquiries migration path
ALTER TABLE app.opportunity_inquiries
  ADD COLUMN IF NOT EXISTS listing_id UUID NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'app'
      AND table_name = 'opportunity_inquiries'
      AND constraint_name = 'opportunity_inquiries_listing_id_fkey'
  ) THEN
    ALTER TABLE app.opportunity_inquiries
      ADD CONSTRAINT opportunity_inquiries_listing_id_fkey
      FOREIGN KEY (listing_id)
      REFERENCES app.marketplace_listings(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_opportunity_inquiries_listing_id
  ON app.opportunity_inquiries(listing_id);

-- Backfill listing_id = opportunity_id where opportunity refers to marketplace listing
UPDATE app.opportunity_inquiries i
SET listing_id = i.opportunity_id
WHERE i.listing_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM app.marketplace_listings l
    WHERE l.id = i.opportunity_id
  );
