-- ============================================================================
-- 7 Avril 2026 — Système de Crédits Academia
-- Phase 1b : RPCs
-- ============================================================================

-- ============================================================
-- RPC 1 : app_student_get_credit_balance
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_get_credit_balance()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rec app.student_credits%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_rec FROM app.student_credits WHERE student_id = v_uid;

  IF v_rec IS NULL THEN
    -- Auto-create row with welcome bonus
    INSERT INTO app.student_credits (student_id, balance, total_gifted)
    VALUES (v_uid, 30, 30)
    ON CONFLICT (student_id) DO NOTHING
    RETURNING * INTO v_rec;

    IF v_rec IS NOT NULL THEN
      INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
      VALUES (v_uid, 30, 30, 'welcome_bonus', 'Bonus de bienvenue — 30 crédits offerts');
    ELSE
      SELECT * INTO v_rec FROM app.student_credits WHERE student_id = v_uid;
    END IF;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'balance', COALESCE(v_rec.balance, 0),
    'total_purchased', COALESCE(v_rec.total_purchased, 0),
    'total_consumed', COALESCE(v_rec.total_consumed, 0),
    'total_gifted', COALESCE(v_rec.total_gifted, 0),
    'last_weekly_bonus', v_rec.last_weekly_bonus
  );
END;
$$;

-- ============================================================
-- RPC 2 : app_student_check_ai_access
-- Vérifie si l'étudiant a assez de crédits pour une action
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_check_ai_access(p_action_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_balance INTEGER;
  v_cost INTEGER;
  v_action_label TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Récupérer le prix de l'action
  SELECT cost_credits, label INTO v_cost, v_action_label
  FROM app.ai_action_prices
  WHERE action_code = p_action_code AND is_active = TRUE;

  IF v_cost IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_action', 'action_code', p_action_code);
  END IF;

  -- Récupérer le solde (auto-create si premier accès)
  SELECT balance INTO v_balance FROM app.student_credits WHERE student_id = v_uid;

  IF v_balance IS NULL THEN
    -- Auto-create with welcome bonus
    INSERT INTO app.student_credits (student_id, balance, total_gifted)
    VALUES (v_uid, 30, 30)
    ON CONFLICT (student_id) DO NOTHING;

    INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
    SELECT v_uid, 30, 30, 'welcome_bonus', 'Bonus de bienvenue — 30 crédits offerts'
    WHERE NOT EXISTS (
      SELECT 1 FROM app.credit_transactions WHERE student_id = v_uid AND transaction_type = 'welcome_bonus'
    );

    SELECT balance INTO v_balance FROM app.student_credits WHERE student_id = v_uid;
  END IF;

  v_balance := COALESCE(v_balance, 0);

  IF v_balance >= v_cost THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'allowed', TRUE,
      'cost', v_cost,
      'balance', v_balance,
      'balance_after', v_balance - v_cost,
      'action_label', v_action_label
    );
  ELSE
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'allowed', FALSE,
      'cost', v_cost,
      'balance', v_balance,
      'deficit', v_cost - v_balance,
      'action_label', v_action_label,
      'reason', 'insufficient_credits'
    );
  END IF;
END;
$$;

-- ============================================================
-- RPC 3 : app_student_reserve_credits
-- Bloque les crédits AVANT l'appel OpenRouter
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_reserve_credits(
  p_action_code TEXT,
  p_edge_function TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
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

  -- Déduire du solde
  v_new_balance := v_balance - v_cost;
  UPDATE app.student_credits SET
    balance = v_new_balance,
    updated_at = NOW()
  WHERE student_id = v_uid;

  -- Créer la réservation
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

-- ============================================================
-- RPC 4 : app_student_confirm_credits
-- Confirme la consommation après succès OpenRouter
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_confirm_credits(
  p_reservation_id UUID,
  p_openrouter_cost_usd NUMERIC DEFAULT 0,
  p_openrouter_model TEXT DEFAULT NULL,
  p_tokens_input INTEGER DEFAULT 0,
  p_tokens_output INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_res app.credit_reservations%ROWTYPE;
  v_balance INTEGER;
BEGIN
  SELECT * INTO v_res FROM app.credit_reservations WHERE id = p_reservation_id;

  IF v_res IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'reservation_not_found');
  END IF;

  IF v_res.status <> 'reserved' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'reservation_already_resolved', 'status', v_res.status);
  END IF;

  -- Marquer comme confirmé
  UPDATE app.credit_reservations SET
    status = 'confirmed',
    openrouter_cost_usd = p_openrouter_cost_usd,
    openrouter_model = p_openrouter_model,
    tokens_input = p_tokens_input,
    tokens_output = p_tokens_output,
    resolved_at = NOW()
  WHERE id = p_reservation_id;

  -- Mettre à jour total_consumed
  UPDATE app.student_credits SET
    total_consumed = total_consumed + v_res.amount,
    updated_at = NOW()
  WHERE student_id = v_res.student_id;

  -- Récupérer le solde actuel
  SELECT balance INTO v_balance FROM app.student_credits WHERE student_id = v_res.student_id;

  -- Log dans credit_transactions
  INSERT INTO app.credit_transactions (
    student_id, amount, balance_after, transaction_type, action_code,
    edge_function, openrouter_cost_usd, openrouter_model, tokens_input, tokens_output,
    reservation_id, description
  ) VALUES (
    v_res.student_id, -v_res.amount, v_balance, 'consumption', v_res.action_code,
    v_res.edge_function, p_openrouter_cost_usd, p_openrouter_model, p_tokens_input, p_tokens_output,
    p_reservation_id, v_res.action_code || ' via ' || COALESCE(p_openrouter_model, 'unknown')
  );

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'consumed', v_res.amount,
    'balance', v_balance,
    'model_used', p_openrouter_model,
    'cost_usd', p_openrouter_cost_usd
  );
END;
$$;

-- ============================================================
-- RPC 5 : app_student_refund_credits
-- Rembourse si erreur OpenRouter
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_refund_credits(p_reservation_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_res app.credit_reservations%ROWTYPE;
  v_new_balance INTEGER;
BEGIN
  SELECT * INTO v_res FROM app.credit_reservations WHERE id = p_reservation_id;

  IF v_res IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'reservation_not_found');
  END IF;

  IF v_res.status <> 'reserved' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'reservation_already_resolved', 'status', v_res.status);
  END IF;

  -- Rembourser
  UPDATE app.student_credits SET
    balance = balance + v_res.amount,
    updated_at = NOW()
  WHERE student_id = v_res.student_id
  RETURNING balance INTO v_new_balance;

  -- Marquer comme remboursé
  UPDATE app.credit_reservations SET
    status = 'refunded',
    resolved_at = NOW()
  WHERE id = p_reservation_id;

  -- Log
  INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, action_code, reservation_id, description)
  VALUES (v_res.student_id, v_res.amount, v_new_balance, 'refund', v_res.action_code, p_reservation_id,
          'Remboursement ' || v_res.action_code || ' (erreur IA)');

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'refunded', v_res.amount,
    'new_balance', v_new_balance
  );
END;
$$;

-- ============================================================
-- RPC 6 : app_student_purchase_credits
-- Créditer après paiement LigdiCash confirmé
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_purchase_credits(
  p_pack_code TEXT,
  p_payment_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_pack app.credit_packs%ROWTYPE;
  v_credits_total INTEGER;
  v_new_balance INTEGER;
  v_is_first_purchase BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_pack FROM app.credit_packs WHERE code = p_pack_code AND is_active = TRUE;
  IF v_pack IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'pack_not_found');
  END IF;

  -- Vérifier si c'est le premier achat (bonus +50%)
  SELECT NOT EXISTS (
    SELECT 1 FROM app.credit_transactions WHERE student_id = v_uid AND transaction_type = 'purchase'
  ) INTO v_is_first_purchase;

  -- Calculer crédits totaux (base + bonus pack + bonus premier achat)
  v_credits_total := v_pack.credits;
  IF v_pack.bonus_percent > 0 THEN
    v_credits_total := v_credits_total + ROUND(v_pack.credits * v_pack.bonus_percent / 100.0)::INTEGER;
  END IF;
  IF v_is_first_purchase THEN
    v_credits_total := v_credits_total + ROUND(v_pack.credits * 0.5)::INTEGER; -- +50% premier achat
  END IF;

  -- Créditer (upsert student_credits)
  INSERT INTO app.student_credits (student_id, balance, total_purchased)
  VALUES (v_uid, v_credits_total, v_credits_total)
  ON CONFLICT (student_id) DO UPDATE SET
    balance = app.student_credits.balance + v_credits_total,
    total_purchased = app.student_credits.total_purchased + v_credits_total,
    updated_at = NOW()
  RETURNING balance INTO v_new_balance;

  -- Log transaction
  INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
  VALUES (v_uid, v_credits_total, v_new_balance, 'purchase',
          'Achat pack ' || v_pack.name || ' (' || v_pack.credits || ' + bonus) via LigdiCash'
          || CASE WHEN v_is_first_purchase THEN ' [PREMIER ACHAT +50%]' ELSE '' END);

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'credits_added', v_credits_total,
    'pack_base', v_pack.credits,
    'bonus_percent', v_pack.bonus_percent,
    'first_purchase_bonus', v_is_first_purchase,
    'new_balance', v_new_balance,
    'pack_name', v_pack.name
  );
END;
$$;

-- ============================================================
-- RPC 7 : app_student_claim_weekly_bonus
-- Réclamer le bonus hebdomadaire (15 crédits)
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_claim_weekly_bonus()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_last_bonus TIMESTAMPTZ;
  v_new_balance INTEGER;
  v_bonus INTEGER := 15;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Vérifier quand le dernier bonus a été reçu
  SELECT last_weekly_bonus INTO v_last_bonus
  FROM app.student_credits
  WHERE student_id = v_uid;

  -- Si jamais reçu ou reçu il y a plus de 6 jours
  IF v_last_bonus IS NOT NULL AND v_last_bonus > NOW() - INTERVAL '6 days' THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', 'bonus_already_claimed',
      'last_bonus', v_last_bonus,
      'next_available', v_last_bonus + INTERVAL '7 days'
    );
  END IF;

  -- Créditer le bonus
  INSERT INTO app.student_credits (student_id, balance, total_gifted, last_weekly_bonus)
  VALUES (v_uid, v_bonus, v_bonus, NOW())
  ON CONFLICT (student_id) DO UPDATE SET
    balance = app.student_credits.balance + v_bonus,
    total_gifted = app.student_credits.total_gifted + v_bonus,
    last_weekly_bonus = NOW(),
    updated_at = NOW()
  RETURNING balance INTO v_new_balance;

  INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
  VALUES (v_uid, v_bonus, v_new_balance, 'weekly_bonus', 'Bonus hebdomadaire — 15 crédits offerts');

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'credits_added', v_bonus,
    'new_balance', v_new_balance,
    'next_available', NOW() + INTERVAL '7 days'
  );
END;
$$;

-- ============================================================
-- RPC 8 : app_student_list_credit_transactions
-- Historique des transactions crédits
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_list_credit_transactions(
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
  v_total INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT COUNT(*) INTO v_total FROM app.credit_transactions WHERE student_id = v_uid;

  SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT id, amount, balance_after, transaction_type, action_code, description,
           openrouter_model, tokens_input, tokens_output, created_at
    FROM app.credit_transactions
    WHERE student_id = v_uid
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'transactions', v_result, 'total', v_total);
END;
$$;

-- ============================================================
-- RPC 9 : app_student_list_credit_packs
-- Liste les packs disponibles
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_list_credit_packs()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT COALESCE(JSONB_AGG(row_to_json(p)::JSONB ORDER BY p.sort_order), '[]'::JSONB)
  INTO v_result
  FROM app.credit_packs p
  WHERE p.is_active = TRUE;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'packs', v_result);
END;
$$;

-- ============================================================
-- RPC 10 : app_student_list_ai_action_prices
-- Liste les prix des actions IA
-- ============================================================
CREATE OR REPLACE FUNCTION app_student_list_ai_action_prices()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT COALESCE(JSONB_AGG(row_to_json(a)::JSONB ORDER BY a.cost_credits), '[]'::JSONB)
  INTO v_result
  FROM app.ai_action_prices a
  WHERE a.is_active = TRUE;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'actions', v_result);
END;
$$;

-- ============================================================
-- RPC 11 : app_admin_get_ai_usage_stats
-- Stats d'usage IA pour l'admin
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_get_ai_usage_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  SELECT JSONB_BUILD_OBJECT(
    'total_students_with_credits', (SELECT COUNT(*) FROM app.student_credits),
    'total_credits_in_circulation', (SELECT COALESCE(SUM(balance), 0) FROM app.student_credits),
    'total_credits_purchased', (SELECT COALESCE(SUM(total_purchased), 0) FROM app.student_credits),
    'total_credits_consumed', (SELECT COALESCE(SUM(total_consumed), 0) FROM app.student_credits),
    'total_credits_gifted', (SELECT COALESCE(SUM(total_gifted), 0) FROM app.student_credits),
    'total_openrouter_cost_usd', (SELECT COALESCE(SUM(openrouter_cost_usd), 0) FROM app.credit_transactions WHERE transaction_type = 'consumption'),
    'total_transactions', (SELECT COUNT(*) FROM app.credit_transactions),
    'transactions_today', (SELECT COUNT(*) FROM app.credit_transactions WHERE created_at >= CURRENT_DATE),
    'active_reservations', (SELECT COUNT(*) FROM app.credit_reservations WHERE status = 'reserved'),
    'usage_by_action', (
      SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB), '[]'::JSONB) FROM (
        SELECT action_code, COUNT(*) AS count, SUM(-amount) AS total_credits,
               ROUND(COALESCE(SUM(openrouter_cost_usd), 0)::NUMERIC, 4) AS total_cost_usd
        FROM app.credit_transactions
        WHERE transaction_type = 'consumption' AND action_code IS NOT NULL
        GROUP BY action_code ORDER BY count DESC
      ) t
    ),
    'usage_by_model', (
      SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB), '[]'::JSONB) FROM (
        SELECT openrouter_model, COUNT(*) AS count,
               ROUND(COALESCE(SUM(openrouter_cost_usd), 0)::NUMERIC, 4) AS total_cost_usd
        FROM app.credit_transactions
        WHERE transaction_type = 'consumption' AND openrouter_model IS NOT NULL
        GROUP BY openrouter_model ORDER BY count DESC
      ) t
    )
  ) INTO v_result;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'stats', v_result);
END;
$$;

-- ============================================================
-- RPC 12 : app_admin_manage_credit_pack
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_manage_credit_pack(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_code TEXT DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_credits INTEGER DEFAULT NULL,
  p_price_xof INTEGER DEFAULT NULL,
  p_bonus_percent INTEGER DEFAULT 0,
  p_is_active BOOLEAN DEFAULT TRUE,
  p_sort_order INTEGER DEFAULT 10,
  p_pack_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  IF p_action = 'create' THEN
    INSERT INTO app.credit_packs (code, name, credits, price_xof, bonus_percent, is_active, sort_order)
    VALUES (p_code, p_name, p_credits, p_price_xof, p_bonus_percent, p_is_active, p_sort_order)
    RETURNING id INTO v_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'pack_id', v_id);

  ELSIF p_action = 'update' AND p_pack_id IS NOT NULL THEN
    UPDATE app.credit_packs SET
      name = COALESCE(p_name, name),
      credits = COALESCE(p_credits, credits),
      price_xof = COALESCE(p_price_xof, price_xof),
      bonus_percent = COALESCE(p_bonus_percent, bonus_percent),
      is_active = COALESCE(p_is_active, is_active),
      sort_order = COALESCE(p_sort_order, sort_order)
    WHERE id = p_pack_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);

  ELSIF p_action = 'delete' AND p_pack_id IS NOT NULL THEN
    DELETE FROM app.credit_packs WHERE id = p_pack_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);

  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_action');
  END IF;
END;
$$;

-- ============================================================
-- RPC 13 : app_admin_manage_ai_action_price
-- ============================================================
CREATE OR REPLACE FUNCTION app_admin_manage_ai_action_price(
  p_action TEXT,
  p_action_code TEXT DEFAULT NULL,
  p_label TEXT DEFAULT NULL,
  p_cost_credits INTEGER DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT TRUE,
  p_price_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin'); END IF;

  IF p_action = 'create' THEN
    INSERT INTO app.ai_action_prices (action_code, label, cost_credits, description, is_active)
    VALUES (p_action_code, p_label, p_cost_credits, p_description, p_is_active)
    RETURNING id INTO v_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'price_id', v_id);

  ELSIF p_action = 'update' AND p_price_id IS NOT NULL THEN
    UPDATE app.ai_action_prices SET
      label = COALESCE(p_label, label),
      cost_credits = COALESCE(p_cost_credits, cost_credits),
      description = COALESCE(p_description, description),
      is_active = COALESCE(p_is_active, is_active),
      updated_at = NOW()
    WHERE id = p_price_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);

  ELSIF p_action = 'delete' AND p_price_id IS NOT NULL THEN
    DELETE FROM app.ai_action_prices WHERE id = p_price_id;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);

  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_action');
  END IF;
END;
$$;
