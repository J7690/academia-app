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
-- 6) VALIDATION RAPIDE DU MODULE UNIVERSITÉS/OFFRES
-- ========================================

SELECT
  'offers_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'universities')) AS universities_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'programs')) AS programs_table_exists;
