CREATE OR REPLACE FUNCTION public.app_get_public_user_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_profile JSONB;
  v_video_count INT;
  v_total_likes INT;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id_required');
  END IF;

  SELECT jsonb_build_object(
    'user_id', s.id,
    'full_name', s.full_name,
    'avatar_url', s.avatar_url,
    'bio', s.bio,
    'website_url', s.website_url,
    'city', s.city,
    'country', s.country
  )
  INTO v_profile
  FROM app.students s
  WHERE s.id = p_user_id;

  IF v_profile IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_not_found');
  END IF;

  -- Count published videos (challenge + free)
  SELECT count(*) INTO v_video_count
  FROM (
    SELECT cp.id
    FROM app.challenge_participations cp
    WHERE cp.user_id = p_user_id
      AND cp.is_active = TRUE
      AND cp.is_deleted = FALSE
      AND cp.video_asset_id IS NOT NULL
    UNION ALL
    SELECT fv.id
    FROM app.free_videos fv
    WHERE fv.user_id = p_user_id
      AND fv.is_active = TRUE
      AND fv.is_deleted = FALSE
      AND fv.video_asset_id IS NOT NULL
  ) t;

  -- Sum total likes across all videos
  SELECT COALESCE(sum(cnt), 0)::INT INTO v_total_likes
  FROM (
    SELECT (SELECT count(*) FROM app.video_likes vl
            WHERE vl.video_type = 'challenge' AND vl.video_id = cp.id) AS cnt
    FROM app.challenge_participations cp
    WHERE cp.user_id = p_user_id
      AND cp.is_active = TRUE AND cp.is_deleted = FALSE
      AND cp.video_asset_id IS NOT NULL
    UNION ALL
    SELECT (SELECT count(*) FROM app.video_likes vl
            WHERE vl.video_type = 'free' AND vl.video_id = fv.id) AS cnt
    FROM app.free_videos fv
    WHERE fv.user_id = p_user_id
      AND fv.is_active = TRUE AND fv.is_deleted = FALSE
      AND fv.video_asset_id IS NOT NULL
  ) t;

  RETURN jsonb_build_object(
    'success', true,
    'profile', v_profile || jsonb_build_object(
      'video_count', v_video_count,
      'total_likes', v_total_likes,
      'followers_count', 0,
      'following_count', 0
    )
  );
END;
$$;
