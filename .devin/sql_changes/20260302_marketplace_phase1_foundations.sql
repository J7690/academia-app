-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 1: FOUNDATIONS (DB ONLY)
--
-- Objectifs:
-- - Ajouter le rôle Commerçant (côté DB via merchant_profiles)
-- - Relier une opportunité à un commerçant (merchant_id)
-- - Ajouter des champs marketplace (MOQ, ready_to_ship, lead_time, pricing range)
-- - Introduire les demandes (inquiries) + messages
--
-- Notes:
-- - Les policies RLS et RPC seront ajoutées en Phase 2.
-- - Ce script ne change pas les policies existantes.
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- =============================
-- 1) MERCHANT PROFILES
-- =============================
CREATE TABLE IF NOT EXISTS app.merchant_profiles (
  user_id UUID PRIMARY KEY,
  display_name TEXT NOT NULL,
  logo_url TEXT,
  bio TEXT,
  country TEXT,
  city TEXT,
  is_verified BOOLEAN DEFAULT FALSE NOT NULL,
  verification_level TEXT DEFAULT 'none' NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_is_active
ON app.merchant_profiles(is_active);

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_verification
ON app.merchant_profiles(is_verified, verification_level);

-- =============================
-- 2) EXTEND OPPORTUNITIES
-- =============================
ALTER TABLE app.opportunities
  ADD COLUMN IF NOT EXISTS merchant_id UUID,
  ADD COLUMN IF NOT EXISTS review_status TEXT DEFAULT 'draft' NOT NULL,
  ADD COLUMN IF NOT EXISTS review_reason TEXT,
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID,
  ADD COLUMN IF NOT EXISTS price_from NUMERIC,
  ADD COLUMN IF NOT EXISTS price_to NUMERIC,
  ADD COLUMN IF NOT EXISTS currency TEXT,
  ADD COLUMN IF NOT EXISTS min_order_qty INTEGER,
  ADD COLUMN IF NOT EXISTS lead_time_days INTEGER,
  ADD COLUMN IF NOT EXISTS is_ready_to_ship BOOLEAN DEFAULT FALSE NOT NULL;

CREATE INDEX IF NOT EXISTS idx_opportunities_merchant_id
ON app.opportunities(merchant_id);

CREATE INDEX IF NOT EXISTS idx_opportunities_review_status
ON app.opportunities(review_status);

-- =============================
-- 3) INQUIRIES (CONTACT / RFQ LIGHT)
-- =============================
CREATE TABLE IF NOT EXISTS app.opportunity_inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id UUID NOT NULL REFERENCES app.opportunities(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL,
  merchant_id UUID NOT NULL,
  message TEXT NOT NULL,
  quantity INTEGER,
  budget NUMERIC,
  status TEXT DEFAULT 'open' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  last_message_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_opportunity_inquiries_opportunity_id
ON app.opportunity_inquiries(opportunity_id);

CREATE INDEX IF NOT EXISTS idx_opportunity_inquiries_merchant_id
ON app.opportunity_inquiries(merchant_id, status, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_opportunity_inquiries_buyer_id
ON app.opportunity_inquiries(buyer_id, last_message_at DESC);

-- =============================
-- 4) INQUIRY MESSAGES
-- =============================
CREATE TABLE IF NOT EXISTS app.opportunity_inquiry_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inquiry_id UUID NOT NULL REFERENCES app.opportunity_inquiries(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_opportunity_inquiry_messages_inquiry_id
ON app.opportunity_inquiry_messages(inquiry_id, created_at DESC);
