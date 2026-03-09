-- ========================================
-- ACADEMIA - MODULE UNIVERSITÉS & OFFRES DE FORMATION
-- Tables app.universities, app.programs
-- + RPC métiers pour les listes d'offres côté étudiant
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE UNIVERSITÉS PARTENAIRES
-- ========================================

CREATE TABLE IF NOT EXISTS app.universities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    logo_url TEXT,
    country TEXT,
    city TEXT,
    website_url TEXT,
    description TEXT,
    tagline TEXT,
    banner_image_url TEXT,
    contact_email TEXT,
    contact_phone TEXT,
    address TEXT,
    social_links JSONB,
    mission TEXT,
    vision TEXT,
    key_figures JSONB,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.universities ENABLE ROW LEVEL SECURITY;

-- Lecture publique (pour l'instant) des universités actives
DROP POLICY IF EXISTS public_select_active_universities ON app.universities;
CREATE POLICY public_select_active_universities
ON app.universities FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.universities TO anon, authenticated;
GRANT ALL ON app.universities TO service_role;

-- ========================================
-- 2) TABLE PROGRAMMES / OFFRES DE FORMATION
-- ========================================

CREATE TABLE IF NOT EXISTS app.programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID NOT NULL REFERENCES app.universities (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    degree_level TEXT,          -- licence, master, etc.
    mode TEXT,                  -- online, presentiel, hybride
    duration_months INTEGER,
    tuition_fees NUMERIC,
    structure TEXT,
    career_outcomes TEXT,
    highlighted BOOLEAN DEFAULT FALSE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.programs ENABLE ROW LEVEL SECURITY;

-- Lecture publique (pour l'instant) des programmes actifs
DROP POLICY IF EXISTS public_select_active_programs ON app.programs;
CREATE POLICY public_select_active_programs
ON app.programs FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.programs TO anon, authenticated;
GRANT ALL ON app.programs TO service_role;

ALTER TABLE app.universities
    ADD COLUMN IF NOT EXISTS tagline TEXT,
    ADD COLUMN IF NOT EXISTS banner_image_url TEXT,
    ADD COLUMN IF NOT EXISTS contact_email TEXT,
    ADD COLUMN IF NOT EXISTS contact_phone TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS social_links JSONB,
    ADD COLUMN IF NOT EXISTS mission TEXT,
    ADD COLUMN IF NOT EXISTS vision TEXT,
    ADD COLUMN IF NOT EXISTS key_figures JSONB;

ALTER TABLE app.programs
    ADD COLUMN IF NOT EXISTS structure TEXT,
    ADD COLUMN IF NOT EXISTS career_outcomes TEXT;

-- ========================================
-- 3) RPC - LISTE D'OFFRES POUR LA PAGE D'ACCUEIL ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_list_home_offers()
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
                'program_id', p.id,
                'program_title', p.title,
                'program_description', p.description,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'highlighted', p.highlighted,
                'university_id', u.id,
                'university_slug', u.slug,
                'university_name', u.name,
                'university_logo_url', u.logo_url,
                'country', u.country,
                'city', u.city
            )
            ORDER BY p.highlighted DESC, p.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.programs p
    JOIN app.universities u ON u.id = p.university_id
    WHERE p.is_active = TRUE
      AND u.is_active = TRUE;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_home_offers TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_list_home_offers TO service_role;

-- ========================================
-- 4) RPC - LISTE DES UNIVERSITÉS PARTENAIRES
-- ========================================

CREATE OR REPLACE FUNCTION app_list_partner_universities()
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
                'id', u.id,
                'name', u.name,
                'slug', u.slug,
                'logo_url', u.logo_url,
                'country', u.country,
                'city', u.city,
                'website_url', u.website_url,
                'description', u.description
            )
            ORDER BY u.name ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.universities u
    WHERE u.is_active = TRUE;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_partner_universities TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_list_partner_universities TO service_role;

-- ========================================
-- 5) RPC - LISTE DES PROGRAMMES PAR UNIVERSITÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_list_programs_by_university(
    p_university_id UUID
)
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
                'program_id', p.id,
                'title', p.title,
                'description', p.description,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'highlighted', p.highlighted
            )
            ORDER BY p.highlighted DESC, p.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.programs p
    WHERE p.university_id = p_university_id
      AND p.is_active = TRUE;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_programs_by_university(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_list_programs_by_university(UUID) TO service_role;

-- ========================================
-- 6) RPC - FONCTIONS DE GESTION DES PROGRAMMES POUR LES UNIVERSITÉS ET LES ADMINISTRATEURS
-- ========================================

CREATE OR REPLACE FUNCTION app_list_university_programs_for_management()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
                'university_id', p.university_id,
                'title', p.title,
                'description', p.description,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'highlighted', p.highlighted,
                'is_active', p.is_active,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            )
            ORDER BY p.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.programs p
    WHERE p.university_id = v_university_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'programs', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_university_programs_for_management() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_university_programs_for_management() TO service_role;

CREATE OR REPLACE FUNCTION app_upsert_university_program(
    p_program_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_degree_level TEXT,
    p_mode TEXT,
    p_duration_months INTEGER,
    p_tuition_fees NUMERIC,
    p_highlighted BOOLEAN,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_program_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_program_id IS NULL THEN
        INSERT INTO app.programs (
            university_id,
            title,
            description,
            degree_level,
            mode,
            duration_months,
            tuition_fees,
            highlighted,
            is_active
        )
        VALUES (
            v_university_id,
            p_title,
            p_description,
            p_degree_level,
            p_mode,
            p_duration_months,
            p_tuition_fees,
            COALESCE(p_highlighted, FALSE),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_program_id;
    ELSE
        UPDATE app.programs
        SET
            title = p_title,
            description = p_description,
            degree_level = p_degree_level,
            mode = p_mode,
            duration_months = p_duration_months,
            tuition_fees = p_tuition_fees,
            highlighted = COALESCE(p_highlighted, highlighted),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_program_id
          AND university_id = v_university_id
        RETURNING id INTO v_program_id;
    END IF;

    IF v_program_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'program_id', v_program_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_upsert_university_program(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_upsert_university_program(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, BOOLEAN, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_all_programs()
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
                'id', p.id,
                'university_id', u.id,
                'university_name', u.name,
                'university_slug', u.slug,
                'university_website_url', u.website_url,
                'title', p.title,
                'description', p.description,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'highlighted', p.highlighted,
                'is_active', p.is_active,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            )
            ORDER BY u.name ASC, p.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.programs p
    JOIN app.universities u ON u.id = p.university_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'programs', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_all_programs() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_all_programs() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_update_program_status(
    p_program_id UUID,
    p_is_active BOOLEAN,
    p_highlighted BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_program_id UUID;
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

    UPDATE app.programs
    SET
        is_active = COALESCE(p_is_active, is_active),
        highlighted = COALESCE(p_highlighted, highlighted),
        updated_at = NOW()
    WHERE id = p_program_id
    RETURNING id INTO v_program_id;

    IF v_program_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'program_id', v_program_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_program_status(UUID, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_program_status(UUID, BOOLEAN, BOOLEAN) TO service_role;

-- ========================================
-- 6) VALIDATION RAPIDE DU MODULE UNIVERSITÉS/OFFRES
-- ========================================

SELECT
  'offers_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'universities')) AS universities_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'programs')) AS programs_table_exists;

CREATE OR REPLACE FUNCTION app_admin_update_university_status(
    p_university_id UUID,
    p_is_active BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_university_exists BOOLEAN;
    v_target_user_id UUID;
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

    IF p_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_university_id');
    END IF;

    SELECT id
    INTO v_university_id
    FROM app.universities
    WHERE id = p_university_id;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    UPDATE app.universities
    SET is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = v_university_id;

    IF p_is_active IS FALSE THEN
        FOR v_target_user_id IN
            SELECT u.id
            FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'university'
              AND (u.raw_user_meta_data->>'university_id')::UUID = v_university_id
        LOOP
            PERFORM app_admin_update_user_status(
                v_target_user_id,
                'suspend',
                COALESCE(p_reason, 'university_deactivated')
            );
        END LOOP;
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university_id', v_university_id,
        'is_active', p_is_active
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_university_status(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_university_status(UUID, BOOLEAN, TEXT) TO service_role;
