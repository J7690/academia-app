-- Free videos RPCs (VideoAsset-only)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_videoasset_free_videos_rpcs.sql

-- 1) app_student_create_free_video : VideoAsset-only

-- On supprime l'ancien shim legacy (p_video_url, p_thumbnail_url, ...)
DROP FUNCTION IF EXISTS public.app_student_create_free_video(
  p_video_url text,
  p_video_renditions jsonb,
  p_thumbnail_url text,
  p_title text,
  p_description text
);

CREATE OR REPLACE FUNCTION public.app_student_create_free_video(
  p_video_asset_id UUID,
  p_playback JSONB,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_is_banned BOOLEAN;
  v_video_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Réutilise le bannissement challenges comme bannissement global vidéo
  SELECT EXISTS (
    SELECT 1
    FROM app.challenge_user_bans b
    WHERE b.user_id = v_user_id
      AND (b.banned_until IS NULL OR b.banned_until > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
  END IF;

  INSERT INTO app.free_videos (
    user_id,
    video_asset_id,
    title,
    description,
    is_active,
    moderation_status,
    moderation_flags,
    moderated_by_admin_id,
    moderated_at,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_video_asset_id,
    NULLIF(TRIM(COALESCE(p_title, '')), ''),
    NULLIF(TRIM(COALESCE(p_description, '')), ''),
    TRUE,
    'published',
    NULL,
    NULL,
    NULL,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_video_id;

  -- Contexte VideoAsset principal
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  VALUES (p_video_asset_id, 'free_video', v_video_id, 'primary')
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'video_id', v_video_id,
    'video_asset_id', p_video_asset_id,
    'playback', JSONB_BUILD_OBJECT(
      'best_url', p_playback->>'best_url',
      'poster_url', p_playback->>'poster_url'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_create_free_video(UUID, JSONB, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_create_free_video(UUID, JSONB, TEXT, TEXT) TO service_role;


-- 2) app_student_set_free_video_main_renditions : VideoAsset-only

-- On supprime l'ancien shim legacy (p_video_url, p_video_renditions)
DROP FUNCTION IF EXISTS public.app_student_set_free_video_main_renditions(
  p_free_video_id uuid,
  p_video_url text,
  p_video_renditions jsonb
);

CREATE OR REPLACE FUNCTION public.app_student_set_free_video_main_renditions(
  p_free_video_id UUID,
  p_video_asset_id UUID,
  p_playback JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_is_banned BOOLEAN;
  v_owner_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Réutilise le bannissement challenges comme bannissement global vidéo
  SELECT EXISTS (
    SELECT 1
    FROM app.challenge_user_bans b
    WHERE b.user_id = v_user_id
      AND (b.banned_until IS NULL OR b.banned_until > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
  END IF;

  SELECT user_id
  INTO v_owner_id
  FROM app.free_videos
  WHERE id = p_free_video_id
    AND is_active = TRUE;

  IF v_owner_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
  END IF;

  UPDATE app.free_videos fv
  SET
    video_asset_id = p_video_asset_id,
    updated_at     = NOW()
  WHERE fv.id = p_free_video_id
    AND fv.is_active = TRUE;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
  END IF;

  -- Contexte VideoAsset principal
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  VALUES (p_video_asset_id, 'free_video', p_free_video_id, 'primary')
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'free_video_id', p_free_video_id,
    'video_asset_id', p_video_asset_id,
    'playback', JSONB_BUILD_OBJECT(
      'best_url', p_playback->>'best_url',
      'poster_url', p_playback->>'poster_url'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_set_free_video_main_renditions(UUID, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_set_free_video_main_renditions(UUID, UUID, JSONB) TO service_role;


-- 3) app_student_get_free_video : renvoie video_asset_id + playback (manifest)

CREATE OR REPLACE FUNCTION public.app_student_get_free_video(
  p_free_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id       UUID := auth.uid();
  v_is_banned     BOOLEAN;
  v_owner_id      UUID;
  v_video_asset_id UUID;
  v_manifest      JSONB;
  v_result        JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Réutilise le bannissement challenges comme bannissement global vidéo
  SELECT EXISTS (
    SELECT 1
    FROM app.challenge_user_bans b
    WHERE b.user_id = v_user_id
      AND (b.banned_until IS NULL OR b.banned_until > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
  END IF;

  SELECT user_id, video_asset_id
  INTO v_owner_id, v_video_asset_id
  FROM app.free_videos
  WHERE id = p_free_video_id
    AND is_active = TRUE;

  IF v_owner_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF v_video_asset_id IS NOT NULL THEN
    v_manifest := app_videoasset_get_playback_manifest(v_video_asset_id, '{}'::JSONB);
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'free_video_id', fv.id,
    'user_id', fv.user_id,
    'video_asset_id', fv.video_asset_id,
    'playback', CASE
      WHEN v_video_asset_id IS NOT NULL
           AND COALESCE(v_manifest->>'success', 'false') = 'true' THEN JSONB_BUILD_OBJECT(
             'best_url',   v_manifest->>'best_url',
             'poster_url', v_manifest->>'poster_url',
             'renditions', v_manifest->'renditions'
           )
      ELSE NULL
    END,
    'title', fv.title,
    'description', fv.description,
    'created_at', fv.created_at,
    'moderation_status', fv.moderation_status,
    'overlays', (
      SELECT o.layers
      FROM app.free_video_overlays o
      WHERE o.free_video_id = fv.id
    )
  )
  INTO v_result
  FROM app.free_videos fv
  WHERE fv.id = p_free_video_id
    AND fv.is_active = TRUE;

  IF v_result IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_free_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_get_free_video(UUID) TO service_role;
