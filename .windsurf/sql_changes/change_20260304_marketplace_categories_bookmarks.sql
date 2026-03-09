-- ========================================
-- ACADEMIA - PHASE 2C (Marketplace UX)
-- Add: marketplace categories (2-level) + bookmarks
-- Patch: student marketplace feed to support category filters + is_bookmarked
-- ========================================

-- 1) Categories taxonomy (2 levels via parent_id)
CREATE TABLE IF NOT EXISTS app.marketplace_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NULL REFERENCES app.marketplace_categories(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  label TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS marketplace_categories_code_uq
  ON app.marketplace_categories (LOWER(code));

CREATE INDEX IF NOT EXISTS marketplace_categories_parent_idx
  ON app.marketplace_categories (parent_id);

ALTER TABLE app.marketplace_categories ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename = 'marketplace_categories'
      AND policyname = 'public_select_active_marketplace_categories'
  ) THEN
    CREATE POLICY public_select_active_marketplace_categories
      ON app.marketplace_categories
      FOR SELECT
      TO public
      USING (is_active = true);
  END IF;
END$$;

-- 2) Add category links on listings (keep existing text columns for backward compatibility)
ALTER TABLE app.marketplace_listings
  ADD COLUMN IF NOT EXISTS category_id UUID NULL REFERENCES app.marketplace_categories(id),
  ADD COLUMN IF NOT EXISTS sub_category_id UUID NULL REFERENCES app.marketplace_categories(id);

CREATE INDEX IF NOT EXISTS marketplace_listings_category_id_idx
  ON app.marketplace_listings (category_id);

CREATE INDEX IF NOT EXISTS marketplace_listings_sub_category_id_idx
  ON app.marketplace_listings (sub_category_id);

-- 3) Bookmarks for marketplace listings
CREATE TABLE IF NOT EXISTS app.marketplace_listing_bookmarks (
  user_id UUID NOT NULL,
  listing_id UUID NOT NULL REFERENCES app.marketplace_listings(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

CREATE INDEX IF NOT EXISTS marketplace_listing_bookmarks_listing_idx
  ON app.marketplace_listing_bookmarks (listing_id);

ALTER TABLE app.marketplace_listing_bookmarks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename = 'marketplace_listing_bookmarks'
      AND policyname = 'user_manage_own_marketplace_listing_bookmarks'
  ) THEN
    CREATE POLICY user_manage_own_marketplace_listing_bookmarks
      ON app.marketplace_listing_bookmarks
      FOR ALL
      TO public
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END$$;

-- 4) RPC: list marketplace categories tree-ish (flat list, client builds tree)
CREATE OR REPLACE FUNCTION public.app_list_marketplace_categories(
  p_parent_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'parent_id', c.parent_id,
            'code', c.code,
            'label', c.label,
            'sort_order', c.sort_order
          )
          ORDER BY c.sort_order ASC, c.label ASC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_categories c
      WHERE c.is_active = true
        AND (p_parent_id IS NULL AND c.parent_id IS NULL OR c.parent_id = p_parent_id)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_list_marketplace_categories(UUID) TO anon, authenticated;

-- 5) RPC: toggle bookmark (student)
CREATE OR REPLACE FUNCTION public.app_marketplace_listing_toggle_bookmark(
  p_listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_exists BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_listing_id');
  END IF;

  SELECT EXISTS(
    SELECT 1
    FROM app.marketplace_listing_bookmarks b
    WHERE b.user_id = v_user_id
      AND b.listing_id = p_listing_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM app.marketplace_listing_bookmarks
    WHERE user_id = v_user_id
      AND listing_id = p_listing_id;

    RETURN jsonb_build_object('success', true, 'bookmarked', false);
  ELSE
    INSERT INTO app.marketplace_listing_bookmarks(user_id, listing_id)
    VALUES (v_user_id, p_listing_id)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object('success', true, 'bookmarked', true);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_marketplace_listing_toggle_bookmark(UUID) TO authenticated;

-- 6) Patch RPC: student feed with category filters + is_bookmarked
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
  v_user_id UUID := auth.uid();
  v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
  v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
  v_sort TEXT := COALESCE(NULLIF(TRIM(COALESCE(p_sort, '')), ''), 'newest');
  v_total INTEGER;
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
        jsonb_agg(
          jsonb_build_object(
            'id', l.id,
            'merchant_id', l.merchant_id,
            'title', l.title,
            'short_description', l.short_description,
            'description', l.description,
            'type', l.type,
            'category', l.category,
            'category_id', l.category_id,
            'sub_category_id', l.sub_category_id,
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
            'status', l.status,
            'review_status', l.review_status,
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
            'is_bookmarked', EXISTS(
              SELECT 1
              FROM app.marketplace_listing_bookmarks b
              WHERE b.user_id = v_user_id
                AND b.listing_id = l.id
            )
          )
          ORDER BY
            CASE WHEN v_sort = 'newest' THEN l.created_at END DESC,
            CASE WHEN v_sort = 'oldest' THEN l.created_at END ASC,
            CASE WHEN v_sort = 'price_low' THEN l.price_from END ASC NULLS LAST,
            CASE WHEN v_sort = 'price_high' THEN l.price_to END DESC NULLS LAST,
            l.created_at DESC
        ),
        '[]'::jsonb
      )
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
      LIMIT GREATEST(1, LEAST(p_limit, 100))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_marketplace_listings(TEXT, TEXT, INTEGER, INTEGER, TEXT, BOOLEAN, BOOLEAN, UUID, UUID) TO authenticated;

-- 7) RPC: list my bookmarked marketplace listings
CREATE OR REPLACE FUNCTION public.app_student_list_bookmarked_marketplace_listings(
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort TEXT DEFAULT 'newest'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sort TEXT := COALESCE(NULLIF(TRIM(COALESCE(p_sort, '')), ''), 'newest');
  v_total INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_listing_bookmarks b
  JOIN app.marketplace_listings l ON l.id = b.listing_id
  WHERE b.user_id = v_user_id
    AND l.is_active = TRUE
    AND l.status = 'published'
    AND l.review_status = 'approved';

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
            'category_id', l.category_id,
            'sub_category_id', l.sub_category_id,
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
            'status', l.status,
            'review_status', l.review_status,
            'reactions_count', l.reactions_count,
            'comments_count', l.comments_count,
            'created_at', l.created_at,
            'updated_at', l.updated_at,
            'is_bookmarked', true
          )
          ORDER BY
            CASE WHEN v_sort = 'newest' THEN l.created_at END DESC,
            CASE WHEN v_sort = 'oldest' THEN l.created_at END ASC,
            CASE WHEN v_sort = 'price_low' THEN l.price_from END ASC NULLS LAST,
            CASE WHEN v_sort = 'price_high' THEN l.price_to END DESC NULLS LAST,
            l.created_at DESC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_listing_bookmarks b
      JOIN app.marketplace_listings l ON l.id = b.listing_id
      WHERE b.user_id = v_user_id
        AND l.is_active = TRUE
        AND l.status = 'published'
        AND l.review_status = 'approved'
      LIMIT GREATEST(1, LEAST(p_limit, 100))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_bookmarked_marketplace_listings(INTEGER, INTEGER, TEXT) TO authenticated;
