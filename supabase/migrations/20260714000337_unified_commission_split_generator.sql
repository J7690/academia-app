-- ============================================================
-- Générateur unifié de commissions multi-bénéficiaires
-- Philosophie conservée : taux via commission_rules + cap dégressif.
-- Partage owner / promoteur / créateur / plateforme piloté par
-- commission_share_config (défini par l'admin). Idempotent.
-- Appliqué en prod le 2026-07-14 (version 20260714000337).
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_generate_commission_split_for_payment(
    p_payment_id uuid,
    p_share_tracking_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
  v_payment    app.application_payments%ROWTYPE;
  v_ref        app.user_referrals%ROWTYPE;
  v_share      app.share_tracking%ROWTYPE;
  v_cfg        app.commission_share_config%ROWTYPE;
  v_owner_id   uuid;
  v_promoter_id uuid;
  v_creator_id uuid;
  v_degree     text;
  v_resolved   record;
  v_cap        record;
  v_final_rate numeric;
  v_total      numeric(12,2);
  v_window     int;
  v_now        timestamptz := now();
  v_owner_amt   numeric(12,2) := 0;
  v_promoter_amt numeric(12,2) := 0;
  v_creator_amt numeric(12,2) := 0;
  v_platform_amt numeric(12,2) := 0;
  v_owner_pct numeric := 0;
  v_promoter_pct numeric := 0;
  v_creator_pct numeric := 0;
  v_scenario text;
  v_created int := 0;
BEGIN
  IF p_payment_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_id');
  END IF;

  SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
  END IF;
  IF v_payment.status <> 'confirmed' THEN
    RETURN jsonb_build_object('success', true, 'generated', false, 'reason', 'payment_not_confirmed');
  END IF;
  IF v_payment.amount_paid IS NULL OR v_payment.amount_paid <= 0 THEN
    RETURN jsonb_build_object('success', true, 'generated', false, 'reason', 'no_amount_paid');
  END IF;
  IF v_payment.student_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'generated', false, 'reason', 'no_student');
  END IF;

  SELECT * INTO v_cfg FROM app.commission_share_config
  WHERE is_active = true
    AND (effective_from IS NULL OR effective_from <= v_now)
    AND (effective_until IS NULL OR effective_until > v_now)
  ORDER BY effective_from DESC NULLS LAST LIMIT 1;

  v_scenario := COALESCE(v_cfg.scenario_name, 'default');
  v_window := COALESCE(v_cfg.promoter_window_days, 30);

  SELECT * INTO v_ref FROM app.user_referrals WHERE student_id = v_payment.student_id LIMIT 1;
  IF FOUND THEN
    v_owner_id := v_ref.commercial_user_id;
  ELSE
    v_owner_id := (SELECT commercial_owner_id FROM app.students WHERE id = v_payment.student_id);
  END IF;

  IF p_share_tracking_id IS NOT NULL THEN
    SELECT * INTO v_share FROM app.share_tracking
    WHERE id = p_share_tracking_id AND student_id = v_payment.student_id;
  ELSE
    SELECT * INTO v_share FROM app.share_tracking
    WHERE student_id = v_payment.student_id
      AND payment_id IS NULL
      AND clicked_at >= v_now - (v_window || ' days')::interval
    ORDER BY clicked_at DESC LIMIT 1;
  END IF;
  IF FOUND THEN
    v_promoter_id := v_share.promoter_commercial_id;
    v_creator_id  := v_share.creator_commercial_id;
  END IF;

  IF v_owner_id IS NOT NULL AND v_ref.attributed_at IS NOT NULL THEN
    IF COALESCE(v_payment.confirmed_at, v_now) > v_ref.attributed_at + interval '1 year' THEN
      v_owner_id := NULL;
    END IF;
  END IF;

  IF v_owner_id IS NULL AND v_promoter_id IS NULL AND v_creator_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'generated', false, 'reason', 'no_commercial_beneficiary_platform_direct');
  END IF;

  v_degree := COALESCE(
     (SELECT p.degree_level FROM app.applications a JOIN app.programs p ON p.id=a.program_id WHERE a.id=v_payment.application_id),
     '*');
  SELECT * INTO v_resolved FROM app.fn_resolve_commission_rate(v_payment.payment_reason::text, v_degree);

  IF v_resolved.resolved_rate IS NULL OR v_resolved.resolved_rate <= 0 THEN
    RETURN jsonb_build_object('success', true, 'generated', false, 'reason', 'zero_rate');
  END IF;

  IF v_owner_id IS NOT NULL THEN
    SELECT * INTO v_cap FROM app.fn_check_commission_cap(v_owner_id, v_payment.student_id);
    IF v_cap.allowed IS FALSE THEN
      v_owner_id := NULL;
      v_final_rate := v_resolved.resolved_rate;
    ELSE
      v_final_rate := LEAST(v_resolved.resolved_rate, v_cap.adjusted_rate);
    END IF;
  ELSE
    v_final_rate := v_resolved.resolved_rate;
  END IF;

  v_total := ROUND(v_payment.amount_paid * v_final_rate, 2);
  IF v_resolved.resolved_max_amount IS NOT NULL AND v_resolved.resolved_max_amount > 0
     AND v_total > v_resolved.resolved_max_amount THEN
    v_total := v_resolved.resolved_max_amount;
  END IF;
  IF v_total <= 0 THEN
    RETURN jsonb_build_object('success', true, 'generated', false, 'reason', 'zero_total');
  END IF;

  v_owner_pct    := COALESCE(v_cfg.owner_percentage, 100);
  v_promoter_pct := COALESCE(v_cfg.promoter_percentage, 0);
  v_creator_pct  := COALESCE(v_cfg.creator_percentage, 0);

  IF v_owner_id IS NOT NULL THEN
    v_owner_amt := ROUND(v_total * v_owner_pct/100.0, 2);
  END IF;

  IF v_promoter_id IS NOT NULL AND v_promoter_id = v_owner_id THEN
    v_owner_amt := v_owner_amt + ROUND(v_total * v_promoter_pct/100.0, 2);
    v_promoter_id := NULL;
  ELSIF v_promoter_id IS NOT NULL THEN
    v_promoter_amt := ROUND(v_total * v_promoter_pct/100.0, 2);
  END IF;

  IF v_creator_id IS NOT NULL THEN
    v_creator_amt := ROUND(v_total * v_creator_pct/100.0, 2);
  END IF;

  v_platform_amt := v_total - v_owner_amt - v_promoter_amt - v_creator_amt;
  IF v_platform_amt < 0 THEN v_platform_amt := 0; END IF;

  IF v_owner_id IS NOT NULL AND v_owner_amt > 0 THEN
    INSERT INTO app.referral_commissions (
      commercial_user_id, student_id, payment_id, commission_rate, commission_amount, currency, status, created_at,
      beneficiary_role, owner_commercial_id, promoter_commercial_id, creator_commercial_id,
      owner_commission_amount, promoter_commission_amount, creator_commission_amount, platform_commission_amount,
      share_scenario, share_tracking_id
    ) VALUES (
      v_owner_id, v_payment.student_id, v_payment.id, v_final_rate, v_owner_amt, v_payment.currency, 'pending', v_now,
      'owner', v_owner_id, v_share.promoter_commercial_id, v_creator_id,
      v_owner_amt, v_promoter_amt, v_creator_amt, v_platform_amt,
      v_scenario, v_share.id
    )
    ON CONFLICT (payment_id, commercial_user_id, beneficiary_role) DO NOTHING;
    IF FOUND THEN v_created := v_created + 1; END IF;
  END IF;

  IF v_promoter_id IS NOT NULL AND v_promoter_amt > 0 THEN
    INSERT INTO app.referral_commissions (
      commercial_user_id, student_id, payment_id, commission_rate, commission_amount, currency, status, created_at,
      beneficiary_role, owner_commercial_id, promoter_commercial_id, creator_commercial_id,
      owner_commission_amount, promoter_commission_amount, creator_commission_amount, platform_commission_amount,
      share_scenario, share_tracking_id
    ) VALUES (
      v_promoter_id, v_payment.student_id, v_payment.id, v_final_rate, v_promoter_amt, v_payment.currency, 'pending', v_now,
      'promoter', v_owner_id, v_promoter_id, v_creator_id,
      v_owner_amt, v_promoter_amt, v_creator_amt, v_platform_amt,
      v_scenario, v_share.id
    )
    ON CONFLICT (payment_id, commercial_user_id, beneficiary_role) DO NOTHING;
    IF FOUND THEN v_created := v_created + 1; END IF;
  END IF;

  IF v_creator_id IS NOT NULL AND v_creator_amt > 0 THEN
    INSERT INTO app.referral_commissions (
      commercial_user_id, student_id, payment_id, commission_rate, commission_amount, currency, status, created_at,
      beneficiary_role, owner_commercial_id, promoter_commercial_id, creator_commercial_id,
      owner_commission_amount, promoter_commission_amount, creator_commission_amount, platform_commission_amount,
      share_scenario, share_tracking_id
    ) VALUES (
      v_creator_id, v_payment.student_id, v_payment.id, v_final_rate, v_creator_amt, v_payment.currency, 'pending', v_now,
      'creator', v_owner_id, v_share.promoter_commercial_id, v_creator_id,
      v_owner_amt, v_promoter_amt, v_creator_amt, v_platform_amt,
      v_scenario, v_share.id
    )
    ON CONFLICT (payment_id, commercial_user_id, beneficiary_role) DO NOTHING;
    IF FOUND THEN v_created := v_created + 1; END IF;
  END IF;

  IF v_share.id IS NOT NULL THEN
    UPDATE app.share_tracking
    SET converted_at = v_now, payment_id = v_payment.id, commission_generated = true
    WHERE id = v_share.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'generated', v_created > 0, 'rows_created', v_created,
    'total_commission', v_total, 'scenario', v_scenario,
    'owner_amount', v_owner_amt, 'promoter_amount', v_promoter_amt,
    'creator_amount', v_creator_amt, 'platform_amount', v_platform_amt
  );
END;
$function$;
