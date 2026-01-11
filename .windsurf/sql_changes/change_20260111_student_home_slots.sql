-- ============================================================
-- CHANGE 2026-01-11 : Slots d'accueil étudiant pour offres de formation
-- Projet : Academia
-- Objectif : permettre à l'admin d'associer chaque offre (programme,
--            formation courte, cours en ligne, opportunité) à un ou
--            plusieurs emplacements d'affichage sur l'accueil étudiant
--            (mobile / desktop), sans impacter les modules existants.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE GENERIQUE DES SLOTS D'ACCUEIL ETUDIANT
-- ========================================

CREATE TABLE IF NOT EXISTS app.student_home_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain TEXT NOT NULL CHECK (domain IN (
        'program',                -- app.programs
        'short_training_session', -- app.short_training_sessions
        'online_course',          -- app.online_courses
        'opportunity'             -- app.opportunities (stages / services)
    )),
    object_id UUID NOT NULL,
    slot TEXT NOT NULL,              -- ex: 'mobile_row_short_trainings', 'mobile_row_online_courses', 'desktop_short_trainings', etc.
    sort_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.student_home_slots ENABLE ROW LEVEL SECURITY;

-- Accès lecture/écriture complet pour service_role
GRANT ALL ON app.student_home_slots TO service_role;

-- Lecture limitée pour authenticated (via RPC admin uniquement)
GRANT SELECT ON app.student_home_slots TO authenticated;

CREATE INDEX IF NOT EXISTS idx_student_home_slots_slot
ON app.student_home_slots (slot, sort_order NULLS LAST, created_at);

-- ========================================
-- 2) RPC ADMIN - LISTE DES SLOTS D'ACCUEIL
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_student_home_slots()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', s.id,
                'domain', s.domain,
                'object_id', s.object_id,
                'slot', s.slot,
                'sort_order', s.sort_order,
                'is_active', s.is_active,
                'created_at', s.created_at,
                'updated_at', s.updated_at
            )
            ORDER BY s.slot, s.sort_order NULLS LAST, s.created_at
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.student_home_slots s;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'slots', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_student_home_slots() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_student_home_slots() TO service_role;

-- ========================================
-- 3) RPC ADMIN - UPSERT D'UN SLOT D'ACCUEIL
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_student_home_slot(
    p_slot_id UUID,
    p_domain TEXT,
    p_object_id UUID,
    p_slot TEXT,
    p_sort_order INTEGER,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_object_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_domain IS NULL OR p_object_id IS NULL OR p_slot IS NULL OR LENGTH(TRIM(p_slot)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_input');
    END IF;

    IF p_domain NOT IN ('program', 'short_training_session', 'online_course', 'opportunity') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_domain');
    END IF;

    -- Vérifier l'existence de l'objet cible selon le domaine
    SELECT CASE
        WHEN p_domain = 'program' THEN EXISTS (
            SELECT 1 FROM app.programs p WHERE p.id = p_object_id
        )
        WHEN p_domain = 'short_training_session' THEN EXISTS (
            SELECT 1 FROM app.short_training_sessions sts WHERE sts.id = p_object_id
        )
        WHEN p_domain = 'online_course' THEN EXISTS (
            SELECT 1 FROM app.online_courses c WHERE c.id = p_object_id
        )
        WHEN p_domain = 'opportunity' THEN EXISTS (
            SELECT 1 FROM app.opportunities o WHERE o.id = p_object_id
        )
        ELSE FALSE
    END INTO v_object_exists;

    IF NOT v_object_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'object_not_found');
    END IF;

    IF p_slot_id IS NULL THEN
        INSERT INTO app.student_home_slots (domain, object_id, slot, sort_order, is_active)
        VALUES (p_domain, p_object_id, p_slot, p_sort_order, COALESCE(p_is_active, TRUE))
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.student_home_slots
        SET
            domain = p_domain,
            object_id = p_object_id,
            slot = p_slot,
            sort_order = p_sort_order,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_slot_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slot_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'slot_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_student_home_slot(UUID, TEXT, UUID, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_student_home_slot(UUID, TEXT, UUID, TEXT, INTEGER, BOOLEAN) TO service_role;

-- ========================================
-- 4) RPC ADMIN - SUPPRESSION D'UN SLOT D'ACCUEIL
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_delete_student_home_slot(
    p_slot_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    DELETE FROM app.student_home_slots
    WHERE id = p_slot_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slot_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'slot_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_student_home_slot(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_student_home_slot(UUID) TO service_role;

-- ========================================
-- 5) RPC PUBLIC - LECTURE DES OFFRES PAR SLOT POUR L'APP ETUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_list_student_home_slot_items(
    p_slot TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_items JSONB;
BEGIN
    IF p_slot IS NULL OR LENGTH(TRIM(p_slot)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'items', '[]'::JSONB);
    END IF;

    SELECT COALESCE(
        JSONB_AGG(item ORDER BY item->>'domain', (item->>'sort_order')::INT NULLS LAST),
        '[]'::JSONB
    )
    INTO v_items
    FROM (
        SELECT JSONB_BUILD_OBJECT(
            'slot_id', s.id,
            'domain', s.domain,
            'object_id', s.object_id,
            'slot', s.slot,
            'sort_order', s.sort_order,
            'is_active', s.is_active,
            'program', CASE WHEN s.domain = 'program' THEN JSONB_BUILD_OBJECT(
                'id', p.id,
                'title', p.title,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'university_name', u.name,
                'university_logo_url', u.logo_url
            ) ELSE NULL END,
            'short_training_session', CASE WHEN s.domain = 'short_training_session' THEN JSONB_BUILD_OBJECT(
                'id', sts.id,
                'title', sts.title,
                'category', sts.category,
                'modality', sts.modality,
                'location', sts.location,
                'start_at', sts.start_at,
                'price', sts.price
            ) ELSE NULL END,
            'online_course', CASE WHEN s.domain = 'online_course' THEN JSONB_BUILD_OBJECT(
                'id', c.id,
                'title', c.title,
                'short_description', c.short_description,
                'category', c.category,
                'level', c.level,
                'price', c.price
            ) ELSE NULL END,
            'opportunity', CASE WHEN s.domain = 'opportunity' THEN JSONB_BUILD_OBJECT(
                'id', o.id,
                'title', o.title,
                'type', o.type,
                'location', o.location,
                'starts_at', o.starts_at
            ) ELSE NULL END
        ) AS item
        FROM app.student_home_slots s
        LEFT JOIN app.programs p ON s.domain = 'program' AND p.id = s.object_id AND p.is_active = TRUE
        LEFT JOIN app.universities u ON s.domain = 'program' AND u.id = p.university_id AND u.is_active = TRUE
        LEFT JOIN app.short_training_sessions sts ON s.domain = 'short_training_session' AND sts.id = s.object_id
        LEFT JOIN app.online_courses c ON s.domain = 'online_course' AND c.id = s.object_id
        LEFT JOIN app.opportunities o ON s.domain = 'opportunity' AND o.id = s.object_id
        WHERE s.slot = p_slot
          AND s.is_active = TRUE
    ) AS t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'items', v_items);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_student_home_slot_items(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_list_student_home_slot_items(TEXT) TO service_role;
