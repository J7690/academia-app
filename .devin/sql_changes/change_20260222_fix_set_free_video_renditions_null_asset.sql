-- FIX: app_student_set_free_video_main_renditions rejetait les appels avec
-- p_video_asset_id = NULL. Après un re-upload (ex: mixage audio FFmpeg),
-- le client n'a pas de video_asset_id car fetchPlaybackForDirectUrl retourne
-- un fallback sans asset. La RPC doit alors récupérer le video_asset_id
-- existant de la free_video et mettre à jour la rendition public_url_hint.

DROP FUNCTION IF EXISTS public.app_student_set_free_video_main_renditions(
  p_free_video_id uuid,
  p_video_asset_id uuid,
  p_playback jsonb
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
  v_user_id        UUID := auth.uid();
  v_is_banned      BOOLEAN;
  v_owner_id       UUID;
  v_existing_asset UUID;
  v_effective_asset UUID;
  v_best_url       TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

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
  INTO v_owner_id, v_existing_asset
  FROM app.free_videos
  WHERE id = p_free_video_id
    AND is_active = TRUE;

  IF v_owner_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  v_best_url := TRIM(COALESCE(p_playback->>'best_url', ''));

  -- Determine effective video_asset_id:
  -- 1) Use provided p_video_asset_id if not null
  -- 2) Fall back to existing video_asset_id on the free_video
  -- 3) Auto-create a new video_asset if we have a best_url
  v_effective_asset := COALESCE(p_video_asset_id, v_existing_asset);

  IF v_effective_asset IS NULL AND v_best_url <> '' THEN
    -- Auto-create video_asset + rendition (same logic as create_free_video)
    INSERT INTO app.video_assets (
      owner_user_id, origin, status, has_audio,
      canonical_type, created_at, updated_at
    ) VALUES (
      v_user_id, 'free_video_reupload', 'ready', TRUE,
      'video', NOW(), NOW()
    )
    RETURNING id INTO v_effective_asset;

    INSERT INTO app.video_renditions (
      video_asset_id, rendition_key, kind, status,
      public_url_hint, storage_bucket, storage_path, created_at
    ) VALUES (
      v_effective_asset, 'legacy_primary', 'mp4', 'ready',
      v_best_url, 'challenge-media', 'legacy/external', NOW()
    );
  END IF;

  IF v_effective_asset IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_video_asset_available');
  END IF;

  -- Update the free_video's video_asset_id
  UPDATE app.free_videos fv
  SET
    video_asset_id = v_effective_asset,
    updated_at     = NOW()
  WHERE fv.id = p_free_video_id
    AND fv.is_active = TRUE;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
  END IF;

  -- Update the rendition's public_url_hint if we have a new best_url
  IF v_best_url <> '' THEN
    UPDATE app.video_renditions
    SET public_url_hint = v_best_url
    WHERE video_asset_id = v_effective_asset
      AND rendition_key = 'legacy_primary'
      AND kind = 'mp4';

    -- If no legacy_primary rendition exists, create one
    IF NOT FOUND THEN
      INSERT INTO app.video_renditions (
        video_asset_id, rendition_key, kind, status,
        public_url_hint, storage_bucket, storage_path, created_at
      ) VALUES (
        v_effective_asset, 'legacy_primary', 'mp4', 'ready',
        v_best_url, 'challenge-media', 'legacy/external', NOW()
      );
    END IF;
  END IF;

  -- VideoAsset context
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  VALUES (v_effective_asset, 'free_video', p_free_video_id, 'primary')
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'free_video_id', p_free_video_id,
    'video_asset_id', v_effective_asset,
    'playback', JSONB_BUILD_OBJECT(
      'best_url', v_best_url,
      'poster_url', p_playback->>'poster_url'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_set_free_video_main_renditions(UUID, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_set_free_video_main_renditions(UUID, UUID, JSONB) TO service_role;
