-- Étape 7c (cutover non-destructif) : enrichit Hero playlist avec video_asset_id + playback (best_url/poster_url)
-- AUCUNE suppression legacy (base_video_url/base_image_url restent)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step7_hero_playlist_videoasset.sql

CREATE OR REPLACE FUNCTION app_public_hero_playlist(
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slot_required');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(p)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = p.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = p.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
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

GRANT EXECUTE ON FUNCTION app_public_hero_playlist(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_hero_playlist(TEXT) TO service_role;


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
          (
            TO_JSONB(p)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = p.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = p.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
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
        'video_asset_id', p.video_asset_id,
        'playback', JSONB_BUILD_OBJECT(
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = p.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = p.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        ),
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
