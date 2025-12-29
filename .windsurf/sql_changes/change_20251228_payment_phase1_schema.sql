-- ========================================
-- ACADEMIA - PAYMENTS PHASE 1 (SCHEMA ONLY)
-- Types + tables: application_payments, payment_proofs, payment_receipts
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) ENUM / DOMAIN-LIKE TYPES
-- ========================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_channel') THEN
    CREATE TYPE payment_channel AS ENUM (
      'cash',
      'orange_money',
      'moov_money',
      'telecel_money'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
    CREATE TYPE payment_status AS ENUM (
      'pending',
      'declared_by_student',
      'under_verification',
      'confirmed',
      'rejected',
      'cancelled'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_reason') THEN
    CREATE TYPE payment_reason AS ENUM (
      'application_fee',
      'registration_fee',
      'tuition_deposit',
      'other'
    );
  END IF;
END$$;

-- ========================================
-- 2) MAIN TABLE: app.application_payments
-- ========================================

CREATE TABLE IF NOT EXISTS app.application_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES app.applications(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
  university_id UUID NOT NULL REFERENCES app.universities(id) ON DELETE CASCADE,

  amount_due NUMERIC(12,2) NOT NULL,
  amount_paid NUMERIC(12,2),
  currency TEXT NOT NULL DEFAULT 'XOF',

  payment_reason payment_reason NOT NULL,
  channel payment_channel,
  status payment_status NOT NULL DEFAULT 'pending',

  reference_code TEXT NOT NULL,
  external_reference TEXT,
  student_note TEXT,

  created_by UUID,
  verified_by UUID,
  confirmed_by UUID,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at TIMESTAMPTZ,
  confirmed_at TIMESTAMPTZ
);

-- Ensure reference_code uniqueness for easier audit
CREATE UNIQUE INDEX IF NOT EXISTS application_payments_reference_code_key
  ON app.application_payments(reference_code);

-- Ensure external_reference (réf. opérateur) uniqueness when present
CREATE UNIQUE INDEX IF NOT EXISTS application_payments_external_reference_key
  ON app.application_payments(external_reference)
  WHERE external_reference IS NOT NULL;

-- Indexes for typical access paths
CREATE INDEX IF NOT EXISTS application_payments_application_id_idx
  ON app.application_payments(application_id);

CREATE INDEX IF NOT EXISTS application_payments_student_id_idx
  ON app.application_payments(student_id);

CREATE INDEX IF NOT EXISTS application_payments_university_id_idx
  ON app.application_payments(university_id);

CREATE INDEX IF NOT EXISTS application_payments_status_idx
  ON app.application_payments(status);

-- ========================================
-- 3) TABLE: app.payment_proofs
-- ========================================

CREATE TABLE IF NOT EXISTS app.payment_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES app.application_payments(id) ON DELETE CASCADE,
  proof_type TEXT NOT NULL,
  file_path TEXT NOT NULL,

  uploaded_by UUID NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  note TEXT
);

CREATE INDEX IF NOT EXISTS payment_proofs_payment_id_idx
  ON app.payment_proofs(payment_id);

-- ========================================
-- 4) TABLE: app.payment_receipts (append-only)
-- ========================================

CREATE TABLE IF NOT EXISTS app.payment_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES app.application_payments(id) ON DELETE RESTRICT,
  receipt_number TEXT NOT NULL,

  issued_by UUID NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  snapshot JSONB NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS payment_receipts_receipt_number_key
  ON app.payment_receipts(receipt_number);

CREATE INDEX IF NOT EXISTS payment_receipts_payment_id_idx
  ON app.payment_receipts(payment_id);

-- Prevent accidental updates/deletes on receipts (soft protection, RPCs will enforce more)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'payment_receipts_no_update'
  ) THEN
    CREATE TRIGGER payment_receipts_no_update
    BEFORE UPDATE ON app.payment_receipts
    FOR EACH ROW
    EXECUTE FUNCTION pg_catalog.raise_exception('payment_receipts are immutable');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'payment_receipts_no_delete'
  ) THEN
    CREATE TRIGGER payment_receipts_no_delete
    BEFORE DELETE ON app.payment_receipts
    FOR EACH ROW
    EXECUTE FUNCTION pg_catalog.raise_exception('payment_receipts cannot be deleted');
  END IF;
END$$;

-- ========================================
-- 5) ROW LEVEL SECURITY (MINIMUM) & GRANTS
-- ========================================

ALTER TABLE app.application_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.payment_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.payment_receipts ENABLE ROW LEVEL SECURITY;

-- Étudiant : voir uniquement ses paiements
DROP POLICY IF EXISTS student_select_own_payments ON app.application_payments;
CREATE POLICY student_select_own_payments
ON app.application_payments FOR SELECT
USING (student_id = auth.uid());

-- Université : lecture des paiements de ses candidatures via université actuelle
DROP POLICY IF EXISTS university_select_own_payments ON app.application_payments;
CREATE POLICY university_select_own_payments
ON app.application_payments FOR SELECT
USING (
  CASE
    WHEN auth.jwt() ? 'role' AND auth.jwt()->>'role' = 'university' THEN
      (auth.jwt()->>'university_id')::UUID = application_payments.university_id
    ELSE FALSE
  END
);

-- Admin : lecture globale (via rôle dans raw_user_meta_data)
DROP POLICY IF EXISTS admin_select_all_payments ON app.application_payments;
CREATE POLICY admin_select_all_payments
ON app.application_payments FOR SELECT
USING (
  auth.jwt() ? 'role' AND auth.jwt()->>'role' = 'admin'
);

GRANT SELECT ON app.application_payments TO authenticated;
GRANT ALL ON app.application_payments TO service_role;

-- Preuves : lecture/écriture contrôlée plus tard via RPC, pour l'instant lecture limitée
DROP POLICY IF EXISTS student_select_own_payment_proofs ON app.payment_proofs;
CREATE POLICY student_select_own_payment_proofs
ON app.payment_proofs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.application_payments p
    WHERE p.id = payment_proofs.payment_id
      AND p.student_id = auth.uid()
  )
);

GRANT SELECT ON app.payment_proofs TO authenticated;
GRANT ALL ON app.payment_proofs TO service_role;

-- Reçus : lecture globale pour authenticated (contrôle d’affichage côté app), full pour service_role
DROP POLICY IF EXISTS authenticated_select_payment_receipts ON app.payment_receipts;
CREATE POLICY authenticated_select_payment_receipts
ON app.payment_receipts FOR SELECT
USING (TRUE);

GRANT SELECT ON app.payment_receipts TO authenticated;
GRANT ALL ON app.payment_receipts TO service_role;
