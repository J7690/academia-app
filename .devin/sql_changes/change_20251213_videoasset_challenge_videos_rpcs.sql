-- Challenge videos RPCs (VideoAsset-only)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_videoasset_challenge_videos_rpcs.sql

-- 1) app_student_add_challenge_video : VideoAsset-only

-- On supprime l'ancien shim legacy (p_video_url, p_thumbnail_url)
DROP FUNCTION IF EXISTS public.app_student_add_challenge_video(
  p_participation_id uuid,
  p_video_url text,
  p_thumbnail_url text
);

CREATE OR REPLACE FUNCTION public.app_student_add_challenge_video(
  p_participation_id UUID,
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
  v_video_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Réutilise le bannissement challenges
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
  FROM app.challenge_participations
  WHERE id = p_participation_id
    AND is_active = TRUE;

  IF v_owner_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
  END IF;

  INSERT INTO app.challenge_participation_videos (
    participation_id,
    video_asset_id
  ) VALUES (
    p_participation_id,
    p_video_asset_id
  )
  RETURNING id INTO v_video_id;

  IF v_video_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_saved');
  END IF;

  -- Contexte VideoAsset pour la vidéo additionnelle
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  VALUES (p_video_asset_id, 'challenge_participation_video', v_video_id, 'primary')
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

GRANT EXECUTE ON FUNCTION public.app_student_add_challenge_video(UUID, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_add_challenge_video(UUID, UUID, JSONB) TO service_role;


-- 2) app_student_list_my_challenge_videos : VideoAsset + playback

CREATE OR REPLACE FUNCTION public.app_student_list_my_challenge_videos(
  p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_is_banned BOOLEAN;
  v_owner_id  UUID;
  v_result    JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Réutilise le bannissement challenges
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
  FROM app.challenge_participations
  WHERE id = p_participation_id
    AND is_active = TRUE;

  IF v_owner_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', v.id,
        'participation_id', v.participation_id,
        'video_asset_id', v.video_asset_id,
        'playback', CASE
          WHEN v.video_asset_id IS NOT NULL THEN JSONB_BUILD_OBJECT(
            'best_url', (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = v.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('hls','mp4')
              ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            ),
            'poster_url', (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = v.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('poster','thumbnail')
              ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            )
          )
          ELSE NULL
        END,
        'created_at', v.created_at
      )
      ORDER BY v.created_at ASC
    ),
    '[]'::JSONB
  )
  INTO v_result
  FROM app.challenge_participation_videos v
  WHERE v.participation_id = p_participation_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_my_challenge_videos(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_list_my_challenge_videos(UUID) TO service_role;


-- 3) app_student_set_challenge_main_video : VideoAsset-only

-- On supprime les anciens shims legacy (p_video_url, p_video_renditions)
DROP FUNCTION IF EXISTS public.app_student_set_challenge_main_video(
  p_participation_id uuid,
  p_video_url text
);

DROP FUNCTION IF EXISTS public.app_student_set_challenge_main_video(
  p_participation_id uuid,
  p_video_url text,
  p_video_renditions jsonb
);

CREATE OR REPLACE FUNCTION public.app_student_set_challenge_main_video(
  p_participation_id UUID,
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

  -- Réutilise le bannissement challenges
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
  FROM app.challenge_participations
  WHERE id = p_participation_id
    AND is_active = TRUE;

  IF v_owner_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
  END IF;

  UPDATE app.challenge_participations cp
  SET
    video_asset_id = p_video_asset_id
  WHERE cp.id = p_participation_id
    AND cp.is_active = TRUE;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
  END IF;

  -- Contexte VideoAsset principal pour la participation
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  VALUES (p_video_asset_id, 'challenge_participation', p_participation_id, 'primary')
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'participation_id', p_participation_id,
    'video_asset_id', p_video_asset_id,
    'playback', JSONB_BUILD_OBJECT(
      'best_url', p_playback->>'best_url',
      'poster_url', p_playback->>'poster_url'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_set_challenge_main_video(UUID, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_set_challenge_main_video(UUID, UUID, JSONB) TO service_role;
