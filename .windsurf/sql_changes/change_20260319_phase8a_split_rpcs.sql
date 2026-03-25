-- ============================================================================
-- PHASE 8A — RPCs Split revenus + Balances acteurs
-- 19 Mars 2026
-- Tables réelles : app.revenue_split_rules, app.actor_balances,
--   app.instructors(id FK auth.users), app.td_teachers(user_id FK auth.users),
--   app.marketplace_merchants(owner_user_id), app.universities(id)
-- ============================================================================

-- ============================================================
-- RPC 1 : app_admin_list_revenue_split_rules
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_list_revenue_split_rules()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  SELECT COALESCE(JSONB_AGG(row_to_json(r)::JSONB ORDER BY r.payment_reason, r.beneficiary_type), '[]'::JSONB)
  INTO v_result
  FROM app.revenue_split_rules r;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'rules', v_result);
END; $$;

-- ============================================================
-- RPC 2 : app_admin_upsert_revenue_split_rule
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_upsert_revenue_split_rule(
  p_payment_reason TEXT,
  p_beneficiary_type TEXT,
  p_percentage NUMERIC,
  p_max_amount NUMERIC DEFAULT NULL,
  p_min_amount NUMERIC DEFAULT 0,
  p_description TEXT DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT TRUE,
  p_priority INTEGER DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  IF p_percentage < 0 OR p_percentage > 1 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'percentage_must_be_between_0_and_1');
  END IF;

  INSERT INTO app.revenue_split_rules (payment_reason, beneficiary_type, percentage, max_amount, min_amount, description, is_active, priority)
  VALUES (p_payment_reason, p_beneficiary_type, p_percentage, p_max_amount, p_min_amount, p_description, p_is_active, p_priority)
  ON CONFLICT (payment_reason, beneficiary_type) DO UPDATE SET
    percentage = EXCLUDED.percentage,
    max_amount = EXCLUDED.max_amount,
    min_amount = EXCLUDED.min_amount,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    priority = EXCLUDED.priority,
    updated_at = NOW()
  RETURNING id INTO v_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'rule_id', v_id);
END; $$;

-- ============================================================
-- RPC 3 : app_admin_delete_revenue_split_rule
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_delete_revenue_split_rule(p_rule_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  DELETE FROM app.revenue_split_rules WHERE id = p_rule_id;
  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END; $$;

-- ============================================================
-- RPC 4 : app_admin_validate_split_totals
-- Vérifie que chaque payment_reason totalise ~100%
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_validate_split_totals()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT payment_reason,
           ROUND(SUM(percentage), 4) AS total_percentage,
           CASE WHEN ABS(SUM(percentage) - 1.0) < 0.001 THEN TRUE ELSE FALSE END AS is_valid,
           COUNT(*) AS rule_count
    FROM app.revenue_split_rules
    WHERE is_active = TRUE
    GROUP BY payment_reason
    ORDER BY payment_reason
  ) t;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'validations', v_result);
END; $$;

-- ============================================================
-- RPC 5 : app_resolve_revenue_split
-- Retourne les parts pour un payment_reason donné
-- ============================================================
CREATE OR REPLACE FUNCTION app_resolve_revenue_split(p_payment_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_result JSONB; v_count INTEGER;
BEGIN
  -- Chercher les règles exactes pour ce payment_reason
  SELECT COUNT(*) INTO v_count
  FROM app.revenue_split_rules
  WHERE payment_reason = p_payment_reason AND is_active = TRUE;

  IF v_count > 0 THEN
    SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT(
      'beneficiary_type', beneficiary_type,
      'percentage', percentage,
      'max_amount', max_amount,
      'min_amount', min_amount
    )), '[]'::JSONB)
    INTO v_result
    FROM app.revenue_split_rules
    WHERE payment_reason = p_payment_reason AND is_active = TRUE;
  ELSE
    -- Fallback vers wildcard '*'
    SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT(
      'beneficiary_type', beneficiary_type,
      'percentage', percentage,
      'max_amount', max_amount,
      'min_amount', min_amount
    )), '[]'::JSONB)
    INTO v_result
    FROM app.revenue_split_rules
    WHERE payment_reason = '*' AND is_active = TRUE;
  END IF;

  RETURN v_result;
END; $$;

-- ============================================================
-- RPC 6 : app_instructor_get_my_balance
-- ============================================================
CREATE OR REPLACE FUNCTION app_instructor_get_my_balance()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_balance RECORD;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'instructor' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor'); END IF;

  SELECT * INTO v_balance FROM app.actor_balances WHERE actor_type = 'instructor' AND actor_id = v_user_id;

  IF v_balance IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'available_balance', 0, 'pending_balance', 0, 'total_earned', 0, 'total_withdrawn', 0, 'currency', 'XOF');
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'available_balance', v_balance.available_balance,
    'pending_balance', v_balance.pending_balance,
    'total_earned', v_balance.total_earned,
    'total_withdrawn', v_balance.total_withdrawn,
    'currency', v_balance.currency
  );
END; $$;

-- ============================================================
-- RPC 7 : app_instructor_request_payout
-- ============================================================
CREATE OR REPLACE FUNCTION app_instructor_request_payout(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_balance RECORD; v_payout_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'instructor' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor'); END IF;

  IF p_phone IS NULL OR LENGTH(TRIM(p_phone)) < 8 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'phone_required');
  END IF;

  SELECT * INTO v_balance FROM app.actor_balances WHERE actor_type = 'instructor' AND actor_id = v_user_id;
  IF v_balance IS NULL OR v_balance.available_balance <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_funds_available', 'available', 0);
  END IF;

  -- Mettre à jour le payout_phone de l'enseignant
  UPDATE app.instructors SET payout_phone = p_phone WHERE id = v_user_id;
  -- Aussi dans td_teachers si c'est un enseignant TD
  UPDATE app.td_teachers SET payout_phone = p_phone WHERE user_id = v_user_id;

  -- Déduire du solde
  UPDATE app.actor_balances SET
    available_balance = available_balance - v_balance.available_balance,
    total_withdrawn = total_withdrawn + v_balance.available_balance,
    updated_at = NOW()
  WHERE actor_type = 'instructor' AND actor_id = v_user_id;

  INSERT INTO app.payout_queue (beneficiary_type, beneficiary_user_id, beneficiary_phone, amount, currency, reason, status)
  VALUES ('instructor', v_user_id, p_phone, v_balance.available_balance, COALESCE(v_balance.currency, 'XOF'), 'instructor_revenue', 'pending')
  RETURNING id INTO v_payout_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'payout_id', v_payout_id, 'amount', v_balance.available_balance, 'phone', p_phone);
END; $$;

-- ============================================================
-- RPC 8 : app_university_get_balance
-- ============================================================
CREATE OR REPLACE FUNCTION app_university_get_balance()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_uni_id UUID; v_balance RECORD;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'university' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university'); END IF;

  SELECT (raw_user_meta_data->>'university_id')::UUID INTO v_uni_id FROM auth.users WHERE id = v_user_id;
  IF v_uni_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_university_id'); END IF;

  SELECT * INTO v_balance FROM app.actor_balances WHERE actor_type = 'university' AND actor_id = v_uni_id;

  IF v_balance IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'available_balance', 0, 'pending_balance', 0, 'total_earned', 0, 'total_withdrawn', 0, 'currency', 'XOF');
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'available_balance', v_balance.available_balance,
    'pending_balance', v_balance.pending_balance,
    'total_earned', v_balance.total_earned,
    'total_withdrawn', v_balance.total_withdrawn,
    'currency', v_balance.currency
  );
END; $$;

-- ============================================================
-- RPC 9 : app_university_request_payout
-- ============================================================
CREATE OR REPLACE FUNCTION app_university_request_payout(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_uni_id UUID; v_balance RECORD; v_payout_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'university' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university'); END IF;

  IF p_phone IS NULL OR LENGTH(TRIM(p_phone)) < 8 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'phone_required');
  END IF;

  SELECT (raw_user_meta_data->>'university_id')::UUID INTO v_uni_id FROM auth.users WHERE id = v_user_id;
  IF v_uni_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_university_id'); END IF;

  SELECT * INTO v_balance FROM app.actor_balances WHERE actor_type = 'university' AND actor_id = v_uni_id;
  IF v_balance IS NULL OR v_balance.available_balance <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_funds_available', 'available', 0);
  END IF;

  -- Mettre à jour le payout_phone de l'université
  UPDATE app.universities SET payout_phone = p_phone WHERE id = v_uni_id;

  UPDATE app.actor_balances SET
    available_balance = available_balance - v_balance.available_balance,
    total_withdrawn = total_withdrawn + v_balance.available_balance,
    updated_at = NOW()
  WHERE actor_type = 'university' AND actor_id = v_uni_id;

  INSERT INTO app.payout_queue (beneficiary_type, beneficiary_user_id, beneficiary_phone, amount, currency, reason, status)
  VALUES ('university', v_uni_id, p_phone, v_balance.available_balance, COALESCE(v_balance.currency, 'XOF'), 'university_share', 'pending')
  RETURNING id INTO v_payout_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'payout_id', v_payout_id, 'amount', v_balance.available_balance, 'phone', p_phone);
END; $$;

-- ============================================================
-- RPC 10 : app_admin_list_actor_balances
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_list_actor_balances(p_actor_type TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID := auth.uid(); v_role TEXT; v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.actor_type, t.total_earned DESC), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT ab.*,
           CASE
             WHEN ab.actor_type = 'instructor' THEN (SELECT i.full_name FROM app.instructors i WHERE i.id = ab.actor_id)
             WHEN ab.actor_type = 'university' THEN (SELECT u.name FROM app.universities u WHERE u.id = ab.actor_id)
             WHEN ab.actor_type = 'commercial' THEN (SELECT au.email FROM auth.users au WHERE au.id = ab.actor_id)
             WHEN ab.actor_type = 'merchant' THEN (SELECT m.name FROM app.marketplace_merchants m WHERE m.owner_user_id = ab.actor_id)
             ELSE NULL
           END AS display_name
    FROM app.actor_balances ab
    WHERE (p_actor_type IS NULL OR ab.actor_type = p_actor_type)
  ) t;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'balances', v_result);
END; $$;
