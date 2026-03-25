-- ============================================================================
-- PHASE 1 — Fondations LigdiCash : enums, colonnes, tables, RPCs, RLS, index
-- 19 Mars 2026
-- Schema : app (cohérent avec toutes les tables financières existantes)
-- ============================================================================

-- ============================================================
-- SECTION A : MODIFIER LES ENUMS EXISTANTS
-- ============================================================

-- A1. payment_channel : ajouter 'ligdicash'
ALTER TYPE payment_channel ADD VALUE IF NOT EXISTS 'ligdicash';

-- A2. payment_status : ajouter 'processing' (entre OTP envoyé et confirmation)
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'processing';

-- A3. payment_reason : ajouter nouvelles raisons
ALTER TYPE payment_reason ADD VALUE IF NOT EXISTS 'subscription';
ALTER TYPE payment_reason ADD VALUE IF NOT EXISTS 'marketplace_purchase';
ALTER TYPE payment_reason ADD VALUE IF NOT EXISTS 'online_course';

-- ============================================================
-- SECTION B : AJOUTER COLONNES SUR TABLES EXISTANTES
-- ============================================================

-- B1. application_payments : colonnes LigdiCash
ALTER TABLE app.application_payments
  ADD COLUMN IF NOT EXISTS ligdicash_token TEXT,
  ADD COLUMN IF NOT EXISTS ligdicash_transaction_id TEXT,
  ADD COLUMN IF NOT EXISTS ligdicash_operator TEXT,
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- B2. marketplace_payments : colonnes LigdiCash
ALTER TABLE app.marketplace_payments
  ADD COLUMN IF NOT EXISTS ligdicash_token TEXT,
  ADD COLUMN IF NOT EXISTS ligdicash_transaction_id TEXT,
  ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- B3. commercial_profiles : numéro payout
ALTER TABLE app.commercial_profiles
  ADD COLUMN IF NOT EXISTS payout_phone TEXT;

-- ============================================================
-- SECTION C : NOUVELLES TABLES
-- ============================================================

-- C1. subscription_plans
CREATE TABLE IF NOT EXISTS app.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  duration_days INTEGER NOT NULL,
  features JSONB DEFAULT '[]'::JSONB,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  promo_percent INTEGER NOT NULL DEFAULT 0,
  promo_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- C2. subscriptions
CREATE TABLE IF NOT EXISTS app.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES app.students(id),
  plan_id UUID NOT NULL REFERENCES app.subscription_plans(id),
  status TEXT NOT NULL DEFAULT 'pending_payment',
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  payment_id UUID REFERENCES app.application_payments(id),
  auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- C3. payout_queue
CREATE TABLE IF NOT EXISTS app.payout_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_type TEXT NOT NULL,
  beneficiary_user_id UUID,
  beneficiary_phone TEXT,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  reason TEXT,
  source_payment_id UUID REFERENCES app.application_payments(id),
  source_marketplace_payment_id UUID,
  status TEXT NOT NULL DEFAULT 'pending',
  ligdicash_token TEXT,
  ligdicash_transaction_id TEXT,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- C4. platform_ledger
CREATE TABLE IF NOT EXISTS app.platform_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_type TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  direction TEXT NOT NULL,
  counterpart_type TEXT,
  counterpart_id UUID,
  reference_id UUID,
  description TEXT,
  balance_after NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION D : INDEX
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_subscriptions_student_status ON app.subscriptions(student_id, status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires ON app.subscriptions(expires_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_payout_queue_status ON app.payout_queue(status);
CREATE INDEX IF NOT EXISTS idx_payout_queue_beneficiary ON app.payout_queue(beneficiary_user_id);
CREATE INDEX IF NOT EXISTS idx_platform_ledger_created ON app.platform_ledger(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_ledger_type ON app.platform_ledger(transaction_type);
CREATE INDEX IF NOT EXISTS idx_application_payments_method ON app.application_payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_application_payments_ligdicash_token ON app.application_payments(ligdicash_token) WHERE ligdicash_token IS NOT NULL;

-- ============================================================
-- SECTION E : RLS (Row Level Security)
-- ============================================================

-- E1. subscription_plans — lecture publique (plans visibles par tous les authentifiés)
ALTER TABLE app.subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY sub_plans_select_all ON app.subscription_plans FOR SELECT TO public USING (true);
CREATE POLICY sub_plans_admin_all ON app.subscription_plans FOR ALL TO public USING (
  (auth.jwt() ? 'role') AND (auth.jwt() ->> 'role') = 'admin'
);

-- E2. subscriptions — étudiant voit les siennes, admin voit toutes
ALTER TABLE app.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY subscriptions_student_select ON app.subscriptions FOR SELECT TO public USING (
  student_id = auth.uid()
);
CREATE POLICY subscriptions_admin_all ON app.subscriptions FOR ALL TO public USING (
  (auth.jwt() ? 'role') AND (auth.jwt() ->> 'role') = 'admin'
);

-- E3. payout_queue — admin voit toutes, commercial/merchant voient les leurs
ALTER TABLE app.payout_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY payout_queue_admin_all ON app.payout_queue FOR ALL TO public USING (
  (auth.jwt() ? 'role') AND (auth.jwt() ->> 'role') = 'admin'
);
CREATE POLICY payout_queue_beneficiary_select ON app.payout_queue FOR SELECT TO public USING (
  beneficiary_user_id = auth.uid()
);

-- E4. platform_ledger — admin SELECT only
ALTER TABLE app.platform_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_ledger_admin_select ON app.platform_ledger FOR SELECT TO public USING (
  (auth.jwt() ? 'role') AND (auth.jwt() ->> 'role') = 'admin'
);

-- ============================================================
-- SECTION F : SEED DATA — Plans d'abonnement
-- ============================================================

INSERT INTO app.subscription_plans (code, name, description, price, currency, duration_days, features, is_active, promo_percent)
VALUES
  ('premium_monthly', 'Premium Mensuel', 'Accès complet à toutes les fonctionnalités premium pendant 1 mois.', 5000, 'XOF', 30, '["prep_concours","ia_tuteur_illimite","jeux_complets","lives_prioritaires"]'::JSONB, TRUE, 0),
  ('premium_annual', 'Premium Annuel', 'Accès complet à toutes les fonctionnalités premium pendant 1 an. Économisez 25%.', 45000, 'XOF', 365, '["prep_concours","ia_tuteur_illimite","jeux_complets","lives_prioritaires"]'::JSONB, TRUE, 0),
  ('td_pass_monthly', 'TD Pass Mensuel', 'Accès illimité aux sessions de Travaux Dirigés pendant 1 mois.', 3000, 'XOF', 30, '["td_illimite"]'::JSONB, TRUE, 0)
ON CONFLICT (code) DO NOTHING;
