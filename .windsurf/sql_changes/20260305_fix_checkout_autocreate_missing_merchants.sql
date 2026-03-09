-- Fix: checkout should not fail when a listing's merchant (owner_user_id) has no row in app.marketplace_merchants.
-- Strategy: auto-create a minimal merchant row on-the-fly using app.merchant_profiles when available.

CREATE OR REPLACE FUNCTION public.app_student_checkout_create_order_from_cart()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_cart_id uuid;
  v_currency text;
  v_orders jsonb := '[]'::jsonb;
  merchant_rec record;
  v_merchant_name text;
  v_slug text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id INTO v_cart_id
  FROM app.marketplace_carts
  WHERE user_id = v_user AND status = 'open'
  LIMIT 1;

  IF v_cart_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'cart_not_found');
  END IF;

  SELECT max(COALESCE(i.currency, l.currency))
  INTO v_currency
  FROM app.marketplace_cart_items i
  JOIN app.marketplace_listings l ON l.id = i.listing_id
  WHERE i.cart_id = v_cart_id;

  IF NOT EXISTS (SELECT 1 FROM app.marketplace_cart_items WHERE cart_id = v_cart_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'cart_empty');
  END IF;

  FOR merchant_rec IN (
    SELECT
      l.merchant_id AS merchant_owner_user_id,
      COALESCE(sum(COALESCE(i.unit_price, l.price_from, 0) * i.quantity), 0) AS total_amount
    FROM app.marketplace_cart_items i
    JOIN app.marketplace_listings l ON l.id = i.listing_id
    WHERE i.cart_id = v_cart_id
    GROUP BY l.merchant_id
  ) LOOP
    DECLARE
      v_order_id uuid;
      v_merchant_id uuid;
    BEGIN
      SELECT m.id
      INTO v_merchant_id
      FROM app.marketplace_merchants m
      WHERE m.owner_user_id = merchant_rec.merchant_owner_user_id
        AND m.is_active = true
      LIMIT 1;

      IF v_merchant_id IS NULL THEN
        SELECT COALESCE(NULLIF(mp.display_name, ''), 'Marchand')
        INTO v_merchant_name
        FROM app.merchant_profiles mp
        WHERE mp.user_id = merchant_rec.merchant_owner_user_id
        LIMIT 1;

        v_slug := 'auto-' || replace(gen_random_uuid()::text, '-', '');

        INSERT INTO app.marketplace_merchants(
          owner_user_id,
          name,
          slug,
          status,
          is_active
        )
        VALUES (
          merchant_rec.merchant_owner_user_id,
          COALESCE(v_merchant_name, 'Marchand'),
          v_slug,
          'pending',
          true
        )
        RETURNING id INTO v_merchant_id;
      END IF;

      INSERT INTO app.marketplace_orders(student_id, merchant_id, status, total_amount, currency)
      VALUES (v_user, v_merchant_id, 'pending', merchant_rec.total_amount, v_currency)
      RETURNING id INTO v_order_id;

      INSERT INTO app.marketplace_order_items(order_id, product_id, quantity, unit_price, currency)
      SELECT
        v_order_id,
        i.listing_id,
        i.quantity,
        COALESCE(i.unit_price, l.price_from),
        COALESCE(i.currency, l.currency)
      FROM app.marketplace_cart_items i
      JOIN app.marketplace_listings l ON l.id = i.listing_id
      WHERE i.cart_id = v_cart_id
        AND l.merchant_id = merchant_rec.merchant_owner_user_id;

      v_orders := v_orders || jsonb_build_object(
        'order_id', v_order_id,
        'merchant_id', v_merchant_id,
        'total_amount', merchant_rec.total_amount,
        'currency', v_currency
      );
    END;
  END LOOP;

  UPDATE app.marketplace_carts
  SET status = 'checked_out',
      updated_at = now()
  WHERE id = v_cart_id;

  RETURN jsonb_build_object(
    'success', true,
    'orders', v_orders
  );
END;
$$;
