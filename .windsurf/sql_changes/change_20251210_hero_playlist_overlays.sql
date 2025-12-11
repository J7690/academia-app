-- Hero Studio Télé : playlist + overlays + RPC config
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251210_hero_playlist_overlays.sql

-- 1) Table hero_playlist (items Hero pour slots public & étudiant)

CREATE TABLE IF NOT EXISTS app.hero_playlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slot TEXT NOT NULL,
    media_type TEXT NOT NULL DEFAULT 'video'
        CHECK (media_type IN ('video','image')),
    base_video_url TEXT,
    base_image_url TEXT,
    title TEXT,
    subtitle TEXT,
    sort_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.hero_playlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_hero_playlist ON app.hero_playlist;
CREATE POLICY public_select_active_hero_playlist
ON app.hero_playlist FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.hero_playlist TO anon, authenticated;
GRANT ALL ON app.hero_playlist TO service_role;


-- 2) Table hero_overlays (configuration TV par item de playlist)

CREATE TABLE IF NOT EXISTS app.hero_overlays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_item_id UUID NOT NULL REFERENCES app.hero_playlist (id) ON DELETE CASCADE,
    layers JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (playlist_item_id)
);

ALTER TABLE app.hero_overlays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_hero_overlays ON app.hero_overlays;
CREATE POLICY admin_all_hero_overlays
ON app.hero_overlays
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.hero_overlays TO authenticated;
GRANT ALL ON app.hero_overlays TO service_role;


-- 3) (Re)création de hero_renders en s'assurant que hero_playlist existe

CREATE TABLE IF NOT EXISTS app.hero_renders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_item_id UUID NOT NULL REFERENCES app.hero_playlist (id),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'done', 'failed')),
    render_url TEXT,
    thumbnail_url TEXT,
    logs TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.hero_renders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_hero_renders ON app.hero_renders;
CREATE POLICY admin_all_hero_renders
ON app.hero_renders
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT ON app.hero_renders TO authenticated;
GRANT ALL ON app.hero_renders TO service_role;


-- 4) RPC ADMIN - LECTURE DE LA PLAYLIST PAR SLOT

CREATE OR REPLACE FUNCTION app_admin_get_hero_playlist(
    p_slot TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_items JSONB;
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
            TO_JSONB(p)
            ORDER BY p.sort_order, p.created_at
        ),
        '[]'::JSONB
    )
    INTO v_items
    FROM app.hero_playlist p
    WHERE p.slot = p_slot
      AND p.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'items', v_items);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_hero_playlist(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_hero_playlist(TEXT) TO service_role;


-- 5) RPC ADMIN - UPSERT D'UN ITEM HERO PLAYLIST

CREATE OR REPLACE FUNCTION app_admin_upsert_hero_playlist_item(
    p_item_id UUID,
    p_slot TEXT,
    p_media_type TEXT,
    p_base_video_url TEXT,
    p_base_image_url TEXT,
    p_title TEXT,
    p_subtitle TEXT,
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

    IF p_slot IS NULL OR LENGTH(TRIM(p_slot)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slot_required');
    END IF;

    v_media_type_trim := LOWER(TRIM(COALESCE(p_media_type, 'video')));

    IF v_media_type_trim NOT IN ('video','image') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
    END IF;

    -- Validation forte: une vidéo active doit obligatoirement avoir une base_video_url
    IF v_media_type_trim = 'video' AND COALESCE(p_is_active, TRUE) = TRUE THEN
        IF p_base_video_url IS NULL OR LENGTH(TRIM(p_base_video_url)) = 0 THEN
            RETURN JSONB_BUILD_OBJECT(
                'success', FALSE,
                'error', 'base_video_url_required_for_active_video'
            );
        END IF;
    END IF;

    IF p_item_id IS NULL THEN
        INSERT INTO app.hero_playlist (
            slot,
            media_type,
            base_video_url,
            base_image_url,
            title,
            subtitle,
            sort_order,
            is_active
        )
        VALUES (
            p_slot,
            v_media_type_trim,
            p_base_video_url,
            p_base_image_url,
            p_title,
            p_subtitle,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.hero_playlist
        SET
            slot = p_slot,
            media_type = v_media_type_trim,
            base_video_url = p_base_video_url,
            base_image_url = p_base_image_url,
            title = p_title,
            subtitle = p_subtitle,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_item_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'item_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'playlist_item_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_hero_playlist_item(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_hero_playlist_item(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;


-- 6) RPC ADMIN - UPSERT DES OVERLAYS POUR UN ITEM

CREATE OR REPLACE FUNCTION app_admin_upsert_hero_overlays(
    p_playlist_item_id UUID,
    p_layers JSONB
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

    IF p_playlist_item_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'playlist_item_id_required');
    END IF;

    IF p_layers IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_layers');
    END IF;

    INSERT INTO app.hero_overlays (playlist_item_id, layers)
    VALUES (p_playlist_item_id, p_layers)
    ON CONFLICT (playlist_item_id) DO UPDATE
    SET
        layers = EXCLUDED.layers,
        updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_hero_overlays(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_hero_overlays(UUID, JSONB) TO service_role;


-- 7) RPC ADMIN - LECTURE CONFIG COMPLÈTE D'UN ITEM

CREATE OR REPLACE FUNCTION app_admin_get_hero_playlist_item_config(
    p_playlist_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_item JSONB;
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
        'id', p.id,
        'slot', p.slot,
        'media_type', p.media_type,
        'base_video_url', p.base_video_url,
        'base_image_url', p.base_image_url,
        'title', p.title,
        'subtitle', p.subtitle,
        'sort_order', p.sort_order,
        'is_active', p.is_active,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'overlays', (
            SELECT h.layers
            FROM app.hero_overlays h
            WHERE h.playlist_item_id = p.id
        ),
        'last_render', (
            SELECT JSONB_BUILD_OBJECT(
                'id', r.id,
                'status', r.status,
                'render_url', r.render_url,
                'thumbnail_url', r.thumbnail_url,
                'created_at', r.created_at,
                'updated_at', r.updated_at
            )
            FROM app.hero_renders r
            WHERE r.playlist_item_id = p.id
            ORDER BY r.created_at DESC
            LIMIT 1
        )
    )
    INTO v_item
    FROM app.hero_playlist p
    WHERE p.id = p_playlist_item_id;

    IF v_item IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'playlist_item_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'item', v_item);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_hero_playlist_item_config(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_hero_playlist_item_config(UUID) TO service_role;


-- 8) RPC ADMIN - SUPPRESSION D'UN ITEM HERO PLAYLIST

CREATE OR REPLACE FUNCTION app_admin_delete_hero_playlist_item(
    p_item_id UUID
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

    IF p_item_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'item_id_required');
    END IF;

    DELETE FROM app.hero_playlist
    WHERE id = p_item_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_hero_playlist_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_hero_playlist_item(UUID) TO service_role;
