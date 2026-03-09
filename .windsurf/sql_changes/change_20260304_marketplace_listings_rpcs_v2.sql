-- ========================================
-- ACADEMIA - PHASE 2B-2 (Option A: 2 tables)
-- RPC v2 for app.marketplace_listings
-- - Student feed/detail
-- - Merchant CRUD + submit for review
-- - Admin review
-- - Inquiry create v2 (writes opportunity_id for backward compatibility)
-- ========================================

-- 1) Student: list marketplace listings
CREATE OR REPLACE FUNCTION public.app_student_list_marketplace_listings(
  p_type TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort TEXT DEFAULT 'newest',
  p_verified_only BOOLEAN DEFAULT FALSE,
  p_ready_to_ship_only BOOLEAN DEFAULT FALSE
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

GRANT EXECUTE ON FUNCTION public.app_student_list_marketplace_listings(TEXT, TEXT, INTEGER, INTEGER, TEXT, BOOLEAN, BOOLEAN) TO authenticated;

-- 2) Student: get listing detail
CREATE OR REPLACE FUNCTION public.app_student_get_marketplace_listing_detail(
  p_listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_id_required');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'listing', (
      SELECT to_jsonb(l)
      FROM app.marketplace_listings l
      WHERE l.id = p_listing_id
        AND l.is_active = TRUE
        AND l.status = 'published'
        AND l.review_status = 'approved'
      LIMIT 1
    ),
    'merchant_profile', (
      SELECT to_jsonb(mp)
      FROM app.merchant_profiles mp
      JOIN app.marketplace_listings l ON l.merchant_id = mp.user_id
      WHERE l.id = p_listing_id
        AND mp.is_active = TRUE
      LIMIT 1
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_marketplace_listing_detail(UUID) TO authenticated;

-- 3) Merchant: list my listings
CREATE OR REPLACE FUNCTION public.app_merchant_list_my_marketplace_listings(
  p_review_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_review_status TEXT := NULLIF(TRIM(COALESCE(p_review_status, '')), '');
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(
        jsonb_agg(to_jsonb(l) ORDER BY l.updated_at DESC),
        '[]'::jsonb
      )
      FROM app.marketplace_listings l
      WHERE l.merchant_id = v_user_id
        AND (v_review_status IS NULL OR l.review_status = v_review_status)
      LIMIT GREATEST(1, LEAST(p_limit, 200))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_list_my_marketplace_listings(TEXT, INTEGER, INTEGER) TO authenticated;

-- 4) Merchant: upsert listing
CREATE OR REPLACE FUNCTION public.app_merchant_upsert_marketplace_listing(
  p_listing_id UUID,
  p_title TEXT,
  p_short_description TEXT,
  p_description TEXT,
  p_type TEXT,
  p_category TEXT,
  p_organization_name TEXT,
  p_organization_logo_url TEXT,
  p_country TEXT,
  p_city TEXT,
  p_price_from NUMERIC,
  p_price_to NUMERIC,
  p_currency TEXT,
  p_min_order_qty INTEGER,
  p_lead_time_days INTEGER,
  p_is_ready_to_ship BOOLEAN
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
  v_title TEXT := NULLIF(TRIM(COALESCE(p_title, '')), '');
  v_short_desc TEXT := NULLIF(TRIM(COALESCE(p_short_description, '')), '');
  v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
  v_org TEXT := NULLIF(TRIM(COALESCE(p_organization_name, '')), '');
  v_country TEXT := NULLIF(TRIM(COALESCE(p_country, '')), '');
  v_city TEXT := NULLIF(TRIM(COALESCE(p_city, '')), '');
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  IF v_title IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_title');
  END IF;

  IF v_short_desc IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_short_description');
  END IF;

  IF v_type IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_type');
  END IF;

  IF v_org IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_organization_name');
  END IF;

  IF v_country IS NULL OR v_city IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_location');
  END IF;

  IF p_listing_id IS NULL THEN
    v_id := gen_random_uuid();
    INSERT INTO app.marketplace_listings(
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
      status,
      review_status,
      updated_at
    )
    VALUES (
      v_id,
      v_user_id,
      v_title,
      v_short_desc,
      NULLIF(TRIM(COALESCE(p_description, '')), ''),
      v_type,
      NULLIF(TRIM(COALESCE(p_category, '')), ''),
      v_org,
      NULLIF(TRIM(COALESCE(p_organization_logo_url, '')), ''),
      v_country,
      v_city,
      p_price_from,
      p_price_to,
      NULLIF(TRIM(COALESCE(p_currency, '')), ''),
      p_min_order_qty,
      p_lead_time_days,
      COALESCE(p_is_ready_to_ship, FALSE),
      'draft',
      'draft',
      now()
    );
  ELSE
    UPDATE app.marketplace_listings
    SET
      title = v_title,
      short_description = v_short_desc,
      description = NULLIF(TRIM(COALESCE(p_description, '')), ''),
      type = v_type,
      category = NULLIF(TRIM(COALESCE(p_category, '')), ''),
      organization_name = v_org,
      organization_logo_url = NULLIF(TRIM(COALESCE(p_organization_logo_url, '')), ''),
      country = v_country,
      city = v_city,
      price_from = p_price_from,
      price_to = p_price_to,
      currency = NULLIF(TRIM(COALESCE(p_currency, '')), ''),
      min_order_qty = p_min_order_qty,
      lead_time_days = p_lead_time_days,
      is_ready_to_ship = COALESCE(p_is_ready_to_ship, is_ready_to_ship),
      updated_at = now()
    WHERE id = p_listing_id
      AND merchant_id = v_user_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'not_found_or_not_owner');
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'listing_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_upsert_marketplace_listing(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, INTEGER, INTEGER, BOOLEAN) TO authenticated;

-- 5) Merchant: submit for review
CREATE OR REPLACE FUNCTION public.app_merchant_submit_marketplace_listing_for_review(
  p_listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  UPDATE app.marketplace_listings
  SET
    review_status = 'pending_review',
    review_reason = NULL,
    submitted_at = now(),
    updated_at = now()
  WHERE id = p_listing_id
    AND merchant_id = v_user_id
    AND review_status IN ('draft', 'rejected')
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found_or_not_submittable');
  END IF;

  RETURN jsonb_build_object('success', true, 'listing_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_submit_marketplace_listing_for_review(UUID) TO authenticated;

-- 6) Admin: list pending listings
CREATE OR REPLACE FUNCTION public.app_admin_list_pending_marketplace_listings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(jsonb_agg(to_jsonb(l) ORDER BY l.submitted_at DESC), '[]'::jsonb)
      FROM app.marketplace_listings l
      WHERE l.review_status = 'pending_review'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_pending_marketplace_listings() TO authenticated;

-- 7) Admin: review listing
CREATE OR REPLACE FUNCTION public.app_admin_review_marketplace_listing(
  p_listing_id UUID,
  p_decision TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_decision NOT IN ('approve', 'reject') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_decision');
  END IF;

  IF p_decision = 'approve' THEN
    UPDATE app.marketplace_listings
    SET
      review_status = 'approved',
      review_reason = NULL,
      reviewed_at = now(),
      reviewed_by = v_user_id,
      status = 'published',
      is_active = TRUE,
      updated_at = now()
    WHERE id = p_listing_id
      AND review_status = 'pending_review'
    RETURNING id INTO v_id;
  ELSE
    UPDATE app.marketplace_listings
    SET
      review_status = 'rejected',
      review_reason = p_reason,
      reviewed_at = now(),
      reviewed_by = v_user_id,
      status = 'draft',
      updated_at = now()
    WHERE id = p_listing_id
      AND review_status = 'pending_review'
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found_or_not_pending');
  END IF;

  RETURN jsonb_build_object('success', true, 'listing_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_review_marketplace_listing(UUID, TEXT, TEXT) TO authenticated;

-- 8) Student: create inquiry for listing (v2)
CREATE OR REPLACE FUNCTION public.app_student_create_marketplace_listing_inquiry(
  p_listing_id UUID,
  p_message TEXT,
  p_quantity INTEGER DEFAULT NULL,
  p_budget NUMERIC DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_merchant_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_id_required');
  END IF;

  IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_required');
  END IF;

  SELECT merchant_id
  INTO v_merchant_id
  FROM app.marketplace_listings l
  WHERE l.id = p_listing_id
    AND l.is_active = TRUE
    AND l.status = 'published'
    AND l.review_status = 'approved'
  LIMIT 1;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_not_found');
  END IF;

  INSERT INTO app.opportunity_inquiries(
    opportunity_id,
    listing_id,
    buyer_id,
    merchant_id,
    message,
    quantity,
    budget,
    status,
    created_at,
    last_message_at
  )
  VALUES (
    p_listing_id,  -- backward compat (still points to the same UUID)
    p_listing_id,
    v_user_id,
    v_merchant_id,
    trim(p_message),
    p_quantity,
    p_budget,
    'open',
    now(),
    now()
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_create_marketplace_listing_inquiry(UUID, TEXT, INTEGER, NUMERIC) TO authenticated;
