-- FIX CRITIQUE: app_student_create_free_video ne créait PAS de video_asset ni
-- de video_rendition quand p_video_asset_id était NULL.
-- Résultat: les free_videos étaient créées en DB mais invisibles dans le feed
-- car la RPC du feed filtre WHERE video_asset_id IS NOT NULL.
--
-- Cette version auto-crée un video_asset + video_rendition quand
-- p_video_asset_id IS NULL mais p_playback->>'best_url' est fourni.

CREATE OR REPLACE FUNCTION app_student_create_free_video(
    p_video_asset_id UUID DEFAULT NULL,
    p_playback JSONB DEFAULT NULL,
    p_title TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_is_banned      BOOLEAN;
  v_video_id       UUID;
  v_asset_id       UUID;
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

  v_best_url := TRIM(COALESCE(p_playback->>'best_url', ''));

  IF p_video_asset_id IS NULL AND v_best_url = '' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_video_source: need video_asset_id or playback.best_url');
  END IF;

  v_asset_id := p_video_asset_id;

  -- Auto-créer video_asset + video_rendition si pas de video_asset_id fourni
  IF v_asset_id IS NULL AND v_best_url <> '' THEN
    INSERT INTO app.video_assets (
      owner_user_id, origin, status, has_audio,
      canonical_type, created_at, updated_at
    ) VALUES (
      v_user_id, 'free_video_upload', 'ready', TRUE,
      'video', NOW(), NOW()
    )
    RETURNING id INTO v_asset_id;

    INSERT INTO app.video_renditions (
      video_asset_id, rendition_key, kind, status,
      public_url_hint, storage_bucket, storage_path, created_at
    ) VALUES (
      v_asset_id, 'legacy_primary', 'mp4', 'ready',
      v_best_url, 'challenge-media', 'legacy/external', NOW()
    );
  END IF;

  -- Créer la free_video avec le video_asset_id (maintenant garanti non-NULL)
  INSERT INTO app.free_videos (
    user_id, video_asset_id, title, description,
    is_active, moderation_status,
    created_at, updated_at
  ) VALUES (
    v_user_id, v_asset_id,
    NULLIF(TRIM(COALESCE(p_title, '')), ''),
    NULLIF(TRIM(COALESCE(p_description, '')), ''),
    TRUE, 'published',
    NOW(), NOW()
  )
  RETURNING id INTO v_video_id;

  -- Contexte VideoAsset principal
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
    VALUES (v_asset_id, 'free_video', v_video_id, 'primary')
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'video_id', v_video_id,
    'video_asset_id', v_asset_id,
    'playback', JSONB_BUILD_OBJECT(
      'best_url', v_best_url,
      'poster_url', p_playback->>'poster_url'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_create_free_video(UUID, JSONB, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_create_free_video(UUID, JSONB, TEXT, TEXT) TO service_role;
