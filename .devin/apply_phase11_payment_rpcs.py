#!/usr/bin/env python3
"""Phase 11 — Create scaffolding RPCs for future payment integration."""
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

rpcs = [
    # 1. Process a marketplace payment (called after external payment provider confirms)
    """
CREATE OR REPLACE FUNCTION public.app_marketplace_process_payment(
  p_order_id UUID,
  p_payment_method TEXT DEFAULT 'pending',
  p_payment_provider TEXT DEFAULT NULL,
  p_payment_provider_ref TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_order app.marketplace_orders%ROWTYPE;
  v_commission_rate NUMERIC := 0.10;
  v_gross NUMERIC;
  v_commission NUMERIC;
  v_net NUMERIC;
  v_payment_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_order FROM app.marketplace_orders WHERE id = p_order_id AND student_id = v_user;
  IF v_order IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF EXISTS (SELECT 1 FROM app.marketplace_payments WHERE order_id = p_order_id AND status != 'failed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_already_exists');
  END IF;

  v_gross := COALESCE(v_order.total_amount, 0);
  v_commission := ROUND(v_gross * v_commission_rate, 2);
  v_net := v_gross - v_commission;

  INSERT INTO app.marketplace_payments (
    order_id, buyer_id, merchant_id,
    gross_amount, commission_rate, commission_amount, net_amount,
    currency, payment_method, payment_provider, payment_provider_ref,
    status
  ) VALUES (
    p_order_id, v_user, v_order.merchant_id,
    v_gross, v_commission_rate, v_commission, v_net,
    COALESCE(v_order.currency, 'XOF'), p_payment_method, p_payment_provider, p_payment_provider_ref,
    'pending'
  ) RETURNING id INTO v_payment_id;

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'gross_amount', v_gross,
    'commission_amount', v_commission,
    'net_amount', v_net,
    'status', 'pending'
  );
END;
$$;
    """,
    # 2. Release escrow (admin or auto after X days)
    """
CREATE OR REPLACE FUNCTION public.app_marketplace_release_escrow(
  p_payment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_payment app.marketplace_payments%ROWTYPE;
BEGIN
  SELECT * INTO v_payment FROM app.marketplace_payments WHERE id = p_payment_id;
  IF v_payment IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
  END IF;

  IF v_payment.status != 'captured' THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_not_captured');
  END IF;

  UPDATE app.marketplace_payments
  SET status = 'released', escrow_released_at = NOW(), updated_at = NOW()
  WHERE id = p_payment_id;

  INSERT INTO app.marketplace_merchant_balances (merchant_id, available_balance, pending_balance, total_earned, total_commission, currency)
  VALUES (v_payment.merchant_id, v_payment.net_amount, 0, v_payment.net_amount, v_payment.commission_amount, v_payment.currency)
  ON CONFLICT (merchant_id) DO UPDATE SET
    available_balance = app.marketplace_merchant_balances.available_balance + v_payment.net_amount,
    total_earned = app.marketplace_merchant_balances.total_earned + v_payment.net_amount,
    total_commission = app.marketplace_merchant_balances.total_commission + v_payment.commission_amount,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'released', true);
END;
$$;
    """,
    # 3. Merchant get balance
    """
CREATE OR REPLACE FUNCTION public.app_merchant_get_my_balance()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_merchant_id UUID;
  v_balance app.marketplace_merchant_balances%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id INTO v_merchant_id FROM app.marketplace_merchants WHERE owner_user_id = v_user LIMIT 1;
  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'available_balance', 0, 'pending_balance', 0, 'total_earned', 0, 'total_commission', 0, 'currency', 'XOF');
  END IF;

  SELECT * INTO v_balance FROM app.marketplace_merchant_balances WHERE merchant_id = v_merchant_id;
  IF v_balance IS NULL THEN
    RETURN jsonb_build_object('success', true, 'available_balance', 0, 'pending_balance', 0, 'total_earned', 0, 'total_commission', 0, 'currency', 'XOF');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'available_balance', v_balance.available_balance,
    'pending_balance', v_balance.pending_balance,
    'total_earned', v_balance.total_earned,
    'total_commission', v_balance.total_commission,
    'currency', v_balance.currency
  );
END;
$$;
    """,
    # 4. Admin list marketplace payments
    """
CREATE OR REPLACE FUNCTION public.app_admin_list_marketplace_payments(
  p_status TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_items JSONB;
  v_total INT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_payments p
  WHERE (p_status IS NULL OR p.status = p_status);

  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_items
  FROM (
    SELECT p.id, p.order_id, p.buyer_id, p.merchant_id,
           p.gross_amount, p.commission_rate, p.commission_amount, p.net_amount,
           p.currency, p.payment_method, p.payment_provider, p.payment_provider_ref,
           p.status, p.escrow_released_at, p.created_at,
           mm.name AS merchant_name
    FROM app.marketplace_payments p
    LEFT JOIN app.marketplace_merchants mm ON mm.id = p.merchant_id
    WHERE (p_status IS NULL OR p.status = p_status)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object('success', true, 'items', v_items, 'total', v_total);
END;
$$;
    """,
]

for i, sql in enumerate(rpcs, 1):
    resp = requests.post(
        m.url + "/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql.strip()},
        timeout=30,
    )
    data = resp.json()
    ok = isinstance(data, dict) and data.get("ok") is not False
    err = data.get("error", "") if isinstance(data, dict) else str(data)[:100]
    sys.stdout.write("RPC %d/4: %s%s\n" % (i, "OK" if ok else "ERR", (" — " + str(err)) if not ok else ""))
