-- ============================================================
-- app_confirm_ligdicash_payment : utilise le générateur unifié
-- pour les commissions commerciales (registre canonique
-- referral_commissions). Le split actor_balances reste inchangé
-- (plateforme/université/instructeur/marchand ; 'commercial' désactivé).
-- Appliqué en prod le 2026-07-14 (version 20260714104823).
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_confirm_ligdicash_payment(
  p_payment_id uuid,
  p_ligdicash_token text DEFAULT NULL,
  p_ligdicash_transaction_id text DEFAULT NULL,
  p_ligdicash_operator text DEFAULT NULL,
  p_payment_type text DEFAULT 'application'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
  v_payment app.application_payments%ROWTYPE;
  v_mp_payment app.marketplace_payments%ROWTYPE;
  v_receipt_id UUID;
  v_receipt_number TEXT;
  v_snapshot JSONB;
  v_split JSONB;
  v_split_rules JSONB;
  v_split_rule JSONB;
  v_split_amount NUMERIC;
  v_total_amount NUMERIC;
  v_payment_reason TEXT;
  v_beneficiary_type TEXT;
  v_beneficiary_pct NUMERIC;
  v_actor_id UUID;
  v_commercial_user_id UUID;
  v_i INTEGER;
BEGIN
  IF p_payment_type = 'application' OR p_payment_type = 'subscription' OR p_payment_type = 'td' OR p_payment_type = 'short_training' THEN

    SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;
    IF v_payment IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
    END IF;

    IF v_payment.status = 'confirmed' THEN
      RETURN JSONB_BUILD_OBJECT('success', TRUE, 'already_confirmed', TRUE);
    END IF;

    IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification', 'processing') THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    UPDATE app.application_payments SET
      status = 'confirmed',
      payment_method = 'ligdicash_otp',
      ligdicash_token = COALESCE(p_ligdicash_token, ligdicash_token),
      ligdicash_transaction_id = COALESCE(p_ligdicash_transaction_id, ligdicash_transaction_id),
      ligdicash_operator = COALESCE(p_ligdicash_operator, ligdicash_operator),
      confirmed_at = NOW(),
      confirmed_by = NULL,
      updated_at = NOW()
    WHERE id = p_payment_id;

    v_receipt_number := 'REC-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                        SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

    v_snapshot := JSONB_BUILD_OBJECT(
      'amount_paid', v_payment.amount_paid, 'amount_due', v_payment.amount_due,
      'currency', v_payment.currency, 'payment_reason', v_payment.payment_reason,
      'channel', 'ligdicash', 'reference_code', v_payment.reference_code,
      'ligdicash_operator', p_ligdicash_operator,
      'ligdicash_transaction_id', p_ligdicash_transaction_id, 'confirmed_at', NOW()
    );

    INSERT INTO app.payment_receipts (payment_id, receipt_number, issued_by, snapshot)
    VALUES (p_payment_id, v_receipt_number, COALESCE(auth.uid(), v_payment.student_id), v_snapshot)
    RETURNING id INTO v_receipt_id;

    INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('payin', COALESCE(v_payment.amount_paid, v_payment.amount_due), v_payment.currency, 'credit', 'student', v_payment.student_id, p_payment_id,
            'Paiement ' || v_payment.payment_reason::TEXT || ' via LigdiCash');

    -- Commissions commerciales (owner / promoteur / créateur) : générateur unifié
    v_split := app_generate_commission_split_for_payment(p_payment_id, NULL);

    SELECT ur.commercial_user_id INTO v_commercial_user_id
    FROM app.user_referrals ur WHERE ur.student_id = v_payment.student_id LIMIT 1;

    -- Split revenus vers actor_balances (le bénéficiaire 'commercial' est désactivé)
    v_total_amount := COALESCE(v_payment.amount_paid, v_payment.amount_due, 0);
    v_payment_reason := v_payment.payment_reason::TEXT;
    v_split_rules := app_resolve_revenue_split(v_payment_reason);

    IF v_split_rules IS NOT NULL AND jsonb_array_length(v_split_rules) > 0 THEN
      FOR v_i IN 0..jsonb_array_length(v_split_rules) - 1 LOOP
        v_split_rule := v_split_rules->v_i;
        v_beneficiary_type := v_split_rule->>'beneficiary_type';
        v_beneficiary_pct := (v_split_rule->>'percentage')::NUMERIC;
        v_split_amount := ROUND(v_total_amount * v_beneficiary_pct, 2);

        IF v_split_rule->>'max_amount' IS NOT NULL AND v_split_amount > (v_split_rule->>'max_amount')::NUMERIC THEN
          v_split_amount := (v_split_rule->>'max_amount')::NUMERIC;
        END IF;

        IF v_split_amount > 0 AND v_beneficiary_type <> 'platform' THEN
          v_actor_id := NULL;

          IF v_beneficiary_type = 'commercial' AND v_commercial_user_id IS NOT NULL THEN
            v_actor_id := v_commercial_user_id;
          ELSIF v_beneficiary_type = 'university' THEN
            SELECT u.id INTO v_actor_id
            FROM app.applications a
            JOIN app.programs p ON p.id = a.program_id
            JOIN app.universities u ON u.id = p.university_id
            WHERE a.id = v_payment.application_id
            LIMIT 1;
          ELSIF v_beneficiary_type = 'instructor' THEN
            IF p_payment_type = 'td' THEN
              SELECT te.teacher_id INTO v_actor_id
              FROM app.td_enrollments te
              WHERE te.payment_id = p_payment_id
              LIMIT 1;
            END IF;
          ELSIF v_beneficiary_type = 'merchant' THEN
            CONTINUE;
          END IF;

          IF v_actor_id IS NOT NULL THEN
            INSERT INTO app.actor_balances (actor_type, actor_id, available_balance, pending_balance, total_earned, currency)
            VALUES (v_beneficiary_type, v_actor_id, v_split_amount, 0, v_split_amount, COALESCE(v_payment.currency, 'XOF'))
            ON CONFLICT (actor_type, actor_id) DO UPDATE SET
              available_balance = app.actor_balances.available_balance + v_split_amount,
              total_earned = app.actor_balances.total_earned + v_split_amount,
              updated_at = NOW();

            INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
            VALUES ('revenue_split', v_split_amount, COALESCE(v_payment.currency, 'XOF'), 'debit', v_beneficiary_type, v_actor_id, p_payment_id,
                    'Split ' || v_beneficiary_type || ' (' || (v_beneficiary_pct * 100)::TEXT || '%) pour ' || v_payment_reason);
          END IF;
        END IF;
      END LOOP;
    END IF;

    IF p_payment_type = 'subscription' THEN
      UPDATE app.subscriptions SET
        status = 'active', started_at = NOW(), payment_id = p_payment_id, updated_at = NOW()
      WHERE payment_id = p_payment_id OR (student_id = v_payment.student_id AND status = 'pending_payment');
    END IF;

    IF p_payment_type = 'td' THEN
      UPDATE app.td_enrollments SET
        access_status = 'waiting_admin', updated_at = NOW()
      WHERE payment_id = p_payment_id AND access_status = 'pending_payment';
    END IF;

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'receipt_number', v_receipt_number,
      'receipt_id', v_receipt_id,
      'commission_split', v_split
    );

  ELSIF p_payment_type = 'marketplace' THEN

    SELECT * INTO v_mp_payment FROM app.marketplace_payments WHERE id = p_payment_id;
    IF v_mp_payment IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'marketplace_payment_not_found');
    END IF;

    IF v_mp_payment.status NOT IN ('pending', 'processing') THEN
      IF v_mp_payment.status IN ('paid', 'captured', 'released') THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'already_confirmed', TRUE);
      END IF;
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_marketplace_payment_status');
    END IF;

    UPDATE app.marketplace_payments SET
      status = 'captured', payment_provider = 'ligdicash',
      payment_provider_ref = p_ligdicash_transaction_id,
      ligdicash_token = p_ligdicash_token,
      ligdicash_transaction_id = p_ligdicash_transaction_id,
      updated_at = NOW()
    WHERE id = p_payment_id;

    UPDATE app.marketplace_orders SET status = 'paid', updated_at = NOW()
    WHERE id = v_mp_payment.order_id;

    INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('escrow_hold', v_mp_payment.gross_amount, v_mp_payment.currency, 'credit', 'student', v_mp_payment.buyer_id, p_payment_id,
            'Paiement marketplace commande #' || v_mp_payment.order_id::TEXT);

    v_total_amount := COALESCE(v_mp_payment.gross_amount, 0);
    v_split_rules := app_resolve_revenue_split('marketplace_purchase');

    IF v_split_rules IS NOT NULL AND jsonb_array_length(v_split_rules) > 0 THEN
      FOR v_i IN 0..jsonb_array_length(v_split_rules) - 1 LOOP
        v_split_rule := v_split_rules->v_i;
        v_beneficiary_type := v_split_rule->>'beneficiary_type';
        v_beneficiary_pct := (v_split_rule->>'percentage')::NUMERIC;
        v_split_amount := ROUND(v_total_amount * v_beneficiary_pct, 2);

        IF v_split_rule->>'max_amount' IS NOT NULL AND v_split_amount > (v_split_rule->>'max_amount')::NUMERIC THEN
          v_split_amount := (v_split_rule->>'max_amount')::NUMERIC;
        END IF;

        IF v_split_amount > 0 AND v_beneficiary_type <> 'platform' THEN
          v_actor_id := NULL;
          IF v_beneficiary_type = 'merchant' THEN
            SELECT mo.merchant_id INTO v_actor_id
            FROM app.marketplace_orders mo WHERE mo.id = v_mp_payment.order_id LIMIT 1;
          END IF;

          IF v_actor_id IS NOT NULL THEN
            INSERT INTO app.actor_balances (actor_type, actor_id, available_balance, pending_balance, total_earned, currency)
            VALUES (v_beneficiary_type, v_actor_id, v_split_amount, 0, v_split_amount, COALESCE(v_mp_payment.currency, 'XOF'))
            ON CONFLICT (actor_type, actor_id) DO UPDATE SET
              available_balance = app.actor_balances.available_balance + v_split_amount,
              total_earned = app.actor_balances.total_earned + v_split_amount,
              updated_at = NOW();

            INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
            VALUES ('revenue_split', v_split_amount, COALESCE(v_mp_payment.currency, 'XOF'), 'debit', v_beneficiary_type, v_actor_id, p_payment_id,
                    'Split merchant (' || (v_beneficiary_pct * 100)::TEXT || '%) marketplace');
          END IF;
        END IF;
      END LOOP;
    END IF;

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE, 'status', 'captured',
      'gross_amount', v_mp_payment.gross_amount,
      'commission_amount', v_mp_payment.commission_amount,
      'net_amount', v_mp_payment.net_amount
    );

  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_payment_type');
  END IF;
END;
$function$;
