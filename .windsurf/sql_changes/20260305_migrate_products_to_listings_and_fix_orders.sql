-- Migration: align Orders with Listings-based flow (Flutter uses marketplace_listings.id).
-- Problem: marketplace_order_items.product_id currently FK -> marketplace_products(id)
-- but checkout inserts listing_id (uuid) which doesn't exist in marketplace_products.
--
-- Strategy:
-- 1) Backfill app.marketplace_listings with rows whose id == marketplace_products.id
--    so existing order_items remain resolvable when we repoint FK to listings.
-- 2) Repoint FK marketplace_order_items.product_id -> marketplace_listings(id).
-- 3) Update order listing routines to join listings + cover image.

-- 1) Backfill listings from products (id-preserving)
INSERT INTO app.marketplace_listings (
  id,
  merchant_id,
  title,
  short_description,
  description,
  type,
  category,
  organization_name,
  organization_logo_url,
  country,
  city,
  price_from,
  price_to,
  currency,
  min_order_qty,
  lead_time_days,
  is_ready_to_ship,
  reactions_count,
  comments_count,
  status,
  is_active,
  is_featured,
  review_status,
  created_at,
  updated_at
)
SELECT
  p.id,
  COALESCE(m.owner_user_id, NULL),
  p.title,
  LEFT(COALESCE(NULLIF(p.description, ''), p.title, ''), 140),
  p.description,
  'product',
  p.category,
  COALESCE(NULLIF(m.name, ''), 'Marchand'),
  m.logo_url,
  COALESCE(NULLIF(m.country, ''), 'N/A'),
  COALESCE(NULLIF(m.city, ''), 'N/A'),
  p.price,
  p.price,
  p.currency,
  1,
  NULL,
  false,
  0,
  0,
  'published',
  true,
  COALESCE(p.is_featured, false),
  'approved',
  COALESCE(p.created_at, now()),
  COALESCE(p.updated_at, now())
FROM app.marketplace_products p
LEFT JOIN app.marketplace_merchants m ON m.id = p.merchant_id
WHERE NOT EXISTS (
  SELECT 1
  FROM app.marketplace_listings l
  WHERE l.id = p.id
);

-- 2) Repoint FK order_items.product_id -> listings(id)
ALTER TABLE app.marketplace_order_items
  DROP CONSTRAINT IF EXISTS marketplace_order_items_product_id_fkey;

ALTER TABLE app.marketplace_order_items
  ADD CONSTRAINT marketplace_order_items_product_id_fkey
  FOREIGN KEY (product_id)
  REFERENCES app.marketplace_listings(id)
  ON DELETE RESTRICT;

-- 3) Update student order list routine to join listings + cover image.
CREATE OR REPLACE FUNCTION public.app_list_student_marketplace_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result jsonb;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'order_id', o.id,
        'status', o.status,
        'total_amount', o.total_amount,
        'currency', o.currency,
        'delivery_mode', o.delivery_mode,
        'shipping_address', o.shipping_address,
        'student_notes', o.student_notes,
        'created_at', o.created_at,
        'merchant_id', m.id,
        'merchant_name', m.name,
        'merchant_city', m.city,
        'merchant_country', m.country,
        'items', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'product_id', i.product_id,
                'quantity', i.quantity,
                'unit_price', i.unit_price,
                'currency', i.currency,
                'product_title', l.title,
                'product_main_image_url', (
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
                )
              )
            ),
            '[]'::jsonb
          )
          FROM app.marketplace_order_items i
          JOIN app.marketplace_listings l ON l.id = i.product_id
          WHERE i.order_id = o.id
        )
      )
      ORDER BY o.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_result
  FROM app.marketplace_orders o
  JOIN app.marketplace_merchants m ON m.id = o.merchant_id
  WHERE o.student_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'orders', v_result);
END;
$$;

-- 4) Update merchant list orders routine to join listings + cover image.
CREATE OR REPLACE FUNCTION public.app_merchant_list_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text;
  v_merchant_id uuid;
  v_result jsonb;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  SELECT id
  INTO v_merchant_id
  FROM app.marketplace_merchants
  WHERE owner_user_id = v_user_id
  ORDER BY created_at
  LIMIT 1;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_not_found');
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'order_id', o.id,
        'status', o.status,
        'total_amount', o.total_amount,
        'currency', o.currency,
        'delivery_mode', o.delivery_mode,
        'shipping_address', o.shipping_address,
        'student_notes', o.student_notes,
        'created_at', o.created_at,
        'student_id', o.student_id,
        'student_full_name', s.full_name,
        'items', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'product_id', i.product_id,
                'quantity', i.quantity,
                'unit_price', i.unit_price,
                'currency', i.currency,
                'product_title', l.title,
                'product_main_image_url', (
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
                )
              )
            ),
            '[]'::jsonb
          )
          FROM app.marketplace_order_items i
          JOIN app.marketplace_listings l ON l.id = i.product_id
          WHERE i.order_id = o.id
        )
      )
      ORDER BY o.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_result
  FROM app.marketplace_orders o
  JOIN app.students s ON s.id = o.student_id
  WHERE o.merchant_id = v_merchant_id;

  RETURN jsonb_build_object('success', true, 'orders', v_result);
END;
$$;
