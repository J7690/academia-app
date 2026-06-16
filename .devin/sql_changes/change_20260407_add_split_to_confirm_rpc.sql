-- ============================================================================
-- 7 Avril 2026 — Ajouter le split automatique vers actor_balances
-- dans app_confirm_ligdicash_payment
-- Après confirmation, la RPC lit revenue_split_rules et crédite
-- actor_balances pour chaque bénéficiaire (instructor, university, merchant, commercial)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_confirm_ligdicash_payment(
  p_payment_id UUID,
  p_ligdicash_token TEXT DEFAULT NULL,
  p_ligdicash_transaction_id TEXT DEFAULT NULL,
  p_ligdicash_operator TEXT DEFAULT NULL,
  p_payment_type TEXT DEFAULT 'application'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_payment app.application_payments%ROWTYPE;
  v_mp_payment app.marketplace_payments%ROWTYPE;
  v_receipt_id UUID;
  v_receipt_number TEXT;
  v_snapshot JSONB;
  -- Commission variables
  v_commercial_user_id UUID;
  v_degree_level TEXT;
  v_resolved RECORD;
  v_cap RECORD;
  v_final_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_commission_id UUID;
  -- Split variables
  v_split_rules JSONB;
  v_split_rule JSONB;
  v_split_amount NUMERIC;
  v_total_amount NUMERIC;
  v_payment_reason TEXT;
  v_beneficiary_type TEXT;
  v_beneficiary_pct NUMERIC;
  v_actor_id UUID;
  v_i INTEGER;
BEGIN
  -- =====================
  -- CAS 1 : application payment
  -- =====================
  IF p_payment_type = 'application' OR p_payment_type = 'subscription' OR p_payment_type = 'td' THEN

    SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;
    IF v_payment IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
    END IF;

    -- Idempotent : si déjà confirmé, ne rien faire
    IF v_payment.status = 'confirmed' THEN
      RETURN JSONB_BUILD_OBJECT('success', TRUE, 'already_confirmed', TRUE);
    END IF;

    IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification', 'processing') THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    -- Mettre à jour le paiement
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

    -- Générer reçu
    v_receipt_number := 'REC-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                        SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

    v_snapshot := JSONB_BUILD_OBJECT(
      'amount_paid', v_payment.amount_paid,
      'amount_due', v_payment.amount_due,
      'currency', v_payment.currency,
      'payment_reason', v_payment.payment_reason,
      'channel', 'ligdicash',
      'reference_code', v_payment.reference_code,
      'ligdicash_operator', p_ligdicash_operator,
      'ligdicash_transaction_id', p_ligdicash_transaction_id,
      'confirmed_at', NOW()
    );

    INSERT INTO app.payment_receipts (payment_id, receipt_number, issued_by, snapshot)
    VALUES (p_payment_id, v_receipt_number, COALESCE(auth.uid(), v_payment.student_id), v_snapshot)
    RETURNING id INTO v_receipt_id;

    -- Écriture au grand livre (crédit plateforme)
    INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('payin', COALESCE(v_payment.amount_paid, v_payment.amount_due), v_payment.currency, 'credit', 'student', v_payment.student_id, p_payment_id,
            'Paiement ' || v_payment.payment_reason::TEXT || ' via LigdiCash');

    -- Commission commerciale (même logique que app_admin_confirm_payment)
    SELECT ur.commercial_user_id INTO v_commercial_user_id
    FROM app.user_referrals ur
    WHERE ur.student_id = v_payment.student_id
    LIMIT 1;

    IF v_commercial_user_id IS NOT NULL THEN
      -- Vérifier que le commercial est actif
      IF EXISTS (SELECT 1 FROM app.commercial_profiles WHERE user_id = v_commercial_user_id AND is_active = TRUE) THEN
        -- Résoudre le taux
        v_degree_level := COALESCE(
          (SELECT p.degree_level FROM app.applications a JOIN app.programs p ON p.id = a.program_id WHERE a.id = v_payment.application_id),
          '*'
        );

        SELECT * INTO v_resolved FROM app.fn_resolve_commission_rate(v_payment.payment_reason::TEXT, v_degree_level);
        SELECT * INTO v_cap FROM app.fn_check_commission_cap(v_commercial_user_id, v_payment.student_id);

        IF v_cap.allowed THEN
          v_final_rate := LEAST(v_resolved.resolved_rate, v_cap.adjusted_rate);
          v_commission_amount := ROUND(COALESCE(v_payment.amount_paid, v_payment.amount_due) * v_final_rate, 2);

          IF v_resolved.resolved_max_amount IS NOT NULL AND v_commission_amount > v_resolved.resolved_max_amount THEN
            v_commission_amount := v_resolved.resolved_max_amount;
          END IF;

          IF v_commission_amount > 0 THEN
            INSERT INTO app.referral_commissions (commercial_user_id, student_id, payment_id, commission_rate, commission_amount, currency, status)
            VALUES (v_commercial_user_id, v_payment.student_id, p_payment_id, v_final_rate, v_commission_amount, v_payment.currency, 'pending')
            RETURNING id INTO v_commission_id;
          END IF;
        END IF;
      END IF;
    END IF;

    -- =============================================
    -- NOUVEAU : SPLIT REVENUS vers actor_balances
    -- =============================================
    v_total_amount := COALESCE(v_payment.amount_paid, v_payment.amount_due, 0);
    v_payment_reason := v_payment.payment_reason::TEXT;

    -- Récupérer les règles de split pour ce payment_reason
    v_split_rules := app_resolve_revenue_split(v_payment_reason);

    IF v_split_rules IS NOT NULL AND jsonb_array_length(v_split_rules) > 0 THEN
      FOR v_i IN 0..jsonb_array_length(v_split_rules) - 1 LOOP
        v_split_rule := v_split_rules->v_i;
        v_beneficiary_type := v_split_rule->>'beneficiary_type';
        v_beneficiary_pct := (v_split_rule->>'percentage')::NUMERIC;
        v_split_amount := ROUND(v_total_amount * v_beneficiary_pct, 2);

        -- Appliquer max_amount si défini
        IF v_split_rule->>'max_amount' IS NOT NULL AND v_split_amount > (v_split_rule->>'max_amount')::NUMERIC THEN
          v_split_amount := (v_split_rule->>'max_amount')::NUMERIC;
        END IF;

        -- Ne créditer que si montant > 0 et pas le type 'platform' (la plateforme garde le reste)
        IF v_split_amount > 0 AND v_beneficiary_type <> 'platform' THEN
          v_actor_id := NULL;

          -- Résoudre l'actor_id selon le type de bénéficiaire
          IF v_beneficiary_type = 'commercial' AND v_commercial_user_id IS NOT NULL THEN
            v_actor_id := v_commercial_user_id;

          ELSIF v_beneficiary_type = 'university' THEN
            -- L'université liée au programme de la candidature
            SELECT u.id INTO v_actor_id
            FROM app.applications a
            JOIN app.programs p ON p.id = a.program_id
            JOIN app.universities u ON u.id = p.university_id
            WHERE a.id = v_payment.application_id
            LIMIT 1;

          ELSIF v_beneficiary_type = 'instructor' THEN
            -- Pour TD : l'enseignant assigné à l'enrollment
            IF p_payment_type = 'td' THEN
              SELECT te.teacher_id INTO v_actor_id
              FROM app.td_enrollments te
              WHERE te.payment_id = p_payment_id
              LIMIT 1;
            END IF;
            -- Pour online_course : l'instructor du cours
            -- (serait résolu si on avait le course_id — pour le futur)

          ELSIF v_beneficiary_type = 'merchant' THEN
            -- Marketplace : résolu dans le CAS 2
            CONTINUE;
          END IF;

          -- Créditer actor_balances si on a trouvé un actor_id
          IF v_actor_id IS NOT NULL THEN
            INSERT INTO app.actor_balances (actor_type, actor_id, available_balance, pending_balance, total_earned, currency)
            VALUES (v_beneficiary_type, v_actor_id, v_split_amount, 0, v_split_amount, COALESCE(v_payment.currency, 'XOF'))
            ON CONFLICT (actor_type, actor_id) DO UPDATE SET
              available_balance = app.actor_balances.available_balance + v_split_amount,
              total_earned = app.actor_balances.total_earned + v_split_amount,
              updated_at = NOW();

            -- Écriture au ledger pour traçabilité
            INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
            VALUES ('revenue_split', v_split_amount, COALESCE(v_payment.currency, 'XOF'), 'debit', v_beneficiary_type, v_actor_id, p_payment_id,
                    'Split ' || v_beneficiary_type || ' (' || (v_beneficiary_pct * 100)::TEXT || '%) pour ' || v_payment_reason);
          END IF;
        END IF;
      END LOOP;
    END IF;

    -- Si c'est un abonnement, activer la subscription
    IF p_payment_type = 'subscription' THEN
      UPDATE app.subscriptions SET
        status = 'active',
        started_at = NOW(),
        payment_id = p_payment_id,
        updated_at = NOW()
      WHERE payment_id = p_payment_id OR (student_id = v_payment.student_id AND status = 'pending_payment');
    END IF;

    -- Si c'est un TD, activer l'enrollment
    IF p_payment_type = 'td' THEN
      UPDATE app.td_enrollments SET
        access_status = 'waiting_admin',
        updated_at = NOW()
      WHERE payment_id = p_payment_id AND access_status = 'pending_payment';
    END IF;

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'receipt_number', v_receipt_number,
      'receipt_id', v_receipt_id,
      'commission_created', v_commission_id IS NOT NULL,
      'commission_amount', COALESCE(v_commission_amount, 0)
    );

  -- =====================
  -- CAS 2 : marketplace payment
  -- =====================
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
      status = 'captured',
      payment_provider = 'ligdicash',
      payment_provider_ref = p_ligdicash_transaction_id,
      ligdicash_token = p_ligdicash_token,
      ligdicash_transaction_id = p_ligdicash_transaction_id,
      updated_at = NOW()
    WHERE id = p_payment_id;

    -- Mettre la commande en "paid"
    UPDATE app.marketplace_orders SET status = 'paid', updated_at = NOW()
    WHERE id = v_mp_payment.order_id;

    -- Écriture au grand livre
    INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('escrow_hold', v_mp_payment.gross_amount, v_mp_payment.currency, 'credit', 'student', v_mp_payment.buyer_id, p_payment_id,
            'Paiement marketplace commande #' || v_mp_payment.order_id::TEXT);

    -- =============================================
    -- NOUVEAU : SPLIT MARKETPLACE vers actor_balances
    -- Créditer le marchand (merchant)
    -- =============================================
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
            -- Résoudre le marchand depuis la commande
            SELECT mo.merchant_id INTO v_actor_id
            FROM app.marketplace_orders mo
            WHERE mo.id = v_mp_payment.order_id
            LIMIT 1;
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
      'success', TRUE,
      'status', 'captured',
      'gross_amount', v_mp_payment.gross_amount,
      'commission_amount', v_mp_payment.commission_amount,
      'net_amount', v_mp_payment.net_amount
    );

  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_payment_type');
  END IF;
END;
$function$;
