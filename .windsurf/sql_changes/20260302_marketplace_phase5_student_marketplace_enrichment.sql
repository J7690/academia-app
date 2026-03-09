-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 5: STUDENT/BUYER UX - ENRICH FEED RPC
--
-- Objectifs:
-- - Enrichir app_student_list_opportunities + app_student_list_bookmarked_opportunities
--   avec les champs marketplace ajoutés sur app.opportunities (phase 1)
-- - Ajouter un badge "marchand vérifié" via jointure merchant_profiles
-- - Conserver la compatibilité avec le feed existant
-- ========================================

-- 1) Student opportunities feed enriched
CREATE OR REPLACE FUNCTION public.app_student_list_opportunities(
    p_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_user_id UUID := auth.uid();
    v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_total INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM app.opportunities o
    WHERE o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
      AND (v_type IS NULL OR LOWER(o.type) = LOWER(v_type))
      AND (
          v_search IS NULL
          OR o.title ILIKE '%' || v_search || '%'
          OR o.organization_name ILIKE '%' || v_search || '%'
          OR o.city ILIKE '%' || v_search || '%'
          OR o.country ILIKE '%' || v_search || '%'
      );

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', o.id,
                'title', o.title,
                'short_description', o.short_description,
                'description', o.description,
                'type', o.type,
                'category', o.category,
                'organization_name', o.organization_name,
                'organization_logo_url', o.organization_logo_url,
                'country', o.country,
                'city', o.city,
                'is_remote_possible', o.is_remote_possible,
                'contract_type', o.contract_type,
                'duration_months', o.duration_months,
                'start_date', o.start_date,
                'application_deadline', o.application_deadline,
                'price', o.price,
                'status', o.status,
                'is_featured', o.is_featured,
                'reactions_count', o.reactions_count,
                'comments_count', o.comments_count,
                'created_at', o.created_at,
                'updated_at', o.updated_at,
                'my_reaction', (
                    SELECT reaction_type 
                    FROM app.opportunity_reactions r 
                    WHERE r.opportunity_id = o.id AND r.user_id = v_user_id
                ),

                -- Marketplace enrichment
                'merchant_id', o.merchant_id,
                'review_status', o.review_status,
                'submitted_at', o.submitted_at,
                'reviewed_at', o.reviewed_at,
                'review_reason', o.review_reason,
                'price_from', o.price_from,
                'price_to', o.price_to,
                'currency', o.currency,
                'min_order_qty', o.min_order_qty,
                'lead_time_days', o.lead_time_days,
                'is_ready_to_ship', o.is_ready_to_ship,
                'merchant_is_verified', (
                    SELECT (mp.is_verified = TRUE)
                    FROM app.merchant_profiles mp
                    WHERE mp.user_id = o.merchant_id
                    LIMIT 1
                )
            )
            ORDER BY o.is_featured DESC, o.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunities o
    WHERE o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
      AND (v_type IS NULL OR LOWER(o.type) = LOWER(v_type))
      AND (
          v_search IS NULL
          OR o.title ILIKE '%' || v_search || '%'
          OR o.organization_name ILIKE '%' || v_search || '%'
          OR o.city ILIKE '%' || v_search || '%'
          OR o.country ILIKE '%' || v_search || '%'
      )
    LIMIT p_limit OFFSET p_offset;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'opportunities', v_result,
        'total', v_total,
        'has_more', (p_offset + p_limit) < v_total
    );
END;
$$;

-- 2) Student bookmarked opportunities feed enriched
CREATE OR REPLACE FUNCTION public.app_student_list_bookmarked_opportunities(
    p_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_user_id UUID := auth.uid();
    v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_total INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM app.opportunities o
    JOIN app.opportunity_bookmarks b
      ON b.opportunity_id = o.id AND b.user_id = v_user_id
    WHERE o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
      AND (v_type IS NULL OR LOWER(o.type) = LOWER(v_type))
      AND (
          v_search IS NULL
          OR o.title ILIKE '%' || v_search || '%'
          OR o.organization_name ILIKE '%' || v_search || '%'
          OR o.city ILIKE '%' || v_search || '%'
          OR o.country ILIKE '%' || v_search || '%'
      );

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', o.id,
                'title', o.title,
                'short_description', o.short_description,
                'description', o.description,
                'type', o.type,
                'category', o.category,
                'organization_name', o.organization_name,
                'organization_logo_url', o.organization_logo_url,
                'country', o.country,
                'city', o.city,
                'is_remote_possible', o.is_remote_possible,
                'contract_type', o.contract_type,
                'duration_months', o.duration_months,
                'start_date', o.start_date,
                'application_deadline', o.application_deadline,
                'price', o.price,
                'status', o.status,
                'is_featured', o.is_featured,
                'reactions_count', o.reactions_count,
                'comments_count', o.comments_count,
                'created_at', o.created_at,
                'updated_at', o.updated_at,
                'my_reaction', (
                    SELECT reaction_type
                    FROM app.opportunity_reactions r
                    WHERE r.opportunity_id = o.id AND r.user_id = v_user_id
                ),
                'is_bookmarked', TRUE,

                -- Marketplace enrichment
                'merchant_id', o.merchant_id,
                'review_status', o.review_status,
                'submitted_at', o.submitted_at,
                'reviewed_at', o.reviewed_at,
                'review_reason', o.review_reason,
                'price_from', o.price_from,
                'price_to', o.price_to,
                'currency', o.currency,
                'min_order_qty', o.min_order_qty,
                'lead_time_days', o.lead_time_days,
                'is_ready_to_ship', o.is_ready_to_ship,
                'merchant_is_verified', (
                    SELECT (mp.is_verified = TRUE)
                    FROM app.merchant_profiles mp
                    WHERE mp.user_id = o.merchant_id
                    LIMIT 1
                )
            )
            ORDER BY o.is_featured DESC, o.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunities o
    JOIN app.opportunity_bookmarks b
      ON b.opportunity_id = o.id AND b.user_id = v_user_id
    WHERE o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
      AND (v_type IS NULL OR LOWER(o.type) = LOWER(v_type))
      AND (
          v_search IS NULL
          OR o.title ILIKE '%' || v_search || '%'
          OR o.organization_name ILIKE '%' || v_search || '%'
          OR o.city ILIKE '%' || v_search || '%'
          OR o.country ILIKE '%' || v_search || '%'
      )
    LIMIT p_limit OFFSET p_offset;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'opportunities', v_result,
        'total', v_total,
        'has_more', (p_offset + p_limit) < v_total
    );
END;
$$;
