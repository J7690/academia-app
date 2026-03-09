-- Patch Marketplace: fix checkout merchant FK + add cover_url in listings list RPC

-- 1) Fix checkout: marketplace_orders.merchant_id expects app.marketplace_merchants.id,
-- but marketplace_listings.merchant_id currently stores the merchant owner's user_id.
-- We map owner_user_id -> merchant.id when creating orders.

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

  -- Create one order per merchant.
  -- IMPORTANT: l.merchant_id is the merchant OWNER user_id (see mp.user_id = l.merchant_id in list RPC)
  -- but orders expect marketplace_merchants.id.
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
        RETURN jsonb_build_object(
          'success', false,
          'error', 'merchant_not_found',
          'merchant_owner_user_id', merchant_rec.merchant_owner_user_id
        );
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


-- 2) Add cover_url to listings list RPC so home can render images without calling detail RPC.
-- cover_url comes from the first active marketplace_listing_media (external_url OR public storage url)

CREATE OR REPLACE FUNCTION public.app_student_list_marketplace_listings(
  p_type text DEFAULT NULL::text,
  p_search text DEFAULT NULL::text,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_sort text DEFAULT 'newest'::text,
  p_verified_only boolean DEFAULT false,
  p_ready_to_ship_only boolean DEFAULT false,
  p_category_id uuid DEFAULT NULL::uuid,
  p_sub_category_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
  v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
  v_sort TEXT := COALESCE(NULLIF(TRIM(COALESCE(p_sort, '')), ''), 'newest');
  v_total INTEGER;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_listings l
  WHERE l.is_active = TRUE
    AND l.status = 'published'
    AND l.review_status = 'approved'
    AND (v_type IS NULL OR LOWER(l.type) = LOWER(v_type))
    AND (p_category_id IS NULL OR l.category_id = p_category_id)
    AND (p_sub_category_id IS NULL OR l.sub_category_id = p_sub_category_id)
    AND (
      v_search IS NULL
      OR l.title ILIKE '%' || v_search || '%'
      OR l.organization_name ILIKE '%' || v_search || '%'
      OR l.city ILIKE '%' || v_search || '%'
      OR l.country ILIKE '%' || v_search || '%'
    )
    AND (
      p_verified_only IS DISTINCT FROM TRUE
      OR EXISTS (
        SELECT 1
        FROM app.merchant_profiles mp
        WHERE mp.user_id = l.merchant_id
          AND mp.is_active = TRUE
          AND mp.is_verified = TRUE
      )
    )
    AND (
      p_ready_to_ship_only IS DISTINCT FROM TRUE
      OR l.is_ready_to_ship = TRUE
    );

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', (
      SELECT COALESCE(
        jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),
        '[]'::jsonb
      )
      FROM (
        SELECT
          l.id,
          l.merchant_id,
          l.title,
          l.short_description,
          l.description,
          l.type,
          l.category,
          l.category_id,
          l.sub_category_id,
          l.organization_name,
          l.organization_logo_url,
          l.country,
          l.city,
          l.price_from,
          l.price_to,
          l.currency,
          l.min_order_qty,
          l.lead_time_days,
          l.is_ready_to_ship,
          l.status,
          l.review_status,
          l.reactions_count,
          l.comments_count,
          l.created_at,
          l.updated_at,
          (
            SELECT COALESCE(
              NULLIF(ml.external_url, ''),
              CASE
                WHEN ml.storage_path IS NOT NULL AND ml.storage_path <> ''
                THEN (v_base_url || '/storage/v1/object/public/' || ml.storage_bucket || '/' || ml.storage_path)
                ELSE NULL
              END
            )
            FROM app.marketplace_listing_media ml
            WHERE ml.listing_id = l.id
              AND ml.is_active = true
            ORDER BY ml.sort_order ASC, ml.created_at ASC
            LIMIT 1
          ) AS cover_url,
          EXISTS (
            SELECT 1
            FROM app.merchant_profiles mp
            WHERE mp.user_id = l.merchant_id
              AND mp.is_active = TRUE
              AND mp.is_verified = TRUE
          ) AS merchant_is_verified,
          EXISTS(
            SELECT 1
            FROM app.marketplace_listing_bookmarks b
            WHERE b.user_id = v_user_id
              AND b.listing_id = l.id
          ) AS is_bookmarked
        FROM app.marketplace_listings l
        WHERE l.is_active = TRUE
          AND l.status = 'published'
          AND l.review_status = 'approved'
          AND (v_type IS NULL OR LOWER(l.type) = LOWER(v_type))
          AND (p_category_id IS NULL OR l.category_id = p_category_id)
          AND (p_sub_category_id IS NULL OR l.sub_category_id = p_sub_category_id)
          AND (
            v_search IS NULL
            OR l.title ILIKE '%' || v_search || '%'
            OR l.organization_name ILIKE '%' || v_search || '%'
            OR l.city ILIKE '%' || v_search || '%'
            OR l.country ILIKE '%' || v_search || '%'
          )
          AND (
            p_verified_only IS DISTINCT FROM TRUE
            OR EXISTS (
              SELECT 1
              FROM app.merchant_profiles mp
              WHERE mp.user_id = l.merchant_id
                AND mp.is_active = TRUE
                AND mp.is_verified = TRUE
            )
          )
          AND (
            p_ready_to_ship_only IS DISTINCT FROM TRUE
            OR l.is_ready_to_ship = TRUE
          )
        ORDER BY
          CASE WHEN v_sort = 'newest' THEN l.created_at END DESC,
          CASE WHEN v_sort = 'oldest' THEN l.created_at END ASC,
          CASE WHEN v_sort = 'price_low' THEN l.price_from END ASC NULLS LAST,
          CASE WHEN v_sort = 'price_high' THEN l.price_to END DESC NULLS LAST,
          l.created_at DESC
        LIMIT GREATEST(1, LEAST(p_limit, 100))
        OFFSET GREATEST(0, p_offset)
      ) x
    )
  );
END;
$$;
