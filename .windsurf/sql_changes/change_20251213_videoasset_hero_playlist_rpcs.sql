-- Hero playlist RPCs (VideoAsset-only for video items)
-- À appliquer via admin_execute_sql (script .windsurf/apply_one_sql_via_admin_rpc.py)

-- 1) RPC PUBLIC / ADMIN de lecture : versions VideoAsset-aware (aucun fallback base_video_url)

-- On remplace les shims Step10B par les vraies implémentations VideoAsset-aware
DROP FUNCTION IF EXISTS public.app_public_hero_playlist(p_slot text) CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_get_hero_playlist(p_slot text) CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_get_hero_playlist_item_config(p_playlist_item_id uuid) CASCADE;


CREATE OR REPLACE FUNCTION public.app_public_hero_playlist(
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

GRANT EXECUTE ON FUNCTION public.app_public_hero_playlist(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_public_hero_playlist(TEXT) TO service_role;


CREATE OR REPLACE FUNCTION public.app_admin_get_hero_playlist(
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

GRANT EXECUTE ON FUNCTION public.app_admin_get_hero_playlist(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_get_hero_playlist(TEXT) TO service_role;


CREATE OR REPLACE FUNCTION public.app_admin_get_hero_playlist_item_config(
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

GRANT EXECUTE ON FUNCTION public.app_admin_get_hero_playlist_item_config(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_get_hero_playlist_item_config(UUID) TO service_role;


-- 2) RPC ADMIN - UPSERT HERO PLAYLIST ITEM (VideoAsset-only pour media_type='video')

-- On remplace le shim legacy (p_base_video_url / p_base_image_url) par une vraie implémentation VideoAsset-only
DROP FUNCTION IF EXISTS public.app_admin_upsert_hero_playlist_item(
  p_item_id uuid,
  p_slot text,
  p_media_type text,
  p_base_video_url text,
  p_base_image_url text,
  p_title text,
  p_subtitle text,
  p_sort_order integer,
  p_is_active boolean
) CASCADE;

CREATE OR REPLACE FUNCTION public.app_admin_upsert_hero_playlist_item(
  p_item_id UUID,
  p_slot TEXT,
  p_media_type TEXT,
  p_video_asset_id UUID,
  p_playback JSONB,
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

  IF p_slot IS NULL OR LENGTH(TRIM(p_slot)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slot_required');
  END IF;

  v_media_type := LOWER(TRIM(COALESCE(p_media_type, 'video')));
  IF v_media_type NOT IN ('video','image') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
  END IF;

  -- Pour les vidéos, on exige un VideoAsset : pas de base_video_url directe
  IF v_media_type = 'video' THEN
    IF p_video_asset_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
    END IF;
  END IF;

  IF p_item_id IS NULL THEN
    INSERT INTO app.hero_playlist (
      slot,
      media_type,
      title,
      subtitle,
      sort_order,
      is_active,
      video_asset_id
    ) VALUES (
      p_slot,
      v_media_type,
      p_title,
      p_subtitle,
      COALESCE(p_sort_order, 0),
      COALESCE(p_is_active, TRUE),
      p_video_asset_id
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE app.hero_playlist
    SET
      slot          = p_slot,
      media_type    = v_media_type,
      title         = p_title,
      subtitle      = p_subtitle,
      sort_order    = COALESCE(p_sort_order, sort_order),
      is_active     = COALESCE(p_is_active, is_active),
      video_asset_id = COALESCE(p_video_asset_id, video_asset_id),
      updated_at    = NOW()
    WHERE id = p_item_id
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'item_not_saved');
  END IF;

  -- Contexte VideoAsset pour les items vidéo
  IF p_video_asset_id IS NOT NULL AND v_media_type = 'video' THEN
    INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
    VALUES (p_video_asset_id, 'hero_playlist', v_id, 'primary')
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'playlist_item_id', v_id,
    'video_asset_id', p_video_asset_id,
    'media_type', v_media_type,
    'playback', CASE
      WHEN p_video_asset_id IS NOT NULL THEN JSONB_BUILD_OBJECT(
        'best_url',   p_playback->>'best_url',
        'poster_url', p_playback->>'poster_url'
      )
      ELSE NULL
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_upsert_hero_playlist_item(
  UUID, TEXT, TEXT, UUID, JSONB, TEXT, TEXT, INTEGER, BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_hero_playlist_item(
  UUID, TEXT, TEXT, UUID, JSONB, TEXT, TEXT, INTEGER, BOOLEAN
) TO service_role;
