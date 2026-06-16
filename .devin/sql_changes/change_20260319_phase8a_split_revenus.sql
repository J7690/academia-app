-- ============================================================================
-- PHASE 8A — Split revenus configurable + colonnes paiement acteurs
-- 19 Mars 2026
-- Basé sur audit réel : instructors(5 cols), td_teachers(10), marketplace_merchants(24), universities(20)
-- ============================================================================

-- ============================================================
-- SECTION A : COLONNES PAIEMENT SUR TABLES ACTEURS
-- ============================================================

-- A1. instructors (actuellement : id, full_name, bio, created_at, updated_at)
ALTER TABLE app.instructors
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS payout_phone TEXT,
  ADD COLUMN IF NOT EXISTS payout_operator TEXT,
  ADD COLUMN IF NOT EXISTS speciality TEXT;

-- A2. td_teachers (actuellement : id, user_id, full_name, discipline, zone, levels, availability, status, created_at, updated_at)
ALTER TABLE app.td_teachers
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS payout_phone TEXT,
  ADD COLUMN IF NOT EXISTS payout_operator TEXT;

-- A3. marketplace_merchants (24 cols, a contact_phone mais pas payout_phone)
ALTER TABLE app.marketplace_merchants
  ADD COLUMN IF NOT EXISTS payout_phone TEXT,
  ADD COLUMN IF NOT EXISTS payout_operator TEXT;

-- A4. universities (20 cols, a contact_phone mais pas payout_phone)
ALTER TABLE app.universities
  ADD COLUMN IF NOT EXISTS payout_phone TEXT,
  ADD COLUMN IF NOT EXISTS payout_operator TEXT,
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS bank_account TEXT;

-- ============================================================
-- SECTION B : TABLE revenue_split_rules
-- ============================================================

CREATE TABLE IF NOT EXISTS app.revenue_split_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_reason TEXT NOT NULL,
  beneficiary_type TEXT NOT NULL,
  percentage NUMERIC NOT NULL,
  max_amount NUMERIC,
  min_amount NUMERIC DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  description TEXT,
  priority INTEGER NOT NULL DEFAULT 10,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(payment_reason, beneficiary_type)
);

ALTER TABLE app.revenue_split_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY rsr_admin_all ON app.revenue_split_rules FOR ALL TO public USING (
  (auth.jwt() ? 'role') AND (auth.jwt() ->> 'role') = 'admin'
);
CREATE POLICY rsr_select_all ON app.revenue_split_rules FOR SELECT TO public USING (true);

CREATE INDEX IF NOT EXISTS idx_rsr_payment_reason ON app.revenue_split_rules(payment_reason);

-- ============================================================
-- SECTION C : TABLE actor_balances
-- ============================================================

CREATE TABLE IF NOT EXISTS app.actor_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_type TEXT NOT NULL,
  actor_id UUID NOT NULL,
  available_balance NUMERIC NOT NULL DEFAULT 0,
  pending_balance NUMERIC NOT NULL DEFAULT 0,
  total_earned NUMERIC NOT NULL DEFAULT 0,
  total_withdrawn NUMERIC NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'XOF',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(actor_type, actor_id)
);

ALTER TABLE app.actor_balances ENABLE ROW LEVEL SECURITY;
CREATE POLICY ab_admin_all ON app.actor_balances FOR ALL TO public USING (
  (auth.jwt() ? 'role') AND (auth.jwt() ->> 'role') = 'admin'
);
CREATE POLICY ab_owner_select ON app.actor_balances FOR SELECT TO public USING (
  actor_id = auth.uid()
);

CREATE INDEX IF NOT EXISTS idx_ab_actor ON app.actor_balances(actor_type, actor_id);

-- ============================================================
-- SECTION D : SEED DATA revenue_split_rules
-- ============================================================

INSERT INTO app.revenue_split_rules (payment_reason, beneficiary_type, percentage, description, priority) VALUES
  -- Frais de dossier
  ('application_fee', 'platform', 0.85, 'Part plateforme frais de dossier', 10),
  ('application_fee', 'commercial', 0.15, 'Commission commercial frais de dossier', 10),
  -- Frais d'inscription
  ('registration_fee', 'platform', 0.15, 'Part plateforme frais inscription', 10),
  ('registration_fee', 'university', 0.70, 'Part université frais inscription', 10),
  ('registration_fee', 'commercial', 0.15, 'Commission commercial inscription', 10),
  -- Scolarité
  ('tuition_deposit', 'platform', 0.10, 'Part plateforme scolarité', 10),
  ('tuition_deposit', 'university', 0.80, 'Part université acompte scolarité', 10),
  ('tuition_deposit', 'commercial', 0.10, 'Commission commercial scolarité', 10),
  -- Accès TD
  ('td_access', 'platform', 0.30, 'Part plateforme TD', 10),
  ('td_access', 'instructor', 0.55, 'Rémunération enseignant TD', 10),
  ('td_access', 'commercial', 0.15, 'Commission commercial TD', 10),
  -- Marketplace
  ('marketplace_purchase', 'platform', 0.10, 'Commission plateforme marketplace', 10),
  ('marketplace_purchase', 'merchant', 0.90, 'Part marchand marketplace', 10),
  -- Cours en ligne
  ('online_course', 'platform', 0.30, 'Part plateforme cours en ligne', 10),
  ('online_course', 'instructor', 0.60, 'Rémunération enseignant cours', 10),
  ('online_course', 'commercial', 0.10, 'Commission commercial cours', 10),
  -- Abonnement (100% plateforme)
  ('subscription', 'platform', 1.00, 'Abonnement 100% plateforme', 10),
  -- Défaut wildcard
  ('*', 'platform', 0.85, 'Défaut part plateforme', 0),
  ('*', 'commercial', 0.15, 'Défaut commission commercial', 0)
ON CONFLICT (payment_reason, beneficiary_type) DO NOTHING;
