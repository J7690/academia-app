-- ============================================================================
-- 7 Avril 2026 — Système de Crédits Academia
-- Phase 1 : Tables + RPCs + Seed data
-- ============================================================================

-- ============================================================
-- TABLE 1 : student_credits — Solde crédits par étudiant
-- ============================================================
CREATE TABLE IF NOT EXISTS app.student_credits (
  student_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
  total_purchased INTEGER NOT NULL DEFAULT 0,
  total_consumed INTEGER NOT NULL DEFAULT 0,
  total_gifted INTEGER NOT NULL DEFAULT 0,
  last_weekly_bonus TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.student_credits ENABLE ROW LEVEL SECURITY;

CREATE POLICY sc_owner_select ON app.student_credits FOR SELECT TO public
  USING (student_id = auth.uid());
CREATE POLICY sc_admin_all ON app.student_credits FOR ALL TO public
  USING ((auth.jwt() ->> 'role') = 'admin');

-- ============================================================
-- TABLE 2 : credit_transactions — Historique crédits
-- ============================================================
CREATE TABLE IF NOT EXISTS app.credit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL, -- positif = achat/bonus, négatif = consommation
  balance_after INTEGER NOT NULL,
  transaction_type TEXT NOT NULL, -- 'purchase','consumption','welcome_bonus','weekly_bonus','referral_bonus','refund','subscription_bonus'
  action_code TEXT, -- 'chat_tuteur','scan_correction','generate_qcm','correct_exercise','compose_exam'
  edge_function TEXT, -- nom de l'Edge Function
  description TEXT,
  openrouter_cost_usd NUMERIC, -- coût réel OpenRouter pour traçabilité
  openrouter_model TEXT, -- modèle utilisé (free ou payant)
  tokens_input INTEGER DEFAULT 0,
  tokens_output INTEGER DEFAULT 0,
  reservation_id UUID, -- lien vers credit_reservations si applicable
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.credit_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY ct_owner_select ON app.credit_transactions FOR SELECT TO public
  USING (student_id = auth.uid());
CREATE POLICY ct_admin_all ON app.credit_transactions FOR ALL TO public
  USING ((auth.jwt() ->> 'role') = 'admin');

CREATE INDEX IF NOT EXISTS idx_ct_student ON app.credit_transactions(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ct_type ON app.credit_transactions(transaction_type);

-- ============================================================
-- TABLE 3 : credit_packs — Packs achetables
-- ============================================================
CREATE TABLE IF NOT EXISTS app.credit_packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  credits INTEGER NOT NULL,
  price_xof INTEGER NOT NULL,
  bonus_percent INTEGER NOT NULL DEFAULT 0, -- ex: 20 = +20% bonus
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 10,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.credit_packs ENABLE ROW LEVEL SECURITY;

CREATE POLICY cp_select_all ON app.credit_packs FOR SELECT TO public USING (true);
CREATE POLICY cp_admin_all ON app.credit_packs FOR ALL TO public
  USING ((auth.jwt() ->> 'role') = 'admin');

-- ============================================================
-- TABLE 4 : ai_action_prices — Prix par action IA
-- ============================================================
CREATE TABLE IF NOT EXISTS app.ai_action_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  cost_credits INTEGER NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.ai_action_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY aap_select_all ON app.ai_action_prices FOR SELECT TO public USING (true);
CREATE POLICY aap_admin_all ON app.ai_action_prices FOR ALL TO public
  USING ((auth.jwt() ->> 'role') = 'admin');

-- ============================================================
-- TABLE 5 : credit_reservations — Réservations en cours
-- ============================================================
CREATE TABLE IF NOT EXISTS app.credit_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_code TEXT NOT NULL,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'confirmed', 'refunded', 'expired')),
  edge_function TEXT,
  openrouter_cost_usd NUMERIC,
  openrouter_model TEXT,
  tokens_input INTEGER DEFAULT 0,
  tokens_output INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE app.credit_reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY cr_owner_select ON app.credit_reservations FOR SELECT TO public
  USING (student_id = auth.uid());
CREATE POLICY cr_admin_all ON app.credit_reservations FOR ALL TO public
  USING ((auth.jwt() ->> 'role') = 'admin');

CREATE INDEX IF NOT EXISTS idx_cr_student_status ON app.credit_reservations(student_id, status);

-- ============================================================
-- SEED : credit_packs
-- ============================================================
INSERT INTO app.credit_packs (code, name, credits, price_xof, bonus_percent, sort_order) VALUES
  ('mini',      'Mini',      100,  100,  0,  1),
  ('etudiant',  'Étudiant',  300,  250,  20, 2),
  ('mensuel',   'Mensuel',   1000, 750,  33, 3),
  ('intensif',  'Intensif',  3000, 2000, 50, 4)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- SEED : ai_action_prices
-- ============================================================
INSERT INTO app.ai_action_prices (action_code, label, cost_credits, description) VALUES
  ('chat_tuteur',      'Message chat tuteur IA',        3,  '1 message envoyé au tuteur IA (TD ou Concours)'),
  ('generate_qcm',     'Générer exercices QCM',         10, 'Générer une série de 10 questions QCM'),
  ('correct_exercise',  'Corriger un exercice',          8,  'Correction IA d''un exercice soumis'),
  ('scan_correction',   'Scanner + corriger (photo/PDF)', 15, 'OCR d''une photo/PDF + correction détaillée'),
  ('compose_exam',      'Composer un examen blanc',      12, 'Générer un sujet d''examen blanc complet')
ON CONFLICT (action_code) DO NOTHING;
