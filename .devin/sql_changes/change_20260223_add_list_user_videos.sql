-- ============================================================
-- RPC: app_student_list_user_videos
-- Returns all published videos for a given user (both challenge
-- participations and free videos), ordered by most recent first.
-- Used by the social profile screen.
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_student_list_user_videos(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_videos JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id requis');
  END IF;

  -- Combine challenge participations and free videos for the user
  WITH all_videos AS (
    -- Challenge participations
    SELECT
      cp.id AS video_id,
      'challenge' AS video_type,
      cp.id AS participation_id,
      c.title AS challenge_title,
      c.type AS challenge_type,
      c.difficulty,
      c.points,
      cp.video_url,
      cp.playback,
      cp.overlays,
      cp.created_at,
      cp.student_id AS user_id,
      COALESCE(
        (SELECT count(*) FROM video_likes vl WHERE vl.video_type = 'challenge' AND vl.video_id = cp.id::text),
        0
      )::int AS likes_count,
      COALESCE(
        (SELECT count(*) FROM video_comments vc WHERE vc.video_type = 'challenge' AND vc.video_id = cp.id::text),
        0
      )::int AS comments_count,
      NULL AS poster_url
    FROM challenge_participations cp
    JOIN challenges c ON c.id = cp.challenge_id
    WHERE cp.student_id = p_user_id
      AND cp.video_url IS NOT NULL
      AND cp.video_url != ''

    UNION ALL

    -- Free videos
    SELECT
      fv.id AS video_id,
      'free' AS video_type,
      NULL AS participation_id,
      fv.title AS challenge_title,
      NULL AS challenge_type,
      NULL AS difficulty,
      NULL AS points,
      COALESCE(fv.playback->>'best_url', '') AS video_url,
      fv.playback,
      fv.overlays,
      fv.created_at,
      fv.student_id AS user_id,
      COALESCE(
        (SELECT count(*) FROM video_likes vl WHERE vl.video_type = 'free' AND vl.video_id = fv.id::text),
        0
      )::int AS likes_count,
      COALESCE(
        (SELECT count(*) FROM video_comments vc WHERE vc.video_type = 'free' AND vc.video_id = fv.id::text),
        0
      )::int AS comments_count,
      fv.playback->>'poster_url' AS poster_url
    FROM student_free_videos fv
    WHERE fv.student_id = p_user_id
      AND fv.playback IS NOT NULL
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'video_id', av.video_id,
      'video_type', av.video_type,
      'participation_id', av.participation_id,
      'challenge_title', av.challenge_title,
      'challenge_type', av.challenge_type,
      'difficulty', av.difficulty,
      'points', av.points,
      'video_url', av.video_url,
      'playback', av.playback,
      'overlays', av.overlays,
      'likes_count', av.likes_count,
      'comments_count', av.comments_count,
      'poster_url', av.poster_url,
      'user_id', av.user_id,
      'created_at', av.created_at
    ) ORDER BY av.created_at DESC
  ), '[]'::jsonb)
  INTO v_videos
  FROM all_videos av;

  RETURN jsonb_build_object(
    'success', true,
    'videos', v_videos
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_user_videos(UUID) TO authenticated;
