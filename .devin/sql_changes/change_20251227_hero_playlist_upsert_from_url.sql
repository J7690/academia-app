-- Hero playlist URL-based upsert helper for admin UIs
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251227_hero_playlist_upsert_from_url.sql

CREATE OR REPLACE FUNCTION public.app_admin_upsert_hero_playlist_item_from_url(
  p_item_id UUID,
  p_slot TEXT,
  p_media_type TEXT,
  p_url TEXT,
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
  v_url TEXT;
  v_result JSONB;
  v_playback_result JSONB;
  v_manifest JSONB;
  v_video_asset_id UUID;
  v_playback JSONB;
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

  v_url := NULLIF(TRIM(COALESCE(p_url, '')), '');

  IF COALESCE(p_is_active, TRUE) = TRUE AND v_url IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'url_required_for_active_item');
  END IF;

  -- Cas image : on conserve le comportement legacy (URL directe dans base_image_url)
  IF v_media_type = 'image' THEN
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
      ) VALUES (
        p_slot,
        v_media_type,
        NULL,
        v_url,
        p_title,
        p_subtitle,
        COALESCE(p_sort_order, 0),
        COALESCE(p_is_active, TRUE)
      )
      RETURNING id INTO v_id;
    ELSE
      UPDATE app.hero_playlist
      SET
        slot          = p_slot,
        media_type    = v_media_type,
        base_image_url = COALESCE(v_url, base_image_url),
        title         = p_title,
        subtitle      = p_subtitle,
        sort_order    = COALESCE(p_sort_order, sort_order),
        is_active     = COALESCE(p_is_active, is_active),
        updated_at    = NOW()
      WHERE id = p_item_id
      RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'item_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'playlist_item_id', v_id,
      'media_type', v_media_type,
      'url', v_url
    );
  END IF;

  -- Cas vidéo : résolution de l'URL via VideoAsset + playback, puis délégation
  IF v_url IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'url_required_for_active_item');
  END IF;

  v_playback_result := public.app_videoasset_get_playback_for_direct_url(v_url);

  IF COALESCE(v_playback_result->>'success', 'false') <> 'true' THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', COALESCE(v_playback_result->>'error', 'playback_resolution_failed')
    );
  END IF;

  v_manifest := v_playback_result->'manifest';
  IF v_manifest IS NULL OR jsonb_typeof(v_manifest) <> 'object' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_playback_manifest');
  END IF;

  BEGIN
    v_video_asset_id := (v_manifest->>'video_asset_id')::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_video_asset_id := NULL;
  END;

  v_playback := v_manifest->'playback';

  IF v_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
  END IF;

  IF v_playback IS NULL OR jsonb_typeof(v_playback) <> 'object' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_playback');
  END IF;

  v_result := public.app_admin_upsert_hero_playlist_item(
    p_item_id,
    p_slot,
    v_media_type,
    v_video_asset_id,
    v_playback,
    p_title,
    p_subtitle,
    p_sort_order,
    p_is_active
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_upsert_hero_playlist_item_from_url(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_hero_playlist_item_from_url(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN
) TO service_role;
