-- Marketplace listing media (images) + storage bucket/policies + RPCs

-- Base URL (used to build public storage URLs)
-- NOTE: keep in sync with Supabase project URL.
-- If you change project, update this constant.
-- Current: https://thevdfcwlcqzdoybfvgs.supabase.co

-- Storage strategy:
-- We reuse the existing bucket 'landing-media' because this project already has
-- working public read + authenticated write policies on storage.objects.

-- 1) DB table
CREATE TABLE IF NOT EXISTS app.marketplace_listing_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES app.marketplace_listings(id) ON DELETE CASCADE,
  media_type text NOT NULL DEFAULT 'image',
  title text,
  description text,
  storage_bucket text NOT NULL DEFAULT 'landing-media',
  storage_path text,
  external_url text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS marketplace_listing_media_listing_id_idx
  ON app.marketplace_listing_media(listing_id);

CREATE INDEX IF NOT EXISTS marketplace_listing_media_active_sort_idx
  ON app.marketplace_listing_media(listing_id, is_active, sort_order);

ALTER TABLE app.marketplace_listing_media ENABLE ROW LEVEL SECURITY;

-- 3) RLS policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='app'
      AND tablename='marketplace_listing_media'
      AND policyname='public_select_marketplace_listing_media'
  ) THEN
    CREATE POLICY public_select_marketplace_listing_media
      ON app.marketplace_listing_media
      FOR SELECT
      TO anon, authenticated
      USING (
        is_active = true
        AND EXISTS (
          SELECT 1
          FROM app.marketplace_listings l
          WHERE l.id = marketplace_listing_media.listing_id
            AND l.is_active = true
            AND l.review_status = 'approved'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='app'
      AND tablename='marketplace_listing_media'
      AND policyname='merchant_manage_own_marketplace_listing_media'
  ) THEN
    CREATE POLICY merchant_manage_own_marketplace_listing_media
      ON app.marketplace_listing_media
      FOR ALL
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM app.marketplace_listings l
          WHERE l.id = marketplace_listing_media.listing_id
            AND l.merchant_id = auth.uid()
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM app.marketplace_listings l
          WHERE l.id = marketplace_listing_media.listing_id
            AND l.merchant_id = auth.uid()
        )
      );
  END IF;
END $$;

-- 5) RPCs
CREATE OR REPLACE FUNCTION public.app_merchant_add_marketplace_listing_media(
  p_listing_id uuid,
  p_storage_path text,
  p_sort_order integer DEFAULT 0,
  p_media_type text DEFAULT 'image',
  p_external_url text DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_media_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_listing_id');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM app.marketplace_listings l
    WHERE l.id = p_listing_id
      AND l.merchant_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  INSERT INTO app.marketplace_listing_media(
    listing_id,
    media_type,
    title,
    description,
    storage_bucket,
    storage_path,
    external_url,
    sort_order,
    is_active,
    updated_at
  ) VALUES (
    p_listing_id,
    COALESCE(NULLIF(trim(p_media_type), ''), 'image'),
    p_title,
    p_description,
    'landing-media',
    NULLIF(trim(p_storage_path), ''),
    NULLIF(trim(p_external_url), ''),
    COALESCE(p_sort_order, 0),
    true,
    now()
  )
  RETURNING id INTO v_media_id;

  RETURN jsonb_build_object(
    'success', true,
    'media_id', v_media_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_add_marketplace_listing_media(uuid, text, integer, text, text, text, text) TO authenticated;

-- 6) Patch student list/detail RPCs to include cover_url + media
CREATE OR REPLACE FUNCTION public.app_student_list_marketplace_listings(
  p_type TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort TEXT DEFAULT 'newest',
  p_verified_only BOOLEAN DEFAULT FALSE,
  p_ready_to_ship_only BOOLEAN DEFAULT FALSE,
  p_category_id UUID DEFAULT NULL,
  p_sub_category_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_total integer;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_listings l
  WHERE l.is_active = TRUE
    AND l.review_status = 'approved'
    AND (p_type IS NULL OR l.type = p_type)
    AND (
      p_search IS NULL
      OR l.title ILIKE '%' || p_search || '%'
      OR l.short_description ILIKE '%' || p_search || '%'
      OR l.description ILIKE '%' || p_search || '%'
    )
    AND (p_ready_to_ship_only IS DISTINCT FROM TRUE OR l.is_ready_to_ship = TRUE)
    AND (p_category_id IS NULL OR l.category_id = p_category_id)
    AND (p_sub_category_id IS NULL OR l.sub_category_id = p_sub_category_id)
    AND (
      p_verified_only IS DISTINCT FROM TRUE
      OR EXISTS (
        SELECT 1
        FROM app.merchant_profiles mp
        WHERE mp.user_id = l.merchant_id
          AND mp.is_active = TRUE
          AND mp.is_verified = TRUE
      )
    );

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', l.id,
            'merchant_id', l.merchant_id,
            'title', l.title,
            'short_description', l.short_description,
            'description', l.description,
            'type', l.type,
            'category', l.category,
            'organization_name', l.organization_name,
            'organization_logo_url', l.organization_logo_url,
            'country', l.country,
            'city', l.city,
            'price_from', l.price_from,
            'price_to', l.price_to,
            'currency', l.currency,
            'min_order_qty', l.min_order_qty,
            'lead_time_days', l.lead_time_days,
            'is_ready_to_ship', l.is_ready_to_ship,
            'reactions_count', l.reactions_count,
            'comments_count', l.comments_count,
            'created_at', l.created_at,
            'updated_at', l.updated_at,
            'merchant_is_verified', EXISTS (
              SELECT 1
              FROM app.merchant_profiles mp
              WHERE mp.user_id = l.merchant_id
                AND mp.is_active = TRUE
                AND mp.is_verified = TRUE
            ),
            'is_bookmarked', EXISTS (
              SELECT 1
              FROM app.marketplace_listing_bookmarks b
              WHERE b.user_id = v_user
                AND b.listing_id = l.id
            ),
            'cover_url', (
              SELECT
                COALESCE(
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
          ORDER BY
            CASE WHEN p_sort = 'newest' THEN l.created_at END DESC,
            CASE WHEN p_sort = 'oldest' THEN l.created_at END ASC,
            CASE WHEN p_sort = 'price_low' THEN l.price_from END ASC NULLS LAST,
            CASE WHEN p_sort = 'price_high' THEN l.price_from END DESC NULLS LAST
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_listings l
      WHERE l.is_active = TRUE
        AND l.review_status = 'approved'
        AND (p_type IS NULL OR l.type = p_type)
        AND (
          p_search IS NULL
          OR l.title ILIKE '%' || p_search || '%'
          OR l.short_description ILIKE '%' || p_search || '%'
          OR l.description ILIKE '%' || p_search || '%'
        )
        AND (p_ready_to_ship_only IS DISTINCT FROM TRUE OR l.is_ready_to_ship = TRUE)
        AND (p_category_id IS NULL OR l.category_id = p_category_id)
        AND (p_sub_category_id IS NULL OR l.sub_category_id = p_sub_category_id)
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
      ORDER BY
        CASE WHEN p_sort = 'newest' THEN l.created_at END DESC,
        CASE WHEN p_sort = 'oldest' THEN l.created_at END ASC,
        CASE WHEN p_sort = 'price_low' THEN l.price_from END ASC NULLS LAST,
        CASE WHEN p_sort = 'price_high' THEN l.price_from END DESC NULLS LAST
      LIMIT p_limit
      OFFSET p_offset
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_marketplace_listings(TEXT, TEXT, INTEGER, INTEGER, TEXT, BOOLEAN, BOOLEAN, UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_student_get_marketplace_listing_detail(
  p_listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_listing jsonb;
  v_media jsonb;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_listing_id');
  END IF;

  SELECT to_jsonb(l)
  INTO v_listing
  FROM app.marketplace_listings l
  WHERE l.id = p_listing_id
    AND l.is_active = TRUE
    AND l.review_status = 'approved'
  LIMIT 1;

  IF v_listing IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found');
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', ml.id,
        'media_type', ml.media_type,
        'title', ml.title,
        'description', ml.description,
        'storage_bucket', ml.storage_bucket,
        'storage_path', ml.storage_path,
        'external_url', ml.external_url,
        'sort_order', ml.sort_order,
        'url', COALESCE(
          NULLIF(ml.external_url, ''),
          CASE
            WHEN ml.storage_path IS NOT NULL AND ml.storage_path <> ''
            THEN (v_base_url || '/storage/v1/object/public/' || ml.storage_bucket || '/' || ml.storage_path)
            ELSE NULL
          END
        )
      )
      ORDER BY ml.sort_order ASC, ml.created_at ASC
    ),
    '[]'::jsonb
  )
  INTO v_media
  FROM app.marketplace_listing_media ml
  WHERE ml.listing_id = p_listing_id
    AND ml.is_active = true;

  RETURN jsonb_build_object(
    'success', true,
    'listing', v_listing,
    'is_bookmarked', EXISTS (
      SELECT 1
      FROM app.marketplace_listing_bookmarks b
      WHERE b.user_id = v_user
        AND b.listing_id = p_listing_id
    ),
    'media', v_media
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_marketplace_listing_detail(UUID) TO authenticated;
