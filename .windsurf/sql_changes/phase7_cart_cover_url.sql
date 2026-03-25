-- ============================================================
-- PHASE 7 — Add cover_url to cart items response
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_student_get_cart()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $function$
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
$function$;
