-- ============================================================================
-- Fix: Les Edge Functions appellent avec service_role, donc auth.uid() = NULL.
-- On ajoute un paramètre p_student_id aux RPCs appelées par les Edge Functions.
-- Les RPCs appelées directement par Flutter gardent auth.uid().
-- ============================================================================

-- RPC reserve_credits : ajout p_student_id pour appel depuis Edge Functions
CREATE OR REPLACE FUNCTION app_student_reserve_credits(
  p_action_code TEXT,
  p_edge_function TEXT DEFAULT NULL,
  p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := COALESCE(p_student_id, auth.uid());
  v_balance INTEGER;
  v_cost INTEGER;
  v_reservation_id UUID;
  v_new_balance INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT cost_credits INTO v_cost
  FROM app.ai_action_prices
  WHERE action_code = p_action_code AND is_active = TRUE;

  IF v_cost IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_action');
  END IF;

  -- Auto-create with welcome bonus if first time
  IF NOT EXISTS (SELECT 1 FROM app.student_credits WHERE student_id = v_uid) THEN
    INSERT INTO app.student_credits (student_id, balance, total_gifted)
    VALUES (v_uid, 30, 30)
    ON CONFLICT (student_id) DO NOTHING;

    INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
    SELECT v_uid, 30, 30, 'welcome_bonus', 'Bonus de bienvenue — 30 crédits offerts'
    WHERE NOT EXISTS (
      SELECT 1 FROM app.credit_transactions WHERE student_id = v_uid AND transaction_type = 'welcome_bonus'
    );
  END IF;

  -- Lock row for update
  SELECT balance INTO v_balance
  FROM app.student_credits
  WHERE student_id = v_uid
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_cost THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', 'insufficient_credits',
      'balance', COALESCE(v_balance, 0),
      'cost', v_cost
    );
  END IF;

  v_new_balance := v_balance - v_cost;
  UPDATE app.student_credits SET
    balance = v_new_balance,
    updated_at = NOW()
  WHERE student_id = v_uid;

  INSERT INTO app.credit_reservations (student_id, action_code, amount, status, edge_function)
  VALUES (v_uid, p_action_code, v_cost, 'reserved', p_edge_function)
  RETURNING id INTO v_reservation_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'reservation_id', v_reservation_id,
    'cost', v_cost,
    'new_balance', v_new_balance
  );
END;
$$;

-- RPC check_ai_access : ajout p_student_id
CREATE OR REPLACE FUNCTION app_student_check_ai_access(
  p_action_code TEXT,
  p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := COALESCE(p_student_id, auth.uid());
  v_balance INTEGER;
  v_cost INTEGER;
  v_action_label TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT cost_credits, label INTO v_cost, v_action_label
  FROM app.ai_action_prices
  WHERE action_code = p_action_code AND is_active = TRUE;

  IF v_cost IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_action', 'action_code', p_action_code);
  END IF;

  -- Auto-create if first time
  IF NOT EXISTS (SELECT 1 FROM app.student_credits WHERE student_id = v_uid) THEN
    INSERT INTO app.student_credits (student_id, balance, total_gifted)
    VALUES (v_uid, 30, 30)
    ON CONFLICT (student_id) DO NOTHING;

    INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
    SELECT v_uid, 30, 30, 'welcome_bonus', 'Bonus de bienvenue — 30 crédits offerts'
    WHERE NOT EXISTS (
      SELECT 1 FROM app.credit_transactions WHERE student_id = v_uid AND transaction_type = 'welcome_bonus'
    );
  END IF;

  SELECT balance INTO v_balance FROM app.student_credits WHERE student_id = v_uid;
  v_balance := COALESCE(v_balance, 0);

  IF v_balance >= v_cost THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE, 'allowed', TRUE, 'cost', v_cost,
      'balance', v_balance, 'balance_after', v_balance - v_cost, 'action_label', v_action_label
    );
  ELSE
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE, 'allowed', FALSE, 'cost', v_cost,
      'balance', v_balance, 'deficit', v_cost - v_balance,
      'action_label', v_action_label, 'reason', 'insufficient_credits'
    );
  END IF;
END;
$$;
