-- Phase 2: Watermarked export (server-side) + surface video_asset_id in feeds

-- 1) Student RPC: request a watermarked export for a VideoAsset.
--    Returns existing ready URL if already generated, otherwise enqueues a processing job.
CREATE OR REPLACE FUNCTION public.app_student_request_video_export_watermarked(
  p_video_asset_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_owner BOOLEAN := FALSE;
  v_allow_download BOOLEAN := FALSE;
  v_existing_url TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_asset_id_required');
  END IF;

  -- Resolve permissions from challenge/free records.
  SELECT TRUE, cp.allow_download
  INTO v_is_owner, v_allow_download
  FROM app.challenge_participations cp
  WHERE cp.video_asset_id = p_video_asset_id
    AND cp.is_active = TRUE
    AND cp.is_deleted = FALSE
    AND cp.user_id = v_user_id
  LIMIT 1;

  IF NOT v_is_owner THEN
    SELECT COALESCE(cp.allow_download, FALSE)
    INTO v_allow_download
    FROM app.challenge_participations cp
    WHERE cp.video_asset_id = p_video_asset_id
      AND cp.is_active = TRUE
      AND cp.is_deleted = FALSE
    LIMIT 1;
  END IF;

  IF NOT v_is_owner AND NOT v_allow_download THEN
    SELECT TRUE, fv.allow_download
    INTO v_is_owner, v_allow_download
    FROM app.free_videos fv
    WHERE fv.video_asset_id = p_video_asset_id
      AND fv.is_active = TRUE
      AND fv.is_deleted = FALSE
      AND fv.user_id = v_user_id
    LIMIT 1;

    IF NOT v_is_owner THEN
      SELECT COALESCE(fv.allow_download, FALSE)
      INTO v_allow_download
      FROM app.free_videos fv
      WHERE fv.video_asset_id = p_video_asset_id
        AND fv.is_active = TRUE
        AND fv.is_deleted = FALSE
      LIMIT 1;
    END IF;
  END IF;

  IF NOT v_is_owner AND NOT v_allow_download THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'download_not_allowed');
  END IF;

  -- If rendition already ready, return it.
  SELECT vr.public_url_hint
  INTO v_existing_url
  FROM app.video_renditions vr
  WHERE vr.video_asset_id = p_video_asset_id
    AND vr.rendition_key = 'export_watermarked'
    AND vr.kind = 'mp4'
    AND vr.status = 'ready'
  ORDER BY vr.created_at DESC
  LIMIT 1;

  IF v_existing_url IS NOT NULL AND LENGTH(TRIM(v_existing_url)) > 0 THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'status', 'ready',
      'url', v_existing_url
    );
  END IF;

  -- Enqueue job if not already queued/running.
  IF NOT EXISTS (
    SELECT 1
    FROM app.video_processing_jobs j
    WHERE j.video_asset_id = p_video_asset_id
      AND j.job_type = 'export_watermarked'
      AND j.status IN ('queued','running')
  ) THEN
    INSERT INTO app.video_processing_jobs (video_asset_id, job_type, status, payload)
    VALUES (p_video_asset_id, 'export_watermarked', 'queued', '{}'::JSONB);
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', 'queued');
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_request_video_export_watermarked(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_request_video_export_watermarked(UUID) TO service_role;


-- 2) Patch feeds: include video_asset_id.

CREATE OR REPLACE FUNCTION public.app_student_unified_video_feed(
  p_cursor TIMESTAMPTZ DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_banned BOOLEAN;
  v_limit INTEGER := GREATEST(COALESCE(p_limit, 20), 1);
  v_result JSONB;
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

  WITH challenge_feed AS (
    SELECT
      'challenge'::TEXT AS video_type,
      cp.id AS video_id,
      cp.user_id,
      cp.video_asset_id,
      cp.allow_download,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = cp.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url,
      (
        SELECT JSONB_OBJECT_AGG(vr.rendition_key, vr.public_url_hint)
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = cp.video_asset_id
          AND vr.status = 'ready'
          AND vr.public_url_hint IS NOT NULL
      ) AS video_renditions,
      NULL::TEXT AS thumbnail_url,
      NULL::TEXT AS title,
      cp.submission_text AS description,
      COALESCE(cp.submitted_at, cp.started_at) AS created_at,
      COALESCE(cp.submitted_at, cp.started_at, NOW()) AS updated_at,
      cp.challenge_id,
      c.title AS challenge_title,
      c.challenge_type,
      c.difficulty,
      c.points,
      cp.id AS participation_id,
      cp.parent_participation_id,
      cp.remix_type,
      cp.moderation_status,
      (
        SELECT COUNT(*)
        FROM app.video_likes vl
        WHERE vl.video_type = 'challenge'
          AND vl.video_id = cp.id
      ) AS likes_count,
      (
        SELECT COUNT(*)
        FROM app.challenge_favorites f
        WHERE f.participation_id = cp.id
      ) AS favorites_count,
      (
        SELECT COUNT(*)
        FROM app.video_comments vc
        WHERE vc.video_type = 'challenge'
          AND vc.video_id = cp.id
          AND vc.is_deleted = FALSE
      ) AS comments_count,
      (
        SELECT COUNT(*)
        FROM app.video_reports vr
        WHERE vr.video_type = 'challenge'
          AND vr.video_id = cp.id
          AND LOWER(vr.status) = 'pending'
      ) AS reports_count,
      EXISTS (
        SELECT 1
        FROM app.video_likes vl2
        WHERE vl2.video_type = 'challenge'
          AND vl2.video_id = cp.id
          AND vl2.user_id = v_user_id
      ) AS has_liked,
      EXISTS (
        SELECT 1
        FROM app.challenge_favorites f2
        WHERE f2.participation_id = cp.id
          AND f2.user_id = v_user_id
      ) AS has_favorited,
      (
        SELECT o.layers
        FROM app.challenge_video_overlays o
        WHERE o.participation_id = cp.id
      ) AS overlays
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.is_active = TRUE
      AND cp.is_deleted = FALSE
      AND cp.video_asset_id IS NOT NULL
      AND COALESCE(cp.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
      AND c.is_active = TRUE
  ),
  free_feed AS (
    SELECT
      'free'::TEXT AS video_type,
      fv.id AS video_id,
      fv.user_id,
      fv.video_asset_id,
      fv.allow_download,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = fv.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url,
      (
        SELECT JSONB_OBJECT_AGG(vr.rendition_key, vr.public_url_hint)
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = fv.video_asset_id
          AND vr.status = 'ready'
          AND vr.public_url_hint IS NOT NULL
      ) AS video_renditions,
      NULL::TEXT AS thumbnail_url,
      fv.title,
      fv.description,
      fv.created_at,
      fv.updated_at,
      NULL::UUID AS challenge_id,
      NULL::TEXT AS challenge_title,
      NULL::TEXT AS challenge_type,
      NULL::TEXT AS difficulty,
      NULL::INTEGER AS points,
      NULL::UUID AS participation_id,
      NULL::UUID AS parent_participation_id,
      'none'::TEXT AS remix_type,
      fv.moderation_status,
      (
        SELECT COUNT(*)
        FROM app.video_likes vl
        WHERE vl.video_type = 'free'
          AND vl.video_id = fv.id
      ) AS likes_count,
      0::BIGINT AS favorites_count,
      (
        SELECT COUNT(*)
        FROM app.video_comments vc
        WHERE vc.video_type = 'free'
          AND vc.video_id = fv.id
          AND vc.is_deleted = FALSE
      ) AS comments_count,
      (
        SELECT COUNT(*)
        FROM app.video_reports vr
        WHERE vr.video_type = 'free'
          AND vr.video_id = fv.id
          AND LOWER(vr.status) = 'pending'
      ) AS reports_count,
      EXISTS (
        SELECT 1
        FROM app.video_likes vl2
        WHERE vl2.video_type = 'free'
          AND vl2.video_id = fv.id
          AND vl2.user_id = v_user_id
      ) AS has_liked,
      FALSE AS has_favorited,
      (
        SELECT fo.layers
        FROM app.free_video_overlays fo
        WHERE fo.free_video_id = fv.id
      ) AS overlays
    FROM app.free_videos fv
    WHERE fv.is_active = TRUE
      AND fv.is_deleted = FALSE
      AND fv.video_asset_id IS NOT NULL
      AND COALESCE(fv.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
  ),
  unified AS (
    SELECT * FROM challenge_feed
    UNION ALL
    SELECT * FROM free_feed
  )
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'video_type', u.video_type,
        'video_id', u.video_id,
        'user_id', u.user_id,
        'video_asset_id', u.video_asset_id,
        'allow_download', u.allow_download,
        'video_url', u.video_url,
        'video_renditions', u.video_renditions,
        'thumbnail_url', u.thumbnail_url,
        'title', u.title,
        'description', u.description,
        'challenge_id', u.challenge_id,
        'challenge_title', u.challenge_title,
        'challenge_type', u.challenge_type,
        'difficulty', u.difficulty,
        'points', u.points,
        'participation_id', u.participation_id,
        'parent_participation_id', u.parent_participation_id,
        'remix_type', u.remix_type,
        'moderation_status', u.moderation_status,
        'created_at', u.created_at,
        'likes_count', u.likes_count,
        'favorites_count', u.favorites_count,
        'comments_count', u.comments_count,
        'reports_count', u.reports_count,
        'has_liked', u.has_liked,
        'has_favorited', u.has_favorited,
        'overlays', u.overlays
      )
      ORDER BY u.created_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_result
  FROM unified u
  WHERE u.video_url IS NOT NULL
    AND (
      p_cursor IS NULL
      OR u.created_at < p_cursor
    )
  LIMIT v_limit;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_unified_video_feed(TIMESTAMPTZ, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_unified_video_feed(TIMESTAMPTZ, INTEGER) TO service_role;


CREATE OR REPLACE FUNCTION public.app_student_list_user_videos(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_videos JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id requis');
  END IF;

  WITH all_videos AS (
    SELECT
      cp.id AS video_id,
      'challenge' AS video_type,
      cp.id AS participation_id,
      cp.video_asset_id,
      c.title AS challenge_title,
      c.challenge_type,
      c.difficulty,
      c.points,
      cp.allow_download,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = cp.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url,
      (
        SELECT JSONB_BUILD_OBJECT('best_url',
          COALESCE(
            (SELECT vr2.public_url_hint FROM app.video_renditions vr2
             WHERE vr2.video_asset_id = cp.video_asset_id AND vr2.status = 'ready'
             ORDER BY vr2.created_at DESC LIMIT 1),
            ''
          )
        )
      ) AS playback,
      (
        SELECT cvo.layers
        FROM app.challenge_video_overlays cvo
        WHERE cvo.participation_id = cp.id
        ORDER BY cvo.updated_at DESC
        LIMIT 1
      ) AS overlays,
      COALESCE(cp.submitted_at, cp.started_at) AS created_at,
      cp.user_id,
      COALESCE(
        (SELECT count(*) FROM app.video_likes vl
         WHERE vl.video_type = 'challenge' AND vl.video_id = cp.id),
        0
      )::int AS likes_count,
      COALESCE(
        (SELECT count(*) FROM app.video_comments vc
         WHERE vc.video_type = 'challenge' AND vc.video_id = cp.id
           AND vc.is_deleted = FALSE),
        0
      )::int AS comments_count,
      NULL::TEXT AS poster_url
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.user_id = p_user_id
      AND cp.is_active = TRUE
      AND cp.is_deleted = FALSE
      AND cp.video_asset_id IS NOT NULL

    UNION ALL

    SELECT
      fv.id AS video_id,
      'free' AS video_type,
      NULL::UUID AS participation_id,
      fv.video_asset_id,
      fv.title AS challenge_title,
      NULL::TEXT AS challenge_type,
      NULL::TEXT AS difficulty,
      NULL::INT AS points,
      fv.allow_download,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = fv.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url,
      (
        SELECT JSONB_BUILD_OBJECT('best_url',
          COALESCE(
            (SELECT vr2.public_url_hint FROM app.video_renditions vr2
             WHERE vr2.video_asset_id = fv.video_asset_id AND vr2.status = 'ready'
             ORDER BY vr2.created_at DESC LIMIT 1),
            ''
          )
        )
      ) AS playback,
      (
        SELECT fvo.layers
        FROM app.free_video_overlays fvo
        WHERE fvo.free_video_id = fv.id
        ORDER BY fvo.updated_at DESC
        LIMIT 1
      ) AS overlays,
      fv.created_at,
      fv.user_id,
      COALESCE(
        (SELECT count(*) FROM app.video_likes vl
         WHERE vl.video_type = 'free' AND vl.video_id = fv.id),
        0
      )::int AS likes_count,
      COALESCE(
        (SELECT count(*) FROM app.video_comments vc
         WHERE vc.video_type = 'free' AND vc.video_id = fv.id
           AND vc.is_deleted = FALSE),
        0
      )::int AS comments_count,
      NULL::TEXT AS poster_url
    FROM app.free_videos fv
    WHERE fv.user_id = p_user_id
      AND fv.is_active = TRUE
      AND fv.is_deleted = FALSE
      AND fv.video_asset_id IS NOT NULL
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'video_id', av.video_id,
      'video_type', av.video_type,
      'participation_id', av.participation_id,
      'video_asset_id', av.video_asset_id,
      'challenge_title', av.challenge_title,
      'challenge_type', av.challenge_type,
      'difficulty', av.difficulty,
      'points', av.points,
      'allow_download', av.allow_download,
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
GRANT EXECUTE ON FUNCTION public.app_student_list_user_videos(UUID) TO service_role;
