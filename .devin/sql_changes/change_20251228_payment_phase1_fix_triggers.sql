-- ========================================
-- ACADEMIA - PAYMENTS PHASE 1 (FIX TRIGGERS)
-- Corrige les triggers d'immutabilité sur app.payment_receipts
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- Fonction trigger unique pour bloquer UPDATE/DELETE sur les reçus
CREATE OR REPLACE FUNCTION app.payment_receipts_block_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'payment_receipts are immutable';
  RETURN OLD;
END;
$$;

-- Recréer les triggers de manière idempotente
DROP TRIGGER IF EXISTS payment_receipts_no_update ON app.payment_receipts;
CREATE TRIGGER payment_receipts_no_update
BEFORE UPDATE ON app.payment_receipts
FOR EACH ROW
EXECUTE FUNCTION app.payment_receipts_block_changes();

DROP TRIGGER IF EXISTS payment_receipts_no_delete ON app.payment_receipts;
CREATE TRIGGER payment_receipts_no_delete
BEFORE DELETE ON app.payment_receipts
FOR EACH ROW
EXECUTE FUNCTION app.payment_receipts_block_changes();
