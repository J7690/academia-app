-- ============================================================
-- PHASE 2 : Favoris (bookmarks) pour le module Opportunités
-- Date : 2026-01-12
-- ============================================================
-- CONTENU :
-- 1. Nouvelle table app.opportunity_bookmarks
-- 2. Policies RLS pour les favoris
-- 3. RPC public.app_opportunity_toggle_bookmark
-- 4. RPC public.app_student_list_bookmarked_opportunities
--    (même format que app_student_list_opportunities, mais filtré sur les favoris)
-- ============================================================

-- ============================================================
-- 1. NOUVELLE TABLE OPPORTUNITY_BOOKMARKS
-- ============================================================

CREATE TABLE IF NOT EXISTS app.opportunity_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id UUID NOT NULL REFERENCES app.opportunities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(opportunity_id, user_id)
);

ALTER TABLE app.opportunity_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_manage_own_opportunity_bookmarks ON app.opportunity_bookmarks;
CREATE POLICY user_manage_own_opportunity_bookmarks
ON app.opportunity_bookmarks
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 3. RPC TOGGLE BOOKMARK
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_opportunity_toggle_bookmark(
    p_opportunity_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Vérifier que l'opportunité est toujours valable
    IF NOT EXISTS (
        SELECT 1
        FROM app.opportunities o
        WHERE o.id = p_opportunity_id
          AND o.is_active = TRUE
          AND o.status = 'published'
          AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_found');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.opportunity_bookmarks b
        WHERE b.opportunity_id = p_opportunity_id
          AND b.user_id = v_user_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM app.opportunity_bookmarks
        WHERE opportunity_id = p_opportunity_id
          AND user_id = v_user_id;

        RETURN JSONB_BUILD_OBJECT(
            'success', TRUE,
            'action', 'removed',
            'is_bookmarked', FALSE
        );
    ELSE
        INSERT INTO app.opportunity_bookmarks (opportunity_id, user_id)
        VALUES (p_opportunity_id, v_user_id);

        RETURN JSONB_BUILD_OBJECT(
            'success', TRUE,
            'action', 'added',
            'is_bookmarked', TRUE
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_opportunity_toggle_bookmark(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_opportunity_toggle_bookmark(UUID) TO service_role;

-- ============================================================
-- 4. RPC LISTING DES OPPORTUNITÉS FAVORITES (ÉTUDIANT)
-- ============================================================

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

    -- Compter le total des opportunités favorites correspondant aux filtres
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

    -- Récupérer les opportunités favorites avec les mêmes champs que app_student_list_opportunities
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
                'is_bookmarked', TRUE
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

GRANT EXECUTE ON FUNCTION public.app_student_list_bookmarked_opportunities(TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_list_bookmarked_opportunities(TEXT, TEXT, INTEGER, INTEGER) TO service_role;
