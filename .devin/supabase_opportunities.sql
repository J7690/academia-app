-- ========================================
-- ACADEMIA - MODULE OPPORTUNITÉS (STAGES, EMPLOIS, AUTRES)
-- Tables app.opportunities, app.opportunity_applications
-- + RPC métiers étudiant/admin
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE OPPORTUNITÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.opportunities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    short_description TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL, -- internship, job, other, etc.
    category TEXT,
    organization_name TEXT NOT NULL,
    organization_logo_url TEXT,
    country TEXT NOT NULL,
    city TEXT NOT NULL,
    is_remote_possible BOOLEAN DEFAULT FALSE NOT NULL,
    contract_type TEXT,
    duration_months INTEGER,
    start_date DATE,
    application_deadline DATE,
    status TEXT NOT NULL DEFAULT 'draft', -- draft, published, archived
    is_featured BOOLEAN DEFAULT FALSE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.opportunities ENABLE ROW LEVEL SECURITY;

-- Lecture publique/authentifiée des opportunités publiées et actives
DROP POLICY IF EXISTS public_select_published_opportunities ON app.opportunities;
CREATE POLICY public_select_published_opportunities
ON app.opportunities FOR SELECT
USING (
    is_active = TRUE
    AND status = 'published'
    AND (application_deadline IS NULL OR application_deadline >= CURRENT_DATE)
);

GRANT SELECT ON app.opportunities TO anon, authenticated;
GRANT ALL ON app.opportunities TO service_role;

-- ========================================
-- 1b) TABLE TYPES D'OPPORTUNITÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.opportunity_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.opportunity_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_opportunity_types ON app.opportunity_types;
CREATE POLICY public_select_active_opportunity_types
ON app.opportunity_types FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.opportunity_types TO anon, authenticated;
GRANT ALL ON app.opportunity_types TO service_role;

-- ========================================
-- 2) TABLE CANDIDATURES AUX OPPORTUNITÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.opportunity_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id UUID NOT NULL REFERENCES app.opportunities (id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    message TEXT,
    cv_url TEXT,
    extra_data JSONB,
    status TEXT NOT NULL DEFAULT 'submitted', -- submitted, in_review, accepted, rejected
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.opportunity_applications ENABLE ROW LEVEL SECURITY;

-- L'étudiant ne voit que ses propres candidatures
DROP POLICY IF EXISTS student_select_own_opportunity_applications ON app.opportunity_applications;
CREATE POLICY student_select_own_opportunity_applications
ON app.opportunity_applications FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_opportunity_applications ON app.opportunity_applications;
CREATE POLICY student_insert_own_opportunity_applications
ON app.opportunity_applications FOR INSERT
WITH CHECK (student_id = auth.uid());

GRANT SELECT, INSERT ON app.opportunity_applications TO authenticated;
GRANT ALL ON app.opportunity_applications TO service_role;

-- ========================================
-- 3) RPC ÉTUDIANT - LISTE D'OPPORTUNITÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_opportunities(
    p_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
BEGIN
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
                'status', o.status,
                'is_featured', o.is_featured,
                'created_at', o.created_at,
                'updated_at', o.updated_at
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
      );

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_opportunities(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_opportunities(TEXT, TEXT) TO service_role;

-- ========================================
-- 4) RPC ÉTUDIANT - DÉTAIL D'UNE OPPORTUNITÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_student_get_opportunity_detail(
    p_opportunity_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
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
               'status', o.status,
               'is_featured', o.is_featured,
               'created_at', o.created_at,
               'updated_at', o.updated_at
           )
    INTO v_result
    FROM app.opportunities o
    WHERE o.id = p_opportunity_id
      AND o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE);

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_get_opportunity_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_get_opportunity_detail(UUID) TO service_role;

-- ========================================
-- 5) RPC ÉTUDIANT - POSTULER À UNE OPPORTUNITÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_student_apply_for_opportunity(
    p_opportunity_id UUID,
    p_message TEXT,
    p_cv_url TEXT,
    p_extra_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_opportunity_exists BOOLEAN;
    v_application_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'student' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.opportunities o
        WHERE o.id = p_opportunity_id
          AND o.is_active = TRUE
          AND o.status = 'published'
          AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
    ) INTO v_opportunity_exists;

    IF NOT v_opportunity_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_available');
    END IF;

    SELECT id
    INTO v_application_id
    FROM app.opportunity_applications a
    WHERE a.opportunity_id = p_opportunity_id
      AND a.student_id = v_user_id
    LIMIT 1;

    IF v_application_id IS NOT NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_applied');
    END IF;

    INSERT INTO app.opportunity_applications (
        opportunity_id,
        student_id,
        message,
        cv_url,
        extra_data,
        status
    )
    VALUES (
        p_opportunity_id,
        v_user_id,
        p_message,
        p_cv_url,
        p_extra_data,
        'submitted'
    )
    RETURNING id INTO v_application_id;

    IF v_application_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'application_id', v_application_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_apply_for_opportunity(UUID, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_apply_for_opportunity(UUID, TEXT, TEXT, JSONB) TO service_role;

-- ========================================
-- 6) RPC ÉTUDIANT - LISTE DE MES CANDIDATURES
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_opportunity_applications()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'application_id', a.id,
                'opportunity_id', o.id,
                'title', o.title,
                'short_description', o.short_description,
                'type', o.type,
                'organization_name', o.organization_name,
                'city', o.city,
                'country', o.country,
                'status', a.status,
                'message', a.message,
                'cv_url', a.cv_url,
                'extra_data', a.extra_data,
                'created_at', a.created_at,
                'updated_at', a.updated_at
            )
            ORDER BY a.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunity_applications a
    JOIN app.opportunities o ON o.id = a.opportunity_id
    WHERE a.student_id = v_user_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_opportunity_applications() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_opportunity_applications() TO service_role;

-- ========================================
-- 7) RPC - TYPES D'OPPORTUNITÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_list_opportunity_types()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', t.id,
                'code', t.code,
                'label', t.label,
                'sort_order', t.sort_order
            )
            ORDER BY t.sort_order, t.label ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunity_types t
    WHERE t.is_active = TRUE;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_opportunity_types() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_list_opportunity_types() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_opportunity_types()
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
                'id', t.id,
                'code', t.code,
                'label', t.label,
                'sort_order', t.sort_order,
                'is_active', t.is_active,
                'created_at', t.created_at,
                'updated_at', t.updated_at
            )
            ORDER BY t.sort_order, t.label ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunity_types t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'types', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_opportunity_types() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_opportunity_types() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_opportunity_type(
    p_type_id UUID,
    p_code TEXT,
    p_label TEXT,
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
    v_type_id UUID;
    v_code TEXT := NULLIF(TRIM(COALESCE(p_code, '')), '');
    v_label TEXT := NULLIF(TRIM(COALESCE(p_label, '')), '');
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

    IF v_code IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_code');
    END IF;

    IF v_label IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_label');
    END IF;

    IF p_type_id IS NULL THEN
        INSERT INTO app.opportunity_types (
            code,
            label,
            sort_order,
            is_active
        )
        VALUES (
            v_code,
            v_label,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_type_id;
    ELSE
        UPDATE app.opportunity_types
        SET
            code = v_code,
            label = v_label,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_type_id
        RETURNING id INTO v_type_id;
    END IF;

    IF v_type_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'type_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'type_id', v_type_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_opportunity_type(UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_opportunity_type(UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

-- ========================================
-- 8) RPC ADMIN - LISTE DES OPPORTUNITÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_opportunities()
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
                'status', o.status,
                'is_featured', o.is_featured,
                'is_active', o.is_active,
                'created_by_user_id', o.created_by_user_id,
                'created_at', o.created_at,
                'updated_at', o.updated_at
            )
            ORDER BY o.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunities o;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'opportunities', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_opportunities() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_opportunities() TO service_role;

-- ========================================
-- 8) RPC ADMIN - CRÉER / METTRE À JOUR UNE OPPORTUNITÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_opportunity(
    p_opportunity_id UUID,
    p_title TEXT,
    p_short_description TEXT,
    p_description TEXT,
    p_type TEXT,
    p_category TEXT,
    p_organization_name TEXT,
    p_organization_logo_url TEXT,
    p_country TEXT,
    p_city TEXT,
    p_is_remote_possible BOOLEAN,
    p_contract_type TEXT,
    p_duration_months INTEGER,
    p_start_date DATE,
    p_application_deadline DATE,
    p_status TEXT,
    p_is_featured BOOLEAN,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_opportunity_id UUID;
    v_title TEXT := NULLIF(TRIM(COALESCE(p_title, '')), '');
    v_short_desc TEXT := NULLIF(TRIM(COALESCE(p_short_description, '')), '');
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_org_name TEXT := NULLIF(TRIM(COALESCE(p_organization_name, '')), '');
    v_country TEXT := NULLIF(TRIM(COALESCE(p_country, '')), '');
    v_city TEXT := NULLIF(TRIM(COALESCE(p_city, '')), '');
    v_status TEXT := COALESCE(NULLIF(TRIM(COALESCE(p_status, '')), ''), 'draft');
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

    IF v_title IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF v_short_desc IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_short_description');
    END IF;

    IF v_type IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_type');
    END IF;

    IF v_org_name IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_organization_name');
    END IF;

    IF v_country IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_country');
    END IF;

    IF v_city IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_city');
    END IF;

    IF p_opportunity_id IS NULL THEN
        INSERT INTO app.opportunities (
            title,
            short_description,
            description,
            type,
            category,
            organization_name,
            organization_logo_url,
            country,
            city,
            is_remote_possible,
            contract_type,
            duration_months,
            start_date,
            application_deadline,
            status,
            is_featured,
            is_active,
            created_by_user_id
        )
        VALUES (
            v_title,
            v_short_desc,
            p_description,
            v_type,
            p_category,
            v_org_name,
            p_organization_logo_url,
            v_country,
            v_city,
            COALESCE(p_is_remote_possible, FALSE),
            p_contract_type,
            p_duration_months,
            p_start_date,
            p_application_deadline,
            v_status,
            COALESCE(p_is_featured, FALSE),
            COALESCE(p_is_active, TRUE),
            v_user_id
        )
        RETURNING id INTO v_opportunity_id;
    ELSE
        UPDATE app.opportunities
        SET
            title = v_title,
            short_description = v_short_desc,
            description = p_description,
            type = v_type,
            category = p_category,
            organization_name = v_org_name,
            organization_logo_url = p_organization_logo_url,
            country = v_country,
            city = v_city,
            is_remote_possible = COALESCE(p_is_remote_possible, is_remote_possible),
            contract_type = p_contract_type,
            duration_months = p_duration_months,
            start_date = p_start_date,
            application_deadline = p_application_deadline,
            status = v_status,
            is_featured = COALESCE(p_is_featured, is_featured),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_opportunity_id
        RETURNING id INTO v_opportunity_id;
    END IF;

    IF v_opportunity_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'opportunity_id', v_opportunity_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_opportunity(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    BOOLEAN,
    TEXT,
    INTEGER,
    DATE,
    DATE,
    TEXT,
    BOOLEAN,
    BOOLEAN
) TO authenticated;

GRANT EXECUTE ON FUNCTION app_admin_upsert_opportunity(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    BOOLEAN,
    TEXT,
    INTEGER,
    DATE,
    DATE,
    TEXT,
    BOOLEAN,
    BOOLEAN
) TO service_role;

-- ========================================
-- 9) RPC ADMIN - MISE À JOUR RAPIDE STATUT/FEATURED/ACTIVE
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_update_opportunity_status(
    p_opportunity_id UUID,
    p_status TEXT,
    p_is_featured BOOLEAN,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_opportunity_id UUID;
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

    UPDATE app.opportunities
    SET
        status = COALESCE(NULLIF(TRIM(COALESCE(p_status, status)), ''), status),
        is_featured = COALESCE(p_is_featured, is_featured),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = p_opportunity_id
    RETURNING id INTO v_opportunity_id;

    IF v_opportunity_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'opportunity_id', v_opportunity_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_opportunity_status(UUID, TEXT, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_opportunity_status(UUID, TEXT, BOOLEAN, BOOLEAN) TO service_role;

-- ========================================
-- 10) RPC ADMIN - LISTE DES CANDIDATURES POUR UNE OPPORTUNITÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_opportunity_applications(
    p_opportunity_id UUID
)
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
                'application_id', a.id,
                'opportunity_id', a.opportunity_id,
                'student_id', a.student_id,
                'status', a.status,
                'message', a.message,
                'cv_url', a.cv_url,
                'extra_data', a.extra_data,
                'created_at', a.created_at,
                'updated_at', a.updated_at
            )
            ORDER BY a.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunity_applications a
    WHERE a.opportunity_id = p_opportunity_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'applications', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_opportunity_applications(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_opportunity_applications(UUID) TO service_role;

-- ========================================
-- 11) VALIDATION RAPIDE DU MODULE OPPORTUNITÉS
-- ========================================

SELECT
  'opportunities_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'opportunities')) AS opportunities_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'opportunity_applications')) AS opportunity_applications_table_exists;
