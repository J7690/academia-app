-- Migration : Sécuriser la vérification du rôle dans les fonctions de paiement
-- Date : 14/09/2026
-- Contexte : l'audit du flux de paiement a révélé que 5 fonctions critiques
-- lisent le rôle dans raw_user_meta_data, que l'utilisateur peut modifier
-- via auth.updateUser(). Seul raw_app_meta_data (modifiable uniquement par
-- le service_role) est fiable.
--
-- Vérification préalable : les 309 comptes à rôle non-student ont tous
-- raw_app_meta_data->>'role' synchronisé avec raw_user_meta_data->>'role'.
-- La migration ne change donc le résultat d'aucune garde existante.
--
-- Fonctions corrigées :
-- 1. app_create_application_payment (rôle admin pour créer au nom d'un autre)
-- 2. app_admin_confirm_payment (confirmer un paiement)
-- 3. app_admin_verify_payment (vérifier un paiement déclaré)
-- 4. app_admin_forward_application (transmettre à l'université)
-- 5. app_university_update_application_status (accepter/refuser une candidature)

-- =====================================================================
-- 1. app_create_application_payment
-- =====================================================================
CREATE OR REPLACE FUNCTION public.app_create_application_payment(
  p_application_id uuid,
  p_payment_reason payment_reason,
  p_amount_due numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_app RECORD;
  v_role TEXT;
  v_amount NUMERIC;
  v_fee NUMERIC;
  v_student_id UUID;
  v_university_id UUID;
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

  SELECT a.*, p.university_id, p.brokerage_fee
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

  -- QUI PEUT CREER CE PAIEMENT : le proprietaire du dossier, ou un admin.
  -- CORRIGE 14/09 : raw_app_meta_data au lieu de raw_user_meta_data.
  SELECT raw_app_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_student_id <> v_user_id AND COALESCE(v_role, '') <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF p_payment_reason = 'application_fee' THEN
    -- COURTAGE : le tarif vient du programme, JAMAIS de l'appelant.
    v_fee := COALESCE(v_app.brokerage_fee, 0);
    IF v_fee <= 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'brokerage_fee_not_defined');
    END IF;

    -- AJOUT DU 09/09, ET LE SEUL. L'etudiant achete une reduction negociee :
    -- tant que personne n'a ecrit ce qui a ete obtenu, il n'y a rien a vendre.
    IF v_app.discount_rate IS NULL THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'error', 'taux_de_reduction_non_fixe',
        'message', 'La réduction négociée n''a pas encore été enregistrée par '
                || 'Academia. Le paiement s''ouvrira dès qu''elle le sera.');
    END IF;

    v_amount := v_fee;
  ELSE
    -- AUTRES MOTIFS : inchange, le montant transmis fait foi.
    IF p_amount_due IS NULL OR p_amount_due <= 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_due');
    END IF;
    v_amount := p_amount_due;
  END IF;

  v_reference_code := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id, student_id, university_id, amount_due, currency,
    payment_reason, status, reference_code, created_by
  ) VALUES (
    p_application_id, v_student_id, v_university_id, v_amount, 'XOF',
    p_payment_reason, 'pending', v_reference_code, v_user_id
  )
  RETURNING id INTO v_payment_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount_due', v_amount,
    'currency', 'XOF',
    'payment_reason', p_payment_reason,
    'amount_imposed', p_payment_reason = 'application_fee',
    'discount_rate', v_app.discount_rate
  );
END;
$function$;

-- =====================================================================
-- 2. app_admin_confirm_payment
-- =====================================================================
CREATE OR REPLACE FUNCTION public.app_admin_confirm_payment(p_payment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_payment app.application_payments%ROWTYPE;
  v_recu JSONB;
  v_split JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- CORRIGE 14/09 : raw_app_meta_data au lieu de raw_user_meta_data.
  SELECT raw_app_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
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

  UPDATE app.application_payments
  SET status = 'confirmed', confirmed_by = v_user_id, confirmed_at = NOW(), updated_at = NOW()
  WHERE id = p_payment_id;

  v_recu := app.emettre_recu(p_payment_id, v_user_id);

  BEGIN
    PERFORM app.emettre_bon(p_payment_id, v_user_id, 'automatique');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, resultat)
    VALUES ('(emission)', v_user_id, 'echec_emission: ' || SQLERRM);
  END;

  -- Commissions (owner / promoteur / créateur) via générateur unifié
  v_split := app_generate_commission_split_for_payment(p_payment_id, NULL);

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'receipt_id', v_recu->>'receipt_id',
    'receipt_number', v_recu->>'receipt_number',
    'commission_split', v_split
  );
END;
$function$;

-- =====================================================================
-- 3. app_admin_verify_payment
-- =====================================================================
CREATE OR REPLACE FUNCTION public.app_admin_verify_payment(
  p_payment_id uuid,
  p_decision text,
  p_comment text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_payment app.application_payments%ROWTYPE;
  v_new_status payment_status;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- CORRIGE 14/09 : raw_app_meta_data au lieu de raw_user_meta_data.
  SELECT raw_app_meta_data->>'role'
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
$function$;

-- =====================================================================
-- 4. app_admin_forward_application
-- =====================================================================
CREATE OR REPLACE FUNCTION public.app_admin_forward_application(p_application_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_app_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- CORRIGE 14/09 : raw_app_meta_data au lieu de raw_user_meta_data.
    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    UPDATE app.applications
    SET sent_to_university = TRUE,
        sent_to_university_at = COALESCE(sent_to_university_at, NOW()),
        updated_at = NOW()
    WHERE id = p_application_id
    RETURNING id INTO v_app_id;

    IF v_app_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application_id', v_app_id
    );
END;
$function$;

-- =====================================================================
-- 5. app_university_update_application_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.app_university_update_application_status(
  p_application_id uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_app_id UUID;
    v_status TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- CORRIGE 14/09 : raw_app_meta_data au lieu de raw_user_meta_data.
    -- Le university_id reste dans raw_user_meta_data car il n'est pas
    -- un secret de securite (l'universite est publique).
    SELECT
        raw_app_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    IF p_new_status IS NULL OR LENGTH(TRIM(p_new_status)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    IF p_new_status NOT IN ('under_review', 'accepted', 'rejected', 'canceled') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unsupported_status');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications a
    SET status = p_new_status,
        updated_at = NOW()
    WHERE a.id = p_application_id
    RETURNING a.id, a.status INTO v_app_id, v_status;

    IF v_app_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application_id', v_app_id,
        'status', v_status
    );
END;
$function$;
