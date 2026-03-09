-- Fix: student marketplace list RPC (GROUP BY / aggregate error)
-- Pattern: jsonb_agg + ORDER BY/LIMIT/OFFSET must aggregate from a subquery.

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

GRANT EXECUTE ON FUNCTION public.app_student_list_marketplace_listings(TEXT, TEXT, INTEGER, INTEGER, TEXT, BOOLEAN, BOOLEAN, UUID, UUID) TO authenticated;
