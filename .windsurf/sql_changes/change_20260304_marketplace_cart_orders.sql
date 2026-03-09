-- Marketplace cart + orders (no payment yet)


CREATE TABLE IF NOT EXISTS app.marketplace_carts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS marketplace_carts_one_open_per_user
  ON app.marketplace_carts (user_id)
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS app.marketplace_cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id uuid NOT NULL REFERENCES app.marketplace_carts(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES app.marketplace_listings(id) ON DELETE RESTRICT,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric,
  currency text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(cart_id, listing_id)
);

CREATE INDEX IF NOT EXISTS marketplace_cart_items_cart_id_idx
  ON app.marketplace_cart_items (cart_id);

-- NOTE: app.marketplace_orders / app.marketplace_order_items may already exist
-- in this project with a different schema (student_id/merchant_id/product_id).
-- We do NOT drop/alter them here. Checkout RPCs below adapt to the existing schema.

ALTER TABLE app.marketplace_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.marketplace_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.marketplace_order_items ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='app' AND tablename='marketplace_carts'
      AND policyname='user_manage_own_marketplace_carts'
  ) THEN
    CREATE POLICY user_manage_own_marketplace_carts
      ON app.marketplace_carts
      FOR ALL
      TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='app' AND tablename='marketplace_cart_items'
      AND policyname='user_manage_own_marketplace_cart_items'
  ) THEN
    CREATE POLICY user_manage_own_marketplace_cart_items
      ON app.marketplace_cart_items
      FOR ALL
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM app.marketplace_carts c
          WHERE c.id = marketplace_cart_items.cart_id
            AND c.user_id = auth.uid()
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM app.marketplace_carts c
          WHERE c.id = marketplace_cart_items.cart_id
            AND c.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='app' AND tablename='marketplace_orders'
      AND policyname='user_select_own_marketplace_orders'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='marketplace_orders' AND column_name='student_id'
    ) THEN
      CREATE POLICY user_select_own_marketplace_orders
        ON app.marketplace_orders
        FOR SELECT
        TO authenticated
        USING (student_id = auth.uid());
    ELSIF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='marketplace_orders' AND column_name='user_id'
    ) THEN
      CREATE POLICY user_select_own_marketplace_orders
        ON app.marketplace_orders
        FOR SELECT
        TO authenticated
        USING (user_id = auth.uid());
    END IF;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='app' AND tablename='marketplace_order_items'
      AND policyname='user_select_own_marketplace_order_items'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='marketplace_orders' AND column_name='student_id'
    ) THEN
      CREATE POLICY user_select_own_marketplace_order_items
        ON app.marketplace_order_items
        FOR SELECT
        TO authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM app.marketplace_orders o
            WHERE o.id = marketplace_order_items.order_id
              AND o.student_id = auth.uid()
          )
        );
    ELSIF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='marketplace_orders' AND column_name='user_id'
    ) THEN
      CREATE POLICY user_select_own_marketplace_order_items
        ON app.marketplace_order_items
        FOR SELECT
        TO authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM app.marketplace_orders o
            WHERE o.id = marketplace_order_items.order_id
              AND o.user_id = auth.uid()
          )
        );
    END IF;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.app_student_get_cart()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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

CREATE OR REPLACE FUNCTION public.app_student_cart_add_item(
  p_listing_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_cart_id uuid;
  v_min_qty integer;
  v_price numeric;
  v_currency text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_listing_id');
  END IF;

  SELECT min_order_qty, price_from, currency
  INTO v_min_qty, v_price, v_currency
  FROM app.marketplace_listings
  WHERE id = p_listing_id
    AND is_active = true
    AND review_status = 'approved';

  IF v_min_qty IS NULL THEN
    v_min_qty := 1;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_not_available');
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

  INSERT INTO app.marketplace_cart_items(
    cart_id, listing_id, quantity, unit_price, currency
  )
  VALUES (
    v_cart_id,
    p_listing_id,
    GREATEST(COALESCE(p_quantity, 1), v_min_qty),
    v_price,
    v_currency
  )
  ON CONFLICT (cart_id, listing_id)
  DO UPDATE SET
    quantity = app.marketplace_cart_items.quantity + EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    currency = EXCLUDED.currency,
    updated_at = now();

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_student_cart_update_quantity(
  p_item_id uuid,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_cart_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_item_id IS NULL OR p_quantity IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_params');
  END IF;

  SELECT i.cart_id INTO v_cart_id
  FROM app.marketplace_cart_items i
  JOIN app.marketplace_carts c ON c.id = i.cart_id
  WHERE i.id = p_item_id AND c.user_id = v_user AND c.status = 'open'
  LIMIT 1;

  IF v_cart_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'item_not_found');
  END IF;

  IF p_quantity <= 0 THEN
    DELETE FROM app.marketplace_cart_items WHERE id = p_item_id;
    RETURN jsonb_build_object('success', true);
  END IF;

  UPDATE app.marketplace_cart_items
  SET quantity = p_quantity,
      updated_at = now()
  WHERE id = p_item_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_student_cart_remove_item(
  p_item_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_item_id');
  END IF;

  DELETE FROM app.marketplace_cart_items i
  USING app.marketplace_carts c
  WHERE i.id = p_item_id
    AND c.id = i.cart_id
    AND c.user_id = v_user
    AND c.status = 'open';

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_student_cart_clear()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_cart_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id INTO v_cart_id
  FROM app.marketplace_carts
  WHERE user_id = v_user AND status = 'open'
  LIMIT 1;

  IF v_cart_id IS NULL THEN
    RETURN jsonb_build_object('success', true);
  END IF;

  DELETE FROM app.marketplace_cart_items WHERE cart_id = v_cart_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

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

  -- Create one order per merchant (existing schema requires merchant_id)
  FOR merchant_rec IN (
    SELECT
      l.merchant_id AS merchant_id,
      COALESCE(sum(COALESCE(i.unit_price, l.price_from, 0) * i.quantity), 0) AS total_amount
    FROM app.marketplace_cart_items i
    JOIN app.marketplace_listings l ON l.id = i.listing_id
    WHERE i.cart_id = v_cart_id
    GROUP BY l.merchant_id
  ) LOOP
    DECLARE
      v_order_id uuid;
    BEGIN
      INSERT INTO app.marketplace_orders(student_id, merchant_id, status, total_amount, currency)
      VALUES (v_user, merchant_rec.merchant_id, 'pending', merchant_rec.total_amount, v_currency)
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
        AND l.merchant_id = merchant_rec.merchant_id;

      v_orders := v_orders || jsonb_build_array(
        jsonb_build_object(
          'order_id', v_order_id,
          'merchant_id', merchant_rec.merchant_id,
          'total_amount', merchant_rec.total_amount,
          'currency', v_currency
        )
      );
    END;
  END LOOP;

  UPDATE app.marketplace_carts
  SET status = 'checked_out', updated_at = now()
  WHERE id = v_cart_id;

  DELETE FROM app.marketplace_cart_items WHERE cart_id = v_cart_id;

  INSERT INTO app.marketplace_carts(user_id, status)
  VALUES (v_user, 'open');

  RETURN jsonb_build_object('success', true, 'orders', v_orders);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_cart() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_cart_add_item(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_cart_update_quantity(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_cart_remove_item(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_cart_clear() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_checkout_create_order_from_cart() TO authenticated;
