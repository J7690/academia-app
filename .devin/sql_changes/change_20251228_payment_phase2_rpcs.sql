-- ========================================
-- ACADEMIA - PAYMENTS PHASE 2 (CORE RPCs)
-- RPC métier : création, déclaration étudiant, vérification admin, confirmation + reçu
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) RPC - Création d'une intention de paiement
-- ========================================

CREATE OR REPLACE FUNCTION app_create_application_payment(
  p_application_id UUID,
  p_payment_reason payment_reason,
  p_amount_due NUMERIC(12,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_app RECORD;
  v_program RECORD;
  v_university_id UUID;
  v_student_id UUID;
  v_payment_id UUID;
  v_reference_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_application_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_application_id');
  END IF;

  IF p_payment_reason IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_reason');
  END IF;

  IF p_amount_due IS NULL OR p_amount_due <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_due');
  END IF;

  SELECT a.*, p.university_id
  INTO v_app
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  WHERE a.id = p_application_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
  END IF;

  v_student_id := v_app.student_id;
  v_university_id := v_app.university_id;

  IF v_student_id IS NULL OR v_university_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_links_invalid');
  END IF;

  -- Générer une référence lisible : AP-YYYYMM-XXXX
  v_reference_code := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id,
    student_id,
    university_id,
    amount_due,
    currency,
    payment_reason,
    status,
    reference_code,
    created_by
  ) VALUES (
    p_application_id,
    v_student_id,
    v_university_id,
    p_amount_due,
    'XOF',
    p_payment_reason,
    'pending',
    v_reference_code,
    v_user_id
  )
  RETURNING id INTO v_payment_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount_due', p_amount_due,
    'currency', 'XOF',
    'payment_reason', p_payment_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_create_application_payment(UUID, payment_reason, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION app_create_application_payment(UUID, payment_reason, NUMERIC) TO service_role;

-- ========================================
-- 2) RPC - Déclaration de paiement par l'étudiant
-- ========================================

CREATE OR REPLACE FUNCTION app_student_declare_payment(
  p_payment_id UUID,
  p_channel payment_channel,
  p_amount_paid NUMERIC(12,2),
  p_external_reference TEXT,
  p_student_note TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_payment app.application_payments%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_id');
  END IF;

  IF p_channel IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_channel');
  END IF;

  IF p_amount_paid IS NULL OR p_amount_paid <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_paid');
  END IF;

  SELECT *
  INTO v_payment
  FROM app.application_payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  IF v_payment.student_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status_for_declaration');
  END IF;

  UPDATE app.application_payments
  SET
    channel = p_channel,
    amount_paid = p_amount_paid,
    external_reference = p_external_reference,
    student_note = p_student_note,
    status = 'declared_by_student',
    updated_at = NOW(),
    declared_at = COALESCE(declared_at, NOW())
  WHERE id = p_payment_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_declare_payment(UUID, payment_channel, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_declare_payment(UUID, payment_channel, NUMERIC, TEXT, TEXT) TO service_role;

-- ========================================
-- 3) RPC - Vérification admin (valid / invalid)
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_verify_payment(
  p_payment_id UUID,
  p_decision TEXT,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_payment app.application_payments%ROWTYPE;
  v_new_status payment_status;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_id');
  END IF;

  SELECT *
  INTO v_payment
  FROM app.application_payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status_for_verification');
  END IF;

  IF p_decision IS NULL OR LENGTH(TRIM(p_decision)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_decision');
  END IF;

  IF LOWER(TRIM(p_decision)) = 'valid' THEN
    v_new_status := 'under_verification';
  ELSIF LOWER(TRIM(p_decision)) = 'invalid' THEN
    v_new_status := 'rejected';
  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_decision');
  END IF;

  UPDATE app.application_payments
  SET
    status = v_new_status,
    verified_by = v_user_id,
    verified_at = NOW(),
    updated_at = NOW(),
    student_note = COALESCE(student_note, p_comment)
  WHERE id = p_payment_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', v_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_verify_payment(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_verify_payment(UUID, TEXT, TEXT) TO service_role;

-- ========================================
-- 4) RPC - Confirmation finale & génération du reçu
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_confirm_payment(
  p_payment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_payment app.application_payments%ROWTYPE;
  v_receipt_id UUID;
  v_receipt_number TEXT;
  v_snapshot JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_id');
  END IF;

  SELECT *
  INTO v_payment
  FROM app.application_payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status_for_confirmation');
  END IF;

  IF v_payment.amount_paid IS NULL OR v_payment.amount_paid <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'amount_paid_missing');
  END IF;

  -- Pour les paiements mobile money, exiger une reference operateur (ID Trans / ref. SMS)
  IF v_payment.channel IN ('orange_money', 'moov_money', 'telecel_money')
     AND (v_payment.external_reference IS NULL OR LENGTH(TRIM(v_payment.external_reference)) = 0)
  THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'external_reference_required_for_mobile_money');
  END IF;

  -- Générer un numéro de reçu lisible
  v_receipt_number := 'REC-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  v_snapshot := JSONB_BUILD_OBJECT(
    'payment_id', v_payment.id,
    'application_id', v_payment.application_id,
    'student_id', v_payment.student_id,
    'university_id', v_payment.university_id,
    'amount_due', v_payment.amount_due,
    'amount_paid', v_payment.amount_paid,
    'currency', v_payment.currency,
    'payment_reason', v_payment.payment_reason,
    'channel', v_payment.channel,
    'reference_code', v_payment.reference_code,
    'external_reference', v_payment.external_reference,
    'created_at', v_payment.created_at,
    'confirmed_at', NOW()
  );

  INSERT INTO app.payment_receipts (
    payment_id,
    receipt_number,
    issued_by,
    issued_at,
    snapshot
  ) VALUES (
    v_payment.id,
    v_receipt_number,
    v_user_id,
    NOW(),
    v_snapshot
  )
  RETURNING id INTO v_receipt_id;

  UPDATE app.application_payments
  SET
    status = 'confirmed',
    confirmed_by = v_user_id,
    confirmed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_payment_id;

  -- TODO (Phase ultérieure) : mettre à jour le statut de la candidature (enrolled/paid)

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'receipt_id', v_receipt_id,
    'receipt_number', v_receipt_number
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_confirm_payment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_confirm_payment(UUID) TO service_role;

-- ========================================
-- 5) RPC - Liste des paiements avec contexte (admin)
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_payments_with_context()
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  RETURN QUERY
  SELECT JSONB_BUILD_OBJECT(
    'id', p.id,
    'application_id', p.application_id,
    'student_id', p.student_id,
    'university_id', p.university_id,
    'amount_due', p.amount_due,
    'amount_paid', p.amount_paid,
    'currency', p.currency,
    'payment_reason', p.payment_reason,
    'status', p.status,
    'channel', p.channel,
    'reference_code', p.reference_code,
    'external_reference', p.external_reference,
    'created_at', p.created_at,
    'updated_at', p.updated_at,
    'verified_at', p.verified_at,
    'confirmed_at', p.confirmed_at,
    'program_id', a.program_id,
    'program_title', prog.title,
    'university_name', u.name
  )
  FROM app.application_payments p
  LEFT JOIN app.applications a ON a.id = p.application_id
  LEFT JOIN app.programs prog ON prog.id = a.program_id
  LEFT JOIN app.universities u ON u.id = prog.university_id
  ORDER BY p.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_payments_with_context() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_payments_with_context() TO service_role;

-- ========================================
-- 6) RPC - Création d'un paiement lié au profil étudiant (hors candidature)
-- ========================================

CREATE OR REPLACE FUNCTION app_student_create_profile_payment(
  p_payment_reason payment_reason,
  p_amount_due NUMERIC(12,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_student_id UUID;
  v_payment_id UUID;
  v_reference_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_payment_reason IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_reason');
  END IF;

  IF p_amount_due IS NULL OR p_amount_due <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_due');
  END IF;

  SELECT id
  INTO v_student_id
  FROM app.students
  WHERE id = v_user_id;

  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_not_found');
  END IF;

  v_reference_code := 'PR-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id,
    student_id,
    university_id,
    amount_due,
    currency,
    payment_reason,
    status,
    reference_code,
    created_by
  ) VALUES (
    NULL,
    v_student_id,
    NULL,
    p_amount_due,
    'XOF',
    p_payment_reason,
    'pending',
    v_reference_code,
    v_user_id
  )
  RETURNING id INTO v_payment_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount_due', p_amount_due,
    'currency', 'XOF',
    'payment_reason', p_payment_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_create_profile_payment(payment_reason, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_create_profile_payment(payment_reason, NUMERIC) TO service_role;
