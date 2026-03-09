-- ========================================
-- ACADEMIA - ACCUEIL ÉTUDIANT (VIDÉOS PUB + BANDE ROULANTE)
-- Tables et RPC dédiés, séparés de la landing publique
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE ANNONCES ACCUEIL ÉTUDIANT (BANDE ROULANTE)
-- ========================================

CREATE TABLE IF NOT EXISTS app.student_home_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    text TEXT NOT NULL,
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.student_home_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_student_home_announcements ON app.student_home_announcements;
CREATE POLICY public_select_active_student_home_announcements
ON app.student_home_announcements FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.student_home_announcements TO anon, authenticated;
GRANT ALL ON app.student_home_announcements TO service_role;

-- ========================================
-- 2) TABLE VIDÉOS ACCUEIL ÉTUDIANT (HERO PUBLICITAIRE)
-- ========================================

CREATE TABLE IF NOT EXISTS app.student_home_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_url TEXT NOT NULL,
    title TEXT,
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    media_type TEXT NOT NULL DEFAULT 'video',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.student_home_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_student_home_videos ON app.student_home_videos;
CREATE POLICY public_select_active_student_home_videos
ON app.student_home_videos FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.student_home_videos TO anon, authenticated;
GRANT ALL ON app.student_home_videos TO service_role;

-- ========================================
-- 3) RPC PUBLIC - CONTENU ACCUEIL ÉTUDIANT (LECTURE POUR L'APP)
-- ========================================

CREATE OR REPLACE FUNCTION app_public_student_home_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_announcements JSONB;
    v_videos JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.student_home_announcements a
    WHERE a.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(v) ORDER BY v.sort_order, v.created_at),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.student_home_videos v
    WHERE v.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'announcements', v_announcements,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_student_home_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_student_home_content() TO service_role;

-- ========================================
-- 4) RPC ADMIN - LECTURE COMPLÈTE CONTENU ACCUEIL ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_get_student_home_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_announcements JSONB;
    v_videos JSONB;
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
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.student_home_announcements a;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(v) ORDER BY v.sort_order, v.created_at),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.student_home_videos v;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'announcements', v_announcements,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_student_home_content() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_student_home_content() TO service_role;

-- ========================================
-- 5) RPC ADMIN - GESTION ANNONCES ACCUEIL ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_student_home_announcement(
    p_announcement_id UUID,
    p_text TEXT,
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
    v_video_url_trim TEXT;
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

    IF p_text IS NULL OR LENGTH(TRIM(p_text)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_text');
    END IF;

    IF p_announcement_id IS NULL THEN
        INSERT INTO app.student_home_announcements (text, sort_order, is_active)
        VALUES (p_text, p_sort_order, COALESCE(p_is_active, TRUE))
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.student_home_announcements
        SET
            text = p_text,
            sort_order = p_sort_order,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_announcement_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'announcement_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'announcement_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_student_home_announcement(UUID, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_student_home_announcement(UUID, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_student_home_announcement(
    p_announcement_id UUID
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

    DELETE FROM app.student_home_announcements
    WHERE id = p_announcement_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'announcement_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'announcement_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_student_home_announcement(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_student_home_announcement(UUID) TO service_role;

-- ========================================
-- 6) RPC ADMIN - GESTION VIDÉOS ACCUEIL ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_student_home_video(
    p_video_id UUID,
    p_video_url TEXT,
    p_title TEXT,
    p_sort_order INTEGER,
    p_is_active BOOLEAN,
    p_media_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_video_url_trim TEXT;
    v_media_type_trim TEXT;
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

    v_video_url_trim := TRIM(COALESCE(p_video_url, ''));
    v_media_type_trim := LOWER(TRIM(COALESCE(p_media_type, 'video')));

    IF v_media_type_trim NOT IN ('video', 'image') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
    END IF;

    IF v_video_url_trim = '' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_url');
    END IF;

    IF v_video_url_trim ILIKE '%stream.mux.com%' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'mux_not_allowed');
    END IF;

    IF v_video_url_trim LIKE 'http%' THEN
        IF v_video_url_trim NOT LIKE 'https://thevdfcwlcqzdoybfvgs.supabase.co%' AND
           v_video_url_trim NOT LIKE 'https://academia-app-production.up.railway.app/supabase%' THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_url_not_allowed');
        END IF;
    END IF;

    IF p_video_id IS NULL THEN
        INSERT INTO app.student_home_videos (video_url, title, sort_order, is_active, media_type)
        VALUES (v_video_url_trim, p_title, p_sort_order, COALESCE(p_is_active, TRUE), v_media_type_trim)
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.student_home_videos
        SET
            video_url = v_video_url_trim,
            title = p_title,
            sort_order = p_sort_order,
            is_active = COALESCE(p_is_active, is_active),
            media_type = v_media_type_trim,
            updated_at = NOW()
        WHERE id = p_video_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_student_home_video(UUID, TEXT, TEXT, INTEGER, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_student_home_video(UUID, TEXT, TEXT, INTEGER, BOOLEAN, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_student_home_video(
    p_video_id UUID
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

    DELETE FROM app.student_home_videos
    WHERE id = p_video_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_student_home_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_student_home_video(UUID) TO service_role;
