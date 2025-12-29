-- ========================================
-- ACADEMIA - PAYMENTS PHASE 1 (RLS FIX)
-- Utiliser les claims JWT au lieu de auth.users dans les policies
-- pour éviter "permission denied for table users" côté client.
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- S'assurer que la RLS est activée
ALTER TABLE app.application_payments ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 1) Université : lecture des paiements de ses candidatures
--    via les claims JWT (role + university_id)
-- ========================================

DROP POLICY IF EXISTS university_select_own_payments ON app.application_payments;
CREATE POLICY university_select_own_payments
ON app.application_payments FOR SELECT
USING (
  (current_setting('request.jwt.claims', true)::jsonb->>'role') = 'university'
  AND (current_setting('request.jwt.claims', true)::jsonb->>'university_id')::uuid = application_payments.university_id
);

-- ========================================
-- 2) Admin : lecture globale via le claim JWT role=admin
-- ========================================

DROP POLICY IF EXISTS admin_select_all_payments ON app.application_payments;
CREATE POLICY admin_select_all_payments
ON app.application_payments FOR SELECT
USING (
  (current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin'
);
