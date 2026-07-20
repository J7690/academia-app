-- ============================================================
-- Branchement du générateur unifié dans les chemins de paiement
-- + suppression du double crédit commercial (actor_balances)
-- Appliqué en prod le 2026-07-14 (version 20260714104717).
-- Réversible : réactiver les règles 'commercial' rétablit l'ancien comportement.
-- ============================================================

-- 1. Fin du double crédit
UPDATE app.revenue_split_rules
SET is_active = FALSE
WHERE beneficiary_type = 'commercial' AND is_active = TRUE;

-- 2. Confirmation admin manuelle -> délègue au générateur unifié
CREATE OR REPLACE FUNCTION public.app_admin_confirm_payment(p_payment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_payment app.application_payments%ROWTYPE;
  v_receipt_id UUID;
  v_receipt_number TEXT;
  v_snapshot JSONB;
  v_split JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role NOT IN ('admin', 'super_admin') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_id');
  END IF;

  SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status_for_confirmation');
  END IF;

  IF v_payment.amount_paid IS NULL OR v_payment.amount_paid <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'amount_paid_missing');
  END IF;

  IF v_payment.channel IN ('orange_money', 'moov_money', 'telecel_money')
     AND (v_payment.external_reference IS NULL OR LENGTH(TRIM(v_payment.external_reference)) = 0)
  THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'external_reference_required_for_mobile_money');
  END IF;

  v_receipt_number := 'REC-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  v_snapshot := JSONB_BUILD_OBJECT(
    'payment_id', v_payment.id, 'application_id', v_payment.application_id,
    'student_id', v_payment.student_id, 'university_id', v_payment.university_id,
    'amount_due', v_payment.amount_due, 'amount_paid', v_payment.amount_paid,
    'currency', v_payment.currency, 'payment_reason', v_payment.payment_reason,
    'channel', v_payment.channel, 'reference_code', v_payment.reference_code,
    'external_reference', v_payment.external_reference,
    'created_at', v_payment.created_at, 'confirmed_at', NOW()
  );

  INSERT INTO app.payment_receipts (payment_id, receipt_number, issued_by, issued_at, snapshot)
  VALUES (v_payment.id, v_receipt_number, v_user_id, NOW(), v_snapshot)
  RETURNING id INTO v_receipt_id;

  UPDATE app.application_payments
  SET status = 'confirmed', confirmed_by = v_user_id, confirmed_at = NOW(), updated_at = NOW()
  WHERE id = p_payment_id;

  v_split := app_generate_commission_split_for_payment(p_payment_id, NULL);

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'receipt_id', v_receipt_id,
    'receipt_number', v_receipt_number,
    'commission_split', v_split
  );
END;
$function$;

-- 3. Wrapper "with_share" -> même générateur unifié (compat ascendante)
CREATE OR REPLACE FUNCTION public.app_admin_confirm_payment_with_share(p_payment_id uuid, p_admin_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
BEGIN
  RETURN app_admin_confirm_payment(p_payment_id);
END;
$function$;
