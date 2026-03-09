-- Fix: app_student_create_free_video doit accepter un video_asset_id NULL
-- Cas d'usage: vidéo uploadée directement vers Storage sans passer par le pipeline VideoAsset
-- Le playback JSONB contient l'URL directe dans ce cas.
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20260221_fix_create_free_video_nullable_asset.sql

-- Drop l'ancienne signature (UUID non-nullable)
DROP FUNCTION IF EXISTS public.app_student_create_free_video(UUID, JSONB, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.app_student_create_free_video(
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

  -- On accepte maintenant video_asset_id NULL (upload direct sans pipeline VideoAsset)
  -- Le playback JSONB doit contenir au minimum best_url
  IF p_video_asset_id IS NULL AND (p_playback IS NULL OR p_playback->>'best_url' IS NULL) THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_video_source: need video_asset_id or playback.best_url');
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
    p_video_asset_id,  -- peut être NULL
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

  -- Contexte VideoAsset principal (seulement si on a un video_asset_id)
  IF p_video_asset_id IS NOT NULL THEN
    INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
    VALUES (p_video_asset_id, 'free_video', v_video_id, 'primary')
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  END IF;

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
