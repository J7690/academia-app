-- ========================================
-- ACADEMIA - PAYMENTS PHASE 2 (PROFILE SUPPORT)
-- Rendre application_id / university_id optionnels pour supporter
-- les paiements liés au profil (sans candidature).
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND table_name = 'application_payments'
      AND column_name = 'application_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE app.application_payments
      ALTER COLUMN application_id DROP NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND table_name = 'application_payments'
      AND column_name = 'university_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE app.application_payments
      ALTER COLUMN university_id DROP NOT NULL;
  END IF;
END$$;
