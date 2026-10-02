-- Validation express : l'admin accepte une candidature, pose le taux,
-- cree le paiement en especes, le confirme, et emet recu + bon + commissions,
-- le tout dans une seule transaction.
--
-- Cas d'usage : un etudiant vient avec l'argent en main, l'admin fait tout
-- depuis l'ecran de la candidature sans passer par LigdiCash.

CREATE OR REPLACE FUNCTION public.app_admin_validation_express(
  p_application_id UUID,
  p_discount_rate  NUMERIC DEFAULT 0,
  p_note           TEXT    DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id       UUID := auth.uid();
  v_role          TEXT;
  v_app           RECORD;
  v_fee           NUMERIC;
  v_payment_id    UUID;
  v_reference_code TEXT;
  v_recu          JSONB;
  v_bon           JSONB;
  v_split         JSONB;
BEGIN
  -- ── Auth ──────────────────────────────────────────────────────────────
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT raw_app_meta_data->>'role' INTO v_role
  FROM auth.users WHERE id = v_user_id;

  IF v_role NOT IN ('admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  -- ── Validation du taux ────────────────────────────────────────────────
  IF p_discount_rate IS NULL OR p_discount_rate < 0 OR p_discount_rate > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'taux_invalide');
  END IF;

  -- ── Charger candidature + programme ───────────────────────────────────
  SELECT a.id, a.student_id, a.status, a.discount_rate,
         a.program_id, p.brokerage_fee, p.university_id
  INTO v_app
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  WHERE a.id = p_application_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'application_not_found');
  END IF;

  -- ── Deja paye ? ──────────────────────────────────────────────────────
  IF EXISTS (
    SELECT 1 FROM app.application_payments
    WHERE application_id = p_application_id
      AND payment_reason = 'application_fee'
      AND status = 'confirmed'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_paid');
  END IF;

  v_fee := COALESCE(v_app.brokerage_fee, 0);
  IF v_fee <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'brokerage_fee_not_defined');
  END IF;

  -- ── 1. Accepter la candidature ────────────────────────────────────────
  IF v_app.status <> 'accepted' THEN
    UPDATE app.applications
    SET status = 'accepted',
        payment_deadline_at = NOW() + INTERVAL '7 days',
        updated_at = NOW()
    WHERE id = p_application_id;
  END IF;

  -- ── 2. Fixer le taux de reduction ────────────────────────────────────
  UPDATE app.applications
  SET discount_rate         = p_discount_rate,
      discount_validated_at = NOW(),
      discount_validated_by = v_user_id,
      discount_details      = COALESCE(NULLIF(TRIM(p_note), ''), discount_details),
      updated_at            = NOW()
  WHERE id = p_application_id;

  -- ── 3. Creer ou reutiliser le paiement ────────────────────────────────
  SELECT id, reference_code INTO v_payment_id, v_reference_code
  FROM app.application_payments
  WHERE application_id = p_application_id
    AND payment_reason = 'application_fee'
    AND status IN ('pending', 'declared_by_student', 'under_verification')
  ORDER BY created_at DESC LIMIT 1;

  IF v_payment_id IS NULL THEN
    v_reference_code := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                        SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);
    INSERT INTO app.application_payments (
      application_id, student_id, university_id, amount_due, currency,
      payment_reason, status, reference_code, created_by
    ) VALUES (
      p_application_id, v_app.student_id, v_app.university_id,
      v_fee, 'XOF', 'application_fee', 'pending', v_reference_code, v_user_id
    )
    RETURNING id INTO v_payment_id;
  END IF;

  -- ── 4. Marquer paye en especes + confirmer ────────────────────────────
  UPDATE app.application_payments
  SET amount_paid    = v_fee,
      channel        = 'cash',
      payment_method = 'cash',
      status         = 'confirmed',
      confirmed_by   = v_user_id,
      confirmed_at   = NOW(),
      declared_at    = NOW(),
      updated_at     = NOW()
  WHERE id = v_payment_id;

  -- ── 5. Emettre le recu ────────────────────────────────────────────────
  v_recu := app.emettre_recu(v_payment_id, v_user_id);

  -- ── 6. Emettre le bon de courtage ─────────────────────────────────────
  BEGIN
    v_bon := app.emettre_bon(v_payment_id, v_user_id, 'saisie_manuelle');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, resultat)
    VALUES ('(validation_express)', v_user_id, 'echec_emission: ' || SQLERRM);
    v_bon := jsonb_build_object('success', false, 'error', SQLERRM);
  END;

  -- ── 7. Commissions ────────────────────────────────────────────────────
  v_split := app_generate_commission_split_for_payment(v_payment_id, NULL);

  -- ── Audit ─────────────────────────────────────────────────────────────
  INSERT INTO app.admin_audit_log (
    admin_id, action_type, target_type, target_id, target_user_id, details
  ) VALUES (
    v_user_id, 'validation_express', 'application',
    p_application_id::text, v_app.student_id,
    jsonb_build_object(
      'payment_id', v_payment_id,
      'montant', v_fee,
      'canal', 'cash',
      'taux_reduction', p_discount_rate,
      'recu', v_recu,
      'bon', v_bon
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount', v_fee,
    'receipt', v_recu,
    'voucher', v_bon,
    'commission_split', v_split
  );
END;
$$;
