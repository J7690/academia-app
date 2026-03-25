-- ============================================================
-- PHASE 1 — Marketplace Consolidation Migration
-- Date: 2026-03-14
-- Description: Enrichit marketplace_listings, fusionne merchant_profiles
--   dans marketplace_merchants, crée marketplace_reviews/payments/balances,
--   ajoute listing_id sur les tables sociales.
-- IMPORTANT: Ne casse RIEN de l'existant. Ajouts uniquement.
-- ============================================================

-- ============================================================
-- 1.3.1 — Fusionner merchant_profiles dans marketplace_merchants
--   Ajouter les colonnes manquantes de merchant_profiles
-- ============================================================

ALTER TABLE app.marketplace_merchants
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_level TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS rating_avg NUMERIC(2,1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_sales INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_products INT NOT NULL DEFAULT 0;

-- Copier les données de merchant_profiles vers marketplace_merchants
-- (seulement si le merchant existe dans les deux tables)
UPDATE app.marketplace_merchants mm
SET
  is_verified = mp.is_verified,
  verification_level = mp.verification_level,
  bio = COALESCE(mm.description, mp.bio),
  display_name = mp.display_name
FROM app.merchant_profiles mp
WHERE mm.owner_user_id = mp.user_id
  AND mm.display_name IS NULL;

-- ============================================================
-- 1.3.2 — Enrichir marketplace_listings
--   Ajouter les colonnes manquantes pour le marketplace Amazon/Alibaba
-- ============================================================

ALTER TABLE app.marketplace_listings
  ADD COLUMN IF NOT EXISTS cover_url TEXT,
  ADD COLUMN IF NOT EXISTS video_url TEXT,
  ADD COLUMN IF NOT EXISTS rating_avg NUMERIC(2,1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sales_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS views_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reactions_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comments_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tags TEXT[],
  ADD COLUMN IF NOT EXISTS specifications JSONB,
  ADD COLUMN IF NOT EXISTS variants JSONB;

-- Initialiser cover_url depuis le premier média actif (sort_order le plus bas)
UPDATE app.marketplace_listings ml
SET cover_url = sub.public_url
FROM (
  SELECT DISTINCT ON (m.listing_id)
    m.listing_id,
    CASE
      WHEN m.external_url IS NOT NULL AND m.external_url != '' THEN m.external_url
      ELSE 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/' || m.storage_bucket || '/' || m.storage_path
    END AS public_url
  FROM app.marketplace_listing_media m
  WHERE m.is_active = true AND m.media_type = 'image'
  ORDER BY m.listing_id, m.sort_order ASC, m.created_at ASC
) sub
WHERE ml.id = sub.listing_id
  AND ml.cover_url IS NULL;

-- ============================================================
-- 1.3.4 — Créer table marketplace_reviews
-- ============================================================

CREATE TABLE IF NOT EXISTS app.marketplace_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES app.marketplace_listings(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id UUID REFERENCES app.marketplace_orders(id) ON DELETE SET NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title TEXT,
  content TEXT,
  media_urls TEXT[],
  is_verified_purchase BOOLEAN NOT NULL DEFAULT FALSE,
  seller_reply TEXT,
  seller_replied_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Un seul avis par acheteur par commande par produit
CREATE UNIQUE INDEX IF NOT EXISTS idx_marketplace_reviews_unique
  ON app.marketplace_reviews(listing_id, buyer_id, order_id)
  WHERE order_id IS NOT NULL;

-- Index pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_marketplace_reviews_listing
  ON app.marketplace_reviews(listing_id, is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_reviews_buyer
  ON app.marketplace_reviews(buyer_id, created_at DESC);

-- ============================================================
-- 1.3.5 — Créer table marketplace_payments (structure, pas de RPCs)
-- ============================================================

CREATE TABLE IF NOT EXISTS app.marketplace_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES app.marketplace_orders(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES auth.users(id),
  merchant_id UUID NOT NULL REFERENCES app.marketplace_merchants(id),
  gross_amount NUMERIC NOT NULL,
  commission_rate NUMERIC NOT NULL DEFAULT 0.10,
  commission_amount NUMERIC NOT NULL DEFAULT 0,
  net_amount NUMERIC NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'XOF',
  payment_method TEXT,
  payment_provider TEXT,
  payment_provider_ref TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  escrow_released_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_payments_order
  ON app.marketplace_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_payments_merchant
  ON app.marketplace_payments(merchant_id, status);
CREATE INDEX IF NOT EXISTS idx_marketplace_payments_status
  ON app.marketplace_payments(status, created_at DESC);

-- ============================================================
-- 1.3.6 — Créer table marketplace_merchant_balances (structure)
-- ============================================================

CREATE TABLE IF NOT EXISTS app.marketplace_merchant_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES app.marketplace_merchants(id) ON DELETE CASCADE UNIQUE,
  available_balance NUMERIC NOT NULL DEFAULT 0,
  pending_balance NUMERIC NOT NULL DEFAULT 0,
  total_earned NUMERIC NOT NULL DEFAULT 0,
  total_commission NUMERIC NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'XOF',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 1.3.7 — Ajouter listing_id sur les tables sociales
--   (pour qu'elles puissent cibler marketplace_listings
--    sans casser les FK existantes vers opportunities)
-- ============================================================

-- opportunity_reactions: ajouter listing_id
ALTER TABLE app.opportunity_reactions
  ADD COLUMN IF NOT EXISTS listing_id UUID REFERENCES app.marketplace_listings(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_opportunity_reactions_listing
  ON app.opportunity_reactions(listing_id, reaction_type)
  WHERE listing_id IS NOT NULL;

-- opportunity_comments: ajouter listing_id
ALTER TABLE app.opportunity_comments
  ADD COLUMN IF NOT EXISTS listing_id UUID REFERENCES app.marketplace_listings(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_opportunity_comments_listing
  ON app.opportunity_comments(listing_id, created_at DESC)
  WHERE listing_id IS NOT NULL;

-- opportunity_bookmarks: ajouter listing_id
ALTER TABLE app.opportunity_bookmarks
  ADD COLUMN IF NOT EXISTS listing_id UUID REFERENCES app.marketplace_listings(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_opportunity_bookmarks_listing
  ON app.opportunity_bookmarks(listing_id)
  WHERE listing_id IS NOT NULL;

-- ============================================================
-- 1.3.8 — Index supplémentaires pour performance marketplace
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_review_status_active
  ON app.marketplace_listings(review_status, is_active)
  WHERE review_status = 'approved' AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_merchant
  ON app.marketplace_listings(merchant_id);

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_category
  ON app.marketplace_listings(category_id)
  WHERE category_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_rating
  ON app.marketplace_listings(rating_avg DESC, rating_count DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_sales
  ON app.marketplace_listings(sales_count DESC);

-- ============================================================
-- 1.3.9 — RLS sur les nouvelles tables
-- ============================================================

ALTER TABLE app.marketplace_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.marketplace_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.marketplace_merchant_balances ENABLE ROW LEVEL SECURITY;

-- Reviews: tout le monde peut lire les avis actifs
CREATE POLICY marketplace_reviews_select ON app.marketplace_reviews
  FOR SELECT USING (is_active = true);

-- Reviews: un acheteur peut créer un avis
CREATE POLICY marketplace_reviews_insert ON app.marketplace_reviews
  FOR INSERT WITH CHECK (buyer_id = auth.uid());

-- Reviews: un acheteur peut modifier son propre avis
CREATE POLICY marketplace_reviews_update ON app.marketplace_reviews
  FOR UPDATE USING (buyer_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM app.marketplace_listings ml
      JOIN app.marketplace_merchants mm ON mm.id = ml.merchant_id
      WHERE ml.id = app.marketplace_reviews.listing_id
        AND mm.owner_user_id = auth.uid()
    ));

-- Payments: lecture par le buyer ou le merchant concerné
CREATE POLICY marketplace_payments_select ON app.marketplace_payments
  FOR SELECT USING (
    buyer_id = auth.uid() OR
    merchant_id IN (SELECT id FROM app.marketplace_merchants WHERE owner_user_id = auth.uid())
  );

-- Balances: lecture par le merchant propriétaire
CREATE POLICY marketplace_merchant_balances_select ON app.marketplace_merchant_balances
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM app.marketplace_merchants WHERE owner_user_id = auth.uid())
  );

-- ============================================================
-- DONE — Phase 1 migration
-- ============================================================
