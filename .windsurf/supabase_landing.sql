CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.landing_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hero_badge_text TEXT,
    hero_title TEXT,
    hero_subtitle TEXT,
    video_url TEXT,
    primary_color TEXT,
    secondary_color TEXT,
    accent_color TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.landing_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_landing_config ON app.landing_config;
CREATE POLICY public_select_landing_config
ON app.landing_config FOR SELECT
USING (TRUE);

GRANT SELECT ON app.landing_config TO anon, authenticated;
GRANT ALL ON app.landing_config TO service_role;

CREATE TABLE IF NOT EXISTS app.landing_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    text TEXT NOT NULL,
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.landing_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_landing_announcements ON app.landing_announcements;
CREATE POLICY public_select_active_landing_announcements
ON app.landing_announcements FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.landing_announcements TO anon, authenticated;
GRANT ALL ON app.landing_announcements TO service_role;

CREATE TABLE IF NOT EXISTS app.landing_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    logo_url TEXT,
    website_url TEXT,
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.landing_partners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_landing_partners ON app.landing_partners;
CREATE POLICY public_select_active_landing_partners
ON app.landing_partners FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.landing_partners TO anon, authenticated;
GRANT ALL ON app.landing_partners TO service_role;

CREATE TABLE IF NOT EXISTS app.landing_why_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subtitle TEXT,
    icon_key TEXT,
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.landing_why_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_landing_why_cards ON app.landing_why_cards;
CREATE POLICY public_select_active_landing_why_cards
ON app.landing_why_cards FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.landing_why_cards TO anon, authenticated;
GRANT ALL ON app.landing_why_cards TO service_role;

CREATE TABLE IF NOT EXISTS app.landing_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_url TEXT NOT NULL,
    title TEXT,
    sort_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    media_type TEXT NOT NULL DEFAULT 'video',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.landing_videos
    ADD COLUMN IF NOT EXISTS media_type TEXT NOT NULL DEFAULT 'video';

ALTER TABLE app.landing_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_landing_videos ON app.landing_videos;
CREATE POLICY public_select_active_landing_videos
ON app.landing_videos FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.landing_videos TO anon, authenticated;
GRANT ALL ON app.landing_videos TO service_role;

CREATE OR REPLACE FUNCTION app_public_landing_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config JSONB;
    v_announcements JSONB;
    v_partners JSONB;
    v_why_cards JSONB;
    v_videos JSONB;
BEGIN
    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.landing_config c
    ORDER BY c.created_at DESC
    LIMIT 1;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.landing_announcements a
    WHERE a.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(p) ORDER BY p.sort_order, p.created_at),
        '[]'::JSONB
    )
    INTO v_partners
    FROM app.landing_partners p
    WHERE p.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(w) ORDER BY w.sort_order, w.created_at),
        '[]'::JSONB
    )
    INTO v_why_cards
    FROM app.landing_why_cards w
    WHERE w.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(v) ORDER BY v.sort_order, v.created_at),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.landing_videos v
    WHERE v.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'config', v_config,
        'announcements', v_announcements,
        'partners', v_partners,
        'why_cards', v_why_cards,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_landing_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_landing_content() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_get_landing_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_config JSONB;
    v_announcements JSONB;
    v_partners JSONB;
    v_why_cards JSONB;
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

    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.landing_config c
    ORDER BY c.created_at DESC
    LIMIT 1;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.landing_announcements a;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(p) ORDER BY p.sort_order, p.created_at),
        '[]'::JSONB
    )
    INTO v_partners
    FROM app.landing_partners p;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(w) ORDER BY w.sort_order, w.created_at),
        '[]'::JSONB
    )
    INTO v_why_cards
    FROM app.landing_why_cards w;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(v) ORDER BY v.sort_order, v.created_at),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.landing_videos v;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'config', v_config,
        'announcements', v_announcements,
        'partners', v_partners,
        'why_cards', v_why_cards,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_landing_content() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_landing_content() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_landing_config(
    p_config_id UUID,
    p_hero_badge_text TEXT,
    p_hero_title TEXT,
    p_hero_subtitle TEXT,
    p_video_url TEXT,
    p_primary_color TEXT,
    p_secondary_color TEXT,
    p_accent_color TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_config_id UUID;
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

    IF p_config_id IS NULL THEN
        INSERT INTO app.landing_config (
            hero_badge_text,
            hero_title,
            hero_subtitle,
            video_url,
            primary_color,
            secondary_color,
            accent_color
        )
        VALUES (
            p_hero_badge_text,
            p_hero_title,
            p_hero_subtitle,
            p_video_url,
            p_primary_color,
            p_secondary_color,
            p_accent_color
        )
        RETURNING id INTO v_config_id;
    ELSE
        UPDATE app.landing_config
        SET
            hero_badge_text = p_hero_badge_text,
            hero_title = p_hero_title,
            hero_subtitle = p_hero_subtitle,
            video_url = p_video_url,
            primary_color = p_primary_color,
            secondary_color = p_secondary_color,
            accent_color = p_accent_color,
            updated_at = NOW()
        WHERE id = p_config_id
        RETURNING id INTO v_config_id;
    END IF;

    IF v_config_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'config_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'config_id', v_config_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_config(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_config(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_landing_announcement(
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
        INSERT INTO app.landing_announcements (text, sort_order, is_active)
        VALUES (p_text, p_sort_order, COALESCE(p_is_active, TRUE))
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.landing_announcements
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

GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_announcement(UUID, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_announcement(UUID, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_landing_announcement(
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

    DELETE FROM app.landing_announcements
    WHERE id = p_announcement_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'announcement_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'announcement_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_landing_announcement(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_landing_announcement(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_landing_partner(
    p_partner_id UUID,
    p_name TEXT,
    p_logo_url TEXT,
    p_website_url TEXT,
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

    IF p_partner_id IS NULL THEN
        INSERT INTO app.landing_partners (name, logo_url, website_url, sort_order, is_active)
        VALUES (p_name, p_logo_url, p_website_url, p_sort_order, COALESCE(p_is_active, TRUE))
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.landing_partners
        SET
            name = p_name,
            logo_url = p_logo_url,
            website_url = p_website_url,
            sort_order = p_sort_order,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_partner_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'partner_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'partner_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_partner(UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_partner(UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_landing_partner(
    p_partner_id UUID
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

    DELETE FROM app.landing_partners
    WHERE id = p_partner_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'partner_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'partner_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_landing_partner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_landing_partner(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_landing_why_card(
    p_why_id UUID,
    p_title TEXT,
    p_subtitle TEXT,
    p_icon_key TEXT,
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

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_why_id IS NULL THEN
        INSERT INTO app.landing_why_cards (title, subtitle, icon_key, sort_order, is_active)
        VALUES (p_title, p_subtitle, p_icon_key, p_sort_order, COALESCE(p_is_active, TRUE))
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.landing_why_cards
        SET
            title = p_title,
            subtitle = p_subtitle,
            icon_key = p_icon_key,
            sort_order = p_sort_order,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_why_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'why_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'why_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_why_card(UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_why_card(UUID, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_landing_why_card(
    p_why_id UUID
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

    DELETE FROM app.landing_why_cards
    WHERE id = p_why_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'why_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'why_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_landing_why_card(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_landing_why_card(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_landing_video(
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
    v_media_type TEXT;
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

    v_media_type := LOWER(TRIM(COALESCE(p_media_type, 'video')));
    IF v_media_type NOT IN ('video', 'image') THEN
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
        INSERT INTO app.landing_videos (video_url, title, sort_order, is_active, media_type)
        VALUES (v_video_url_trim, p_title, p_sort_order, COALESCE(p_is_active, TRUE), v_media_type)
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.landing_videos
        SET
            video_url = v_video_url_trim,
            title = p_title,
            sort_order = p_sort_order,
            is_active = COALESCE(p_is_active, is_active),
            media_type = v_media_type,
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

GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_video(UUID, TEXT, TEXT, INTEGER, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_landing_video(UUID, TEXT, TEXT, INTEGER, BOOLEAN, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_landing_video(
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

    DELETE FROM app.landing_videos
    WHERE id = p_video_id
    RETURNING id INTO v_deleted;

    IF v_deleted IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_id', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_landing_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_landing_video(UUID) TO service_role;
