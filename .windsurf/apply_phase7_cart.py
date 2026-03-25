#!/usr/bin/env python3
"""Apply Phase 7 cart RPC update as a single statement."""
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

sql = """
CREATE OR REPLACE FUNCTION public.app_student_get_cart()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_cart_id uuid;
  v_items jsonb;
  v_total numeric := 0;
  v_currency text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id INTO v_cart_id
  FROM app.marketplace_carts
  WHERE user_id = v_user AND status = 'open'
  LIMIT 1;

  IF v_cart_id IS NULL THEN
    INSERT INTO app.marketplace_carts(user_id, status)
    VALUES (v_user, 'open')
    RETURNING id INTO v_cart_id;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', i.id,
        'listing_id', i.listing_id,
        'quantity', i.quantity,
        'unit_price', i.unit_price,
        'currency', i.currency,
        'title', l.title,
        'cover_url', l.cover_url,
        'merchant_id', l.merchant_id,
        'price_from', l.price_from,
        'price_to', l.price_to
      )
      ORDER BY i.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM app.marketplace_cart_items i
  JOIN app.marketplace_listings l ON l.id = i.listing_id
  WHERE i.cart_id = v_cart_id;

  SELECT
    COALESCE(sum(COALESCE(i.unit_price, l.price_from, 0) * i.quantity), 0),
    max(COALESCE(i.currency, l.currency))
  INTO v_total, v_currency
  FROM app.marketplace_cart_items i
  JOIN app.marketplace_listings l ON l.id = i.listing_id
  WHERE i.cart_id = v_cart_id;

  RETURN jsonb_build_object(
    'success', true,
    'cart_id', v_cart_id,
    'items', v_items,
    'total', v_total,
    'currency', v_currency
  );
END;
$$;
"""

resp = requests.post(
    m.url + "/rest/v1/rpc/admin_execute_sql",
    headers=m.headers,
    json={"p_sql": sql.strip()},
    timeout=30,
)
data = resp.json()
if isinstance(data, dict) and data.get("ok") is not False:
    print("OK — app_student_get_cart updated with cover_url")
else:
    err = data.get("error", str(data)[:200]) if isinstance(data, dict) else str(data)[:200]
    print("ERROR: %s" % err)
