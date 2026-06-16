-- ============================================================
-- PHASE 6 : Notifications et badges - Module Opportunités
-- Date : 2025-01-04
-- ============================================================
-- CONTENU :
-- 1. Table pour tracker les opportunités vues par l'utilisateur
-- 2. RPC pour compter les nouvelles opportunités (badge)
-- 3. RPC pour marquer les opportunités comme vues
-- ============================================================

-- ============================================================
-- 1. TABLE OPPORTUNITY_VIEWS (tracker ce que l'utilisateur a vu)
-- ============================================================

CREATE TABLE IF NOT EXISTS app.opportunity_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    last_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_opportunity_views_user 
ON app.opportunity_views(user_id);

-- RLS
ALTER TABLE app.opportunity_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_manage_own_views ON app.opportunity_views;
CREATE POLICY user_manage_own_views ON app.opportunity_views
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 2. RPC COMPTER LES NOUVELLES OPPORTUNITÉS
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_opportunity_count_new()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_last_viewed TIMESTAMPTZ;
    v_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'count', 0);
    END IF;

    -- Récupérer la dernière date de consultation
    SELECT last_viewed_at INTO v_last_viewed
    FROM app.opportunity_views
    WHERE user_id = v_user_id;

    -- Si jamais consulté, compter toutes les opportunités des 7 derniers jours
    IF v_last_viewed IS NULL THEN
        v_last_viewed := NOW() - INTERVAL '7 days';
    END IF;

    -- Compter les nouvelles opportunités publiées depuis
    SELECT COUNT(*) INTO v_count
    FROM app.opportunities
    WHERE is_active = TRUE
      AND status = 'published'
      AND created_at > v_last_viewed
      AND (application_deadline IS NULL OR application_deadline >= CURRENT_DATE);

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'count', COALESCE(v_count, 0),
        'last_viewed_at', v_last_viewed
    );
END;
$$;

-- ============================================================
-- 3. RPC MARQUER COMME VU
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_opportunity_mark_viewed()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Upsert la date de dernière consultation
    INSERT INTO app.opportunity_views (user_id, last_viewed_at)
    VALUES (v_user_id, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET last_viewed_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;
