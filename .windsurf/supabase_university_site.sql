-- ========================================
-- ACADEMIA - MODULE MINI-SITE UNIVERSITÉ
-- Tables de contenu et RPC de gestion / consultation
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLES DE CONTENU MINI-SITE
-- ========================================

-- Blocs éditoriaux (présentation, admission, campus, etc.)
CREATE TABLE IF NOT EXISTS app.university_site_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID NOT NULL REFERENCES app.universities (id) ON DELETE CASCADE,
    key TEXT NOT NULL,               -- identifiant logique du bloc (about, admission, campus, etc.)
    title TEXT,
    content TEXT,                    -- texte enrichi (markdown / HTML léger)
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Configuration globale du mini-site (hero, couleurs, affiche principale)
CREATE TABLE IF NOT EXISTS app.university_site_config (
    university_id UUID PRIMARY KEY REFERENCES app.universities (id) ON DELETE CASCADE,
    hero_title TEXT NOT NULL,
    hero_subtitle TEXT,
    hero_primary_color TEXT,
    hero_secondary_color TEXT,
    hero_poster_media_id UUID REFERENCES app.university_media (id),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Bannières et carrousels (bandes roulantes) du mini-site
CREATE TABLE IF NOT EXISTS app.university_site_banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID NOT NULL REFERENCES app.universities (id) ON DELETE CASCADE,
    position TEXT NOT NULL,            -- top_carousel, middle_strip, bottom_strip
    title TEXT NOT NULL,
    subtitle TEXT,
    media_id UUID REFERENCES app.university_media (id),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Médias (vidéos, images, brochures) liés au mini-site
CREATE TABLE IF NOT EXISTS app.university_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID NOT NULL REFERENCES app.universities (id) ON DELETE CASCADE,
    media_type TEXT NOT NULL,        -- video, image, brochure, ...
    title TEXT,
    description TEXT,
    url TEXT,                        -- URL publique (YouTube, site externe...)
    storage_path TEXT,               -- chemin Supabase Storage éventuel
    thumbnail_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index simples
CREATE INDEX IF NOT EXISTS university_site_blocks_university_id_idx
    ON app.university_site_blocks (university_id);

CREATE INDEX IF NOT EXISTS university_media_university_id_idx
    ON app.university_media (university_id);

CREATE INDEX IF NOT EXISTS university_site_config_university_id_idx
    ON app.university_site_config (university_id);

CREATE INDEX IF NOT EXISTS university_site_banners_university_id_idx
    ON app.university_site_banners (university_id);

-- ========================================
-- 2) RLS & DROITS
-- ========================================

ALTER TABLE app.university_site_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.university_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.university_site_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.university_site_banners ENABLE ROW LEVEL SECURITY;

-- Lecture publique (uniquement contenus actifs)
DROP POLICY IF EXISTS public_select_university_site_blocks ON app.university_site_blocks;
CREATE POLICY public_select_university_site_blocks
ON app.university_site_blocks FOR SELECT
USING (is_active = TRUE);

DROP POLICY IF EXISTS public_select_university_media ON app.university_media;
CREATE POLICY public_select_university_media
ON app.university_media FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.university_site_blocks TO anon, authenticated;
GRANT SELECT ON app.university_media TO anon, authenticated;
GRANT ALL ON app.university_site_blocks TO service_role;
GRANT ALL ON app.university_media TO service_role;

DROP POLICY IF EXISTS public_select_university_site_config ON app.university_site_config;
CREATE POLICY public_select_university_site_config
ON app.university_site_config FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS public_select_university_site_banners ON app.university_site_banners;
CREATE POLICY public_select_university_site_banners
ON app.university_site_banners FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.university_site_config TO anon, authenticated;
GRANT SELECT ON app.university_site_banners TO anon, authenticated;
GRANT ALL ON app.university_site_config TO service_role;
GRANT ALL ON app.university_site_banners TO service_role;

-- ========================================
-- 3) RPC - GESTION MINI-SITE (CÔTÉ UNIVERSITÉ)
-- ========================================

-- Récupère tout le contenu mini-site pour l'université connectée
CREATE OR REPLACE FUNCTION app_list_university_site_for_management()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_university JSONB;
    v_config JSONB;
    v_blocks JSONB;
    v_media JSONB;
    v_banners JSONB;
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

    SELECT TO_JSONB(u)
    INTO v_university
    FROM app.universities u
    WHERE u.id = v_university_id;

    IF v_university IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(m) ORDER BY m.sort_order, m.created_at),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = v_university_id;

    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.university_site_config c
    WHERE c.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(ban) ORDER BY ban.sort_order, ban.created_at),
        '[]'::JSONB
    )
    INTO v_banners
    FROM app.university_site_banners ban
    WHERE ban.university_id = v_university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'config', v_config,
        'blocks', v_blocks,
        'media', v_media,
        'banners', v_banners
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_university_site_for_management() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_university_site_for_management() TO service_role;

-- Création / mise à jour d'un bloc éditorial du mini-site
CREATE OR REPLACE FUNCTION app_upsert_university_site_block(
    p_block_id UUID,
    p_key TEXT,
    p_title TEXT,
    p_content TEXT,
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
    v_university_id UUID;
    v_block_id UUID;
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

    IF p_key IS NULL OR LENGTH(TRIM(p_key)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_key');
    END IF;

    IF p_block_id IS NULL THEN
        INSERT INTO app.university_site_blocks (
            university_id,
            key,
            title,
            content,
            sort_order,
            is_active
        )
        VALUES (
            v_university_id,
            p_key,
            p_title,
            p_content,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_block_id;
    ELSE
        UPDATE app.university_site_blocks
        SET
            key = p_key,
            title = p_title,
            content = p_content,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_block_id
          AND university_id = v_university_id
        RETURNING id INTO v_block_id;
    END IF;

    IF v_block_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'block_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'block_id', v_block_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_upsert_university_site_block(UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_upsert_university_site_block(UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

-- Suppression logique d'un bloc éditorial
CREATE OR REPLACE FUNCTION app_delete_university_site_block(
    p_block_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
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

    UPDATE app.university_site_blocks
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_block_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'block_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'block_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_delete_university_site_block(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_delete_university_site_block(UUID) TO service_role;

-- Gestion des médias du mini-site pour l'université connectée
CREATE OR REPLACE FUNCTION app_upsert_university_media(
    p_media_id UUID,
    p_media_type TEXT,
    p_title TEXT,
    p_description TEXT,
    p_url TEXT,
    p_storage_path TEXT,
    p_thumbnail_url TEXT,
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
    v_university_id UUID;
    v_media_id UUID;
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

    IF p_media_type IS NULL OR LENGTH(TRIM(p_media_type)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
    END IF;

    IF p_media_id IS NULL THEN
        INSERT INTO app.university_media (
            university_id,
            media_type,
            title,
            description,
            url,
            storage_path,
            thumbnail_url,
            sort_order,
            is_active
        )
        VALUES (
            v_university_id,
            p_media_type,
            p_title,
            p_description,
            p_url,
            p_storage_path,
            p_thumbnail_url,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_media_id;
    ELSE
        UPDATE app.university_media
        SET
            media_type = p_media_type,
            title = p_title,
            description = p_description,
            url = p_url,
            storage_path = p_storage_path,
            thumbnail_url = p_thumbnail_url,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_media_id
          AND university_id = v_university_id
        RETURNING id INTO v_media_id;
    END IF;

    IF v_media_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'media_id', v_media_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_upsert_university_media(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_upsert_university_media(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_delete_university_media(
    p_media_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
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

    UPDATE app.university_media
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_media_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'media_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_delete_university_media(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_delete_university_media(UUID) TO service_role;

-- Configuration du mini-site pour l'université connectée
CREATE OR REPLACE FUNCTION app_upsert_university_site_config(
    p_hero_title TEXT,
    p_hero_subtitle TEXT,
    p_hero_primary_color TEXT,
    p_hero_secondary_color TEXT,
    p_hero_poster_media_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
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

    IF p_hero_title IS NULL OR LENGTH(TRIM(p_hero_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'hero_title_required');
    END IF;

    INSERT INTO app.university_site_config (
        university_id,
        hero_title,
        hero_subtitle,
        hero_primary_color,
        hero_secondary_color,
        hero_poster_media_id
    )
    VALUES (
        v_university_id,
        p_hero_title,
        p_hero_subtitle,
        p_hero_primary_color,
        p_hero_secondary_color,
        p_hero_poster_media_id
    )
    ON CONFLICT (university_id) DO UPDATE
    SET hero_title = EXCLUDED.hero_title,
        hero_subtitle = EXCLUDED.hero_subtitle,
        hero_primary_color = EXCLUDED.hero_primary_color,
        hero_secondary_color = EXCLUDED.hero_secondary_color,
        hero_poster_media_id = EXCLUDED.hero_poster_media_id,
        updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_upsert_university_site_config(TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_upsert_university_site_config(TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

-- Gestion des bannières/carrousels pour l'université connectée
CREATE OR REPLACE FUNCTION app_upsert_university_site_banner(
    p_banner_id UUID,
    p_position TEXT,
    p_title TEXT,
    p_subtitle TEXT,
    p_media_id UUID,
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
    v_university_id UUID;
    v_id UUID;
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

    IF p_position IS NULL OR LENGTH(TRIM(p_position)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'position_required');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'title_required');
    END IF;

    IF p_banner_id IS NULL THEN
        INSERT INTO app.university_site_banners (
            university_id,
            position,
            title,
            subtitle,
            media_id,
            sort_order,
            is_active
        )
        VALUES (
            v_university_id,
            p_position,
            p_title,
            p_subtitle,
            p_media_id,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.university_site_banners
        SET position = p_position,
            title = p_title,
            subtitle = p_subtitle,
            media_id = p_media_id,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_banner_id
          AND university_id = v_university_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banner_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'banner_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_upsert_university_site_banner(UUID, TEXT, TEXT, TEXT, UUID, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_upsert_university_site_banner(UUID, TEXT, TEXT, TEXT, UUID, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_delete_university_site_banner(
    p_banner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
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

    UPDATE app.university_site_banners
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_banner_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banner_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'banner_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_delete_university_site_banner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_delete_university_site_banner(UUID) TO service_role;

-- ========================================
-- 4) RPC - MINI-SITE PUBLIC (CÔTÉ ÉTUDIANT)
-- ========================================

-- Retourne le mini-site public d'une université à partir de son slug
CREATE OR REPLACE FUNCTION app_public_university_site(
    p_slug TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_university_id UUID;
    v_university JSONB;
    v_config JSONB;
    v_blocks JSONB;
    v_media JSONB;
    v_programs JSONB;
    v_banners JSONB;
BEGIN
    SELECT u.id
    INTO v_university_id
    FROM app.universities u
    WHERE u.slug = p_slug
      AND u.is_active = TRUE
    LIMIT 1;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT JSONB_BUILD_OBJECT(
        'id', u.id,
        'name', u.name,
        'slug', u.slug,
        'logo_url', u.logo_url,
        'country', u.country,
        'city', u.city,
        'website_url', u.website_url,
        'description', u.description
    )
    INTO v_university
    FROM app.universities u
    WHERE u.id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = v_university_id
      AND b.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(m) ORDER BY m.sort_order, m.created_at),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = v_university_id
      AND m.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
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
            ) ORDER BY p.highlighted DESC, p.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_programs
    FROM app.programs p
    WHERE p.university_id = v_university_id
      AND p.is_active = TRUE;

    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.university_site_config c
    WHERE c.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(ban) ORDER BY ban.sort_order, ban.created_at),
        '[]'::JSONB
    )
    INTO v_banners
    FROM app.university_site_banners ban
    WHERE ban.university_id = v_university_id
      AND ban.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'config', v_config,
        'blocks', v_blocks,
        'media', v_media,
        'programs', v_programs,
        'banners', v_banners
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_university_site(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_university_site(TEXT) TO service_role;

-- ========================================
-- 5) RPC - MINI-SITE (CÔTÉ ADMIN)
-- ========================================

-- Lecture complète du mini-site pour une université donnée (admin uniquement)
CREATE OR REPLACE FUNCTION app_admin_get_university_site(
    p_university_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university JSONB;
    v_blocks JSONB;
    v_media JSONB;
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

    SELECT JSONB_BUILD_OBJECT(
        'id', u.id,
        'name', u.name,
        'slug', u.slug,
        'logo_url', u.logo_url,
        'country', u.country,
        'city', u.city,
        'website_url', u.website_url,
        'description', u.description
    )
    INTO v_university
    FROM app.universities u
    WHERE u.id = p_university_id;

    IF v_university IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = p_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(m) ORDER BY m.sort_order, m.created_at),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = p_university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'blocks', v_blocks,
        'media', v_media
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_university_site(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_university_site(UUID) TO service_role;

-- Création / mise à jour d'un bloc éditorial pour une université donnée (admin)
CREATE OR REPLACE FUNCTION app_admin_upsert_university_site_block(
    p_university_id UUID,
    p_block_id UUID,
    p_key TEXT,
    p_title TEXT,
    p_content TEXT,
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
    v_block_id UUID;
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_required');
    END IF;

    IF p_key IS NULL OR LENGTH(TRIM(p_key)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_key');
    END IF;

    IF p_block_id IS NULL THEN
        INSERT INTO app.university_site_blocks (
            university_id,
            key,
            title,
            content,
            sort_order,
            is_active
        )
        VALUES (
            p_university_id,
            p_key,
            p_title,
            p_content,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_block_id;
    ELSE
        UPDATE app.university_site_blocks
        SET
            key = p_key,
            title = p_title,
            content = p_content,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_block_id
          AND university_id = p_university_id
        RETURNING id INTO v_block_id;
    END IF;

    IF v_block_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'block_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'block_id', v_block_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_university_site_block(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_university_site_block(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

-- Suppression logique d'un bloc éditorial (admin)
CREATE OR REPLACE FUNCTION app_admin_delete_university_site_block(
    p_block_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_site_blocks
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_block_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'block_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'block_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_university_site_block(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_university_site_block(UUID) TO service_role;

-- Gestion des médias du mini-site pour une université donnée (admin)
CREATE OR REPLACE FUNCTION app_admin_upsert_university_media(
    p_university_id UUID,
    p_media_id UUID,
    p_media_type TEXT,
    p_title TEXT,
    p_description TEXT,
    p_url TEXT,
    p_storage_path TEXT,
    p_thumbnail_url TEXT,
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
    v_media_id UUID;
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_required');
    END IF;

    IF p_media_type IS NULL OR LENGTH(TRIM(p_media_type)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
    END IF;

    IF p_media_id IS NULL THEN
        INSERT INTO app.university_media (
            university_id,
            media_type,
            title,
            description,
            url,
            storage_path,
            thumbnail_url,
            sort_order,
            is_active
        )
        VALUES (
            p_university_id,
            p_media_type,
            p_title,
            p_description,
            p_url,
            p_storage_path,
            p_thumbnail_url,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_media_id;
    ELSE
        UPDATE app.university_media
        SET
            media_type = p_media_type,
            title = p_title,
            description = p_description,
            url = p_url,
            storage_path = p_storage_path,
            thumbnail_url = p_thumbnail_url,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_media_id
          AND university_id = p_university_id
        RETURNING id INTO v_media_id;
    END IF;

    IF v_media_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'media_id', v_media_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_university_media(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_university_media(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

-- Suppression logique d'un média (admin)
CREATE OR REPLACE FUNCTION app_admin_delete_university_media(
    p_media_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_media
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_media_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'media_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_university_media(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_university_media(UUID) TO service_role;

-- Configuration du mini-site (côté admin)
CREATE OR REPLACE FUNCTION app_admin_upsert_university_site_config(
    p_university_id UUID,
    p_hero_title TEXT,
    p_hero_subtitle TEXT,
    p_hero_primary_color TEXT,
    p_hero_secondary_color TEXT,
    p_hero_poster_media_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_required');
    END IF;

    IF p_hero_title IS NULL OR LENGTH(TRIM(p_hero_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'hero_title_required');
    END IF;

    INSERT INTO app.university_site_config (
        university_id,
        hero_title,
        hero_subtitle,
        hero_primary_color,
        hero_secondary_color,
        hero_poster_media_id
    )
    VALUES (
        p_university_id,
        p_hero_title,
        p_hero_subtitle,
        p_hero_primary_color,
        p_hero_secondary_color,
        p_hero_poster_media_id
    )
    ON CONFLICT (university_id) DO UPDATE
    SET hero_title = EXCLUDED.hero_title,
        hero_subtitle = EXCLUDED.hero_subtitle,
        hero_primary_color = EXCLUDED.hero_primary_color,
        hero_secondary_color = EXCLUDED.hero_secondary_color,
        hero_poster_media_id = EXCLUDED.hero_poster_media_id,
        updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_university_site_config(UUID, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_university_site_config(UUID, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

-- Bannières/carrousels (côté admin)
CREATE OR REPLACE FUNCTION app_admin_upsert_university_site_banner(
    p_university_id UUID,
    p_banner_id UUID,
    p_position TEXT,
    p_title TEXT,
    p_subtitle TEXT,
    p_media_id UUID,
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_required');
    END IF;

    IF p_position IS NULL OR LENGTH(TRIM(p_position)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'position_required');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'title_required');
    END IF;

    IF p_banner_id IS NULL THEN
        INSERT INTO app.university_site_banners (
            university_id,
            position,
            title,
            subtitle,
            media_id,
            sort_order,
            is_active
        )
        VALUES (
            p_university_id,
            p_position,
            p_title,
            p_subtitle,
            p_media_id,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.university_site_banners
        SET position = p_position,
            title = p_title,
            subtitle = p_subtitle,
            media_id = p_media_id,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_banner_id
          AND university_id = p_university_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banner_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'banner_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_university_site_banner(UUID, UUID, TEXT, TEXT, TEXT, UUID, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_university_site_banner(UUID, UUID, TEXT, TEXT, TEXT, UUID, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_university_site_banner(
    p_banner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_site_banners
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_banner_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banner_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'banner_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_university_site_banner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_university_site_banner(UUID) TO service_role;
