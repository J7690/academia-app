-- ============================================================================
-- PHASE 1 — RPCs LigdiCash
-- 19 Mars 2026
-- Toutes les RPCs dans schema public (cohérent avec les RPCs existantes)
-- Tables référencées dans schema app
-- ============================================================================

-- ============================================================
-- RPC 1 : app_student_check_subscription
-- Vérifie si l'étudiant courant a un abonnement actif couvrant un feature
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_check_subscription(p_feature TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sub RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('has_access', FALSE, 'reason', 'not_authenticated');
  END IF;

  SELECT s.id, s.status, s.expires_at, sp.code, sp.name, sp.features
  INTO v_sub
  FROM app.subscriptions s
  JOIN app.subscription_plans sp ON sp.id = s.plan_id
  WHERE s.student_id = v_user_id
    AND s.status = 'active'
    AND (s.expires_at IS NULL OR s.expires_at > NOW())
    AND sp.features ? p_feature
  ORDER BY s.expires_at DESC NULLS LAST
  LIMIT 1;

  IF v_sub IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('has_access', FALSE, 'reason', 'no_active_subscription');
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'has_access', TRUE,
    'subscription_id', v_sub.id,
    'plan_code', v_sub.code,
    'plan_name', v_sub.name,
    'expires_at', v_sub.expires_at
  );
END;
$$;

-- ============================================================
-- RPC 2 : app_admin_list_payout_queue
-- Liste les payouts avec filtres optionnels
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_list_payout_queue(
  p_status TEXT DEFAULT NULL,
  p_beneficiary_type TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
  v_total INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.payout_queue pq
  WHERE (p_status IS NULL OR pq.status = p_status)
    AND (p_beneficiary_type IS NULL OR pq.beneficiary_type = p_beneficiary_type);

  SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT pq.id, pq.beneficiary_type, pq.beneficiary_user_id, pq.beneficiary_phone,
           pq.amount, pq.currency, pq.reason, pq.source_payment_id,
           pq.source_marketplace_payment_id, pq.status, pq.ligdicash_token,
           pq.ligdicash_transaction_id, pq.processed_at, pq.error_message,
           pq.retry_count, pq.created_at
    FROM app.payout_queue pq
    WHERE (p_status IS NULL OR pq.status = p_status)
      AND (p_beneficiary_type IS NULL OR pq.beneficiary_type = p_beneficiary_type)
    ORDER BY pq.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'payouts', v_result, 'total', v_total);
END;
$$;

-- ============================================================
-- RPC 3 : app_admin_get_treasury_summary
-- Résumé financier de la plateforme
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_get_treasury_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_total_payin NUMERIC;
  v_total_payout NUMERIC;
  v_month_payin NUMERIC;
  v_month_payout NUMERIC;
  v_pending_payouts NUMERIC;
  v_pending_payout_count INTEGER;
  v_total_commissions_commercial NUMERIC;
  v_total_commissions_marketplace NUMERIC;
  v_active_subscriptions INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  -- Total des paiements confirmés (payin)
  SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_payin
  FROM app.application_payments WHERE status = 'confirmed';

  -- Total des payouts complétés
  SELECT COALESCE(SUM(amount), 0) INTO v_total_payout
  FROM app.payout_queue WHERE status = 'completed';

  -- Payin du mois courant
  SELECT COALESCE(SUM(amount_paid), 0) INTO v_month_payin
  FROM app.application_payments
  WHERE status = 'confirmed'
    AND confirmed_at >= DATE_TRUNC('month', NOW());

  -- Payout du mois courant
  SELECT COALESCE(SUM(amount), 0) INTO v_month_payout
  FROM app.payout_queue
  WHERE status = 'completed'
    AND processed_at >= DATE_TRUNC('month', NOW());

  -- Payouts en attente
  SELECT COALESCE(SUM(amount), 0), COUNT(*)
  INTO v_pending_payouts, v_pending_payout_count
  FROM app.payout_queue WHERE status = 'pending';

  -- Commissions commerciales totales
  SELECT COALESCE(SUM(commission_amount), 0) INTO v_total_commissions_commercial
  FROM app.referral_commissions;

  -- Commissions marketplace totales
  SELECT COALESCE(SUM(commission_amount), 0) INTO v_total_commissions_marketplace
  FROM app.marketplace_payments WHERE status IN ('paid', 'captured', 'released');

  -- Abonnements actifs
  SELECT COUNT(*) INTO v_active_subscriptions
  FROM app.subscriptions WHERE status = 'active' AND (expires_at IS NULL OR expires_at > NOW());

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'total_payin', v_total_payin,
    'total_payout', v_total_payout,
    'month_payin', v_month_payin,
    'month_payout', v_month_payout,
    'pending_payouts', v_pending_payouts,
    'pending_payout_count', v_pending_payout_count,
    'total_commissions_commercial', v_total_commissions_commercial,
    'total_commissions_marketplace', v_total_commissions_marketplace,
    'active_subscriptions', v_active_subscriptions,
    'currency', 'XOF'
  );
END;
$$;

-- ============================================================
-- RPC 4 : app_admin_list_ledger
-- Grand livre paginé
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_list_ledger(
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0,
  p_transaction_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
  v_total INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT COUNT(*) INTO v_total FROM app.platform_ledger
  WHERE (p_transaction_type IS NULL OR transaction_type = p_transaction_type);

  SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT * FROM app.platform_ledger
    WHERE (p_transaction_type IS NULL OR transaction_type = p_transaction_type)
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'entries', v_result, 'total', v_total);
END;
$$;

-- ============================================================
-- RPC 5 : app_commercial_request_payout
-- Le commercial demande le versement de ses commissions approuvées
-- ============================================================
CREATE OR REPLACE FUNCTION app_commercial_request_payout(p_phone TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_profile app.commercial_profiles%ROWTYPE;
  v_total_approved NUMERIC;
  v_total_already_queued NUMERIC;
  v_available NUMERIC;
  v_payout_id UUID;
  v_phone TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'commercial' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_commercial');
  END IF;

  SELECT * INTO v_profile FROM app.commercial_profiles WHERE user_id = v_user_id;
  IF v_profile IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'profile_not_found');
  END IF;

  -- Calculer commissions approuvées non encore versées
  SELECT COALESCE(SUM(commission_amount), 0) INTO v_total_approved
  FROM app.referral_commissions
  WHERE commercial_user_id = v_user_id AND status = 'approved';

  -- Soustraire ce qui est déjà en file payout (pending/processing)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_already_queued
  FROM app.payout_queue
  WHERE beneficiary_user_id = v_user_id AND beneficiary_type = 'commercial'
    AND status IN ('pending', 'processing');

  v_available := v_total_approved - v_total_already_queued;

  IF v_available <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_funds_available', 'available', 0);
  END IF;

  v_phone := COALESCE(p_phone, v_profile.payout_phone);
  IF v_phone IS NULL OR LENGTH(TRIM(v_phone)) < 8 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'phone_required');
  END IF;

  -- Mettre à jour le numéro payout si fourni
  IF p_phone IS NOT NULL THEN
    UPDATE app.commercial_profiles SET payout_phone = p_phone, updated_at = NOW()
    WHERE user_id = v_user_id;
  END IF;

  INSERT INTO app.payout_queue (
    beneficiary_type, beneficiary_user_id, beneficiary_phone,
    amount, currency, reason, status
  ) VALUES (
    'commercial', v_user_id, v_phone,
    v_available, 'XOF', 'commission', 'pending'
  ) RETURNING id INTO v_payout_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payout_id', v_payout_id,
    'amount', v_available,
    'phone', v_phone
  );
END;
$$;

-- ============================================================
-- RPC 6 : app_merchant_request_payout
-- Le marchand demande le versement de son solde disponible
-- ============================================================
CREATE OR REPLACE FUNCTION app_merchant_request_payout(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_merchant_id UUID;
  v_balance RECORD;
  v_payout_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'merchant' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_merchant');
  END IF;

  SELECT id INTO v_merchant_id FROM app.marketplace_merchants WHERE owner_user_id = v_user_id LIMIT 1;
  IF v_merchant_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'merchant_not_found');
  END IF;

  SELECT * INTO v_balance FROM app.marketplace_merchant_balances WHERE merchant_id = v_merchant_id;
  IF v_balance IS NULL OR v_balance.available_balance <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_funds_available', 'available', 0);
  END IF;

  IF p_phone IS NULL OR LENGTH(TRIM(p_phone)) < 8 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'phone_required');
  END IF;

  -- Déduire du solde disponible
  UPDATE app.marketplace_merchant_balances
  SET available_balance = available_balance - v_balance.available_balance, updated_at = NOW()
  WHERE merchant_id = v_merchant_id;

  INSERT INTO app.payout_queue (
    beneficiary_type, beneficiary_user_id, beneficiary_phone,
    amount, currency, reason, status
  ) VALUES (
    'merchant', v_user_id, p_phone,
    v_balance.available_balance, COALESCE(v_balance.currency, 'XOF'), 'merchant_revenue', 'pending'
  ) RETURNING id INTO v_payout_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payout_id', v_payout_id,
    'amount', v_balance.available_balance,
    'phone', p_phone
  );
END;
$$;

-- ============================================================
-- RPC 7 : app_admin_manage_subscription_plan
-- CRUD des plans d'abonnement
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_manage_subscription_plan(
  p_action TEXT,
  p_plan_id UUID DEFAULT NULL,
  p_code TEXT DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_price NUMERIC DEFAULT NULL,
  p_duration_days INTEGER DEFAULT NULL,
  p_features JSONB DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL,
  p_promo_percent INTEGER DEFAULT NULL,
  p_promo_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_plan_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_action = 'create' THEN
    INSERT INTO app.subscription_plans (code, name, description, price, duration_days, features, is_active, promo_percent, promo_expires_at)
    VALUES (p_code, p_name, p_description, p_price, p_duration_days, COALESCE(p_features, '[]'::JSONB), COALESCE(p_is_active, TRUE), COALESCE(p_promo_percent, 0), p_promo_expires_at)
    RETURNING id INTO v_plan_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'plan_id', v_plan_id);

  ELSIF p_action = 'update' THEN
    IF p_plan_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'plan_id_required');
    END IF;
    UPDATE app.subscription_plans SET
      name = COALESCE(p_name, name),
      description = COALESCE(p_description, description),
      price = COALESCE(p_price, price),
      duration_days = COALESCE(p_duration_days, duration_days),
      features = COALESCE(p_features, features),
      is_active = COALESCE(p_is_active, is_active),
      promo_percent = COALESCE(p_promo_percent, promo_percent),
      promo_expires_at = p_promo_expires_at,
      updated_at = NOW()
    WHERE id = p_plan_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);

  ELSIF p_action = 'delete' THEN
    IF p_plan_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'plan_id_required');
    END IF;
    UPDATE app.subscription_plans SET is_active = FALSE, updated_at = NOW() WHERE id = p_plan_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);

  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_action');
  END IF;
END;
$$;

-- ============================================================
-- RPC 8 : app_admin_list_subscriptions
-- Liste des abonnements avec filtres
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_list_subscriptions(p_status TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT s.id, s.student_id, s.status, s.started_at, s.expires_at, s.auto_renew, s.created_at,
           sp.code AS plan_code, sp.name AS plan_name, sp.price AS plan_price,
           st.full_name AS student_name
    FROM app.subscriptions s
    JOIN app.subscription_plans sp ON sp.id = s.plan_id
    LEFT JOIN app.students st ON st.id = s.student_id
    WHERE (p_status IS NULL OR s.status = p_status)
    ORDER BY s.created_at DESC
  ) t;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'subscriptions', v_result);
END;
$$;

-- ============================================================
-- RPC 9 : app_confirm_ligdicash_payment
-- Confirmation d'un paiement après succès LigdiCash
-- Appelée par les Edge Functions (pas directement par le client Flutter)
-- Gère : status confirmed, reçu, split commission, payout_queue, ledger, subscription
-- ============================================================
CREATE OR REPLACE FUNCTION app_confirm_ligdicash_payment(
  p_payment_id UUID,
  p_ligdicash_token TEXT DEFAULT NULL,
  p_ligdicash_transaction_id TEXT DEFAULT NULL,
  p_ligdicash_operator TEXT DEFAULT NULL,
  p_payment_type TEXT DEFAULT 'application'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;
