-- ============================================================
-- CHANGE 2026-02-28 — Bio profil + Soft delete vidéos (challenge/free)
--
-- Objectifs:
-- 1) Ajouter un champ bio (et lien) au profil étudiant.
-- 2) Ajouter un soft-delete (is_deleted, deleted_at) sur:
--      - app.challenge_participations
--      - app.free_videos
-- 3) Mettre à jour les RPCs de listing pour filtrer les contenus supprimés.
-- 4) Ajouter des RPCs "delete/restore" et "recently deleted" (owner-only).
--
-- IMPORTANT:
-- - Soft delete côté lignes applicatives (cp/fv) = ne casse pas video_assets.
-- - L'effacement physique des fichiers storage est hors scope ici.
-- ============================================================

-- 1) Profil: bio + website_url
ALTER TABLE app.students
  ADD COLUMN IF NOT EXISTS bio TEXT;

ALTER TABLE app.students
  ADD COLUMN IF NOT EXISTS website_url TEXT;

-- 2) Soft delete sur challenges/free
ALTER TABLE app.challenge_participations
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE app.challenge_participations
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE app.free_videos
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE app.free_videos
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;


-- 3) RPC: update my profile
CREATE OR REPLACE FUNCTION public.app_student_update_my_profile(
  p_bio TEXT DEFAULT NULL,
  p_website_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  UPDATE app.students s
  SET
    bio = NULLIF(TRIM(COALESCE(p_bio, '')), ''),
    website_url = NULLIF(TRIM(COALESCE(p_website_url, '')), ''),
    updated_at = NOW()
  WHERE s.id = v_user_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_update_my_profile(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_update_my_profile(TEXT, TEXT) TO service_role;


-- 4) RPC: soft delete / restore
CREATE OR REPLACE FUNCTION public.app_student_soft_delete_video(
  p_video_type TEXT,
  p_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_video_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_id_required');
  END IF;

  IF v_type = 'challenge' THEN
    UPDATE app.challenge_participations cp
    SET
      is_deleted = TRUE,
      deleted_at = NOW()
    WHERE cp.id = p_video_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE
    RETURNING cp.id INTO v_id;

    IF v_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found_or_not_owner');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_type', 'challenge', 'video_id', v_id);
  ELSIF v_type = 'free' THEN
    UPDATE app.free_videos fv
    SET
      is_deleted = TRUE,
      deleted_at = NOW()
    WHERE fv.id = p_video_id
      AND fv.user_id = v_user_id
      AND fv.is_active = TRUE
    RETURNING fv.id INTO v_id;

    IF v_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found_or_not_owner');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_type', 'free', 'video_id', v_id);
  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_soft_delete_video(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_soft_delete_video(TEXT, UUID) TO service_role;


CREATE OR REPLACE FUNCTION public.app_student_restore_video(
  p_video_type TEXT,
  p_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_video_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_id_required');
  END IF;

  IF v_type = 'challenge' THEN
    UPDATE app.challenge_participations cp
    SET
      is_deleted = FALSE,
      deleted_at = NULL
    WHERE cp.id = p_video_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE
    RETURNING cp.id INTO v_id;

    IF v_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found_or_not_owner');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_type', 'challenge', 'video_id', v_id);
  ELSIF v_type = 'free' THEN
    UPDATE app.free_videos fv
    SET
      is_deleted = FALSE,
      deleted_at = NULL
    WHERE fv.id = p_video_id
      AND fv.user_id = v_user_id
      AND fv.is_active = TRUE
    RETURNING fv.id INTO v_id;

    IF v_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found_or_not_owner');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_type', 'free', 'video_id', v_id);
  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_restore_video(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_restore_video(TEXT, UUID) TO service_role;


-- 5) RPC: list recently deleted (owner)
CREATE OR REPLACE FUNCTION public.app_student_list_recently_deleted_videos(
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_limit INTEGER := GREATEST(COALESCE(p_limit, 50), 1);
  v_videos JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  WITH deleted_challenge AS (
    SELECT
      'challenge'::TEXT AS video_type,
      cp.id AS video_id,
      cp.user_id,
      cp.deleted_at,
      COALESCE(cp.submitted_at, cp.started_at) AS created_at,
      cp.challenge_id,
      c.title AS challenge_title,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = cp.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.user_id = v_user_id
      AND cp.is_active = TRUE
      AND cp.is_deleted = TRUE
      AND cp.deleted_at IS NOT NULL
  ),
  deleted_free AS (
    SELECT
      'free'::TEXT AS video_type,
      fv.id AS video_id,
      fv.user_id,
      fv.deleted_at,
      fv.created_at,
      NULL::UUID AS challenge_id,
      fv.title AS challenge_title,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = fv.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url
    FROM app.free_videos fv
    WHERE fv.user_id = v_user_id
      AND fv.is_active = TRUE
      AND fv.is_deleted = TRUE
      AND fv.deleted_at IS NOT NULL
  ),
  unified AS (
    SELECT * FROM deleted_challenge
    UNION ALL
    SELECT * FROM deleted_free
  )
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'video_type', u.video_type,
        'video_id', u.video_id,
        'user_id', u.user_id,
        'video_url', u.video_url,
        'challenge_id', u.challenge_id,
        'challenge_title', u.challenge_title,
        'created_at', u.created_at,
        'deleted_at', u.deleted_at
      )
      ORDER BY u.deleted_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_videos
  FROM (
    SELECT *
    FROM unified
    ORDER BY deleted_at DESC
    LIMIT v_limit
  ) u;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_videos);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_recently_deleted_videos(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_list_recently_deleted_videos(INTEGER) TO service_role;


-- 6) Patch RPCs de listing: exclure is_deleted

-- app_student_unified_video_feed : ajouter filtres cp.is_deleted/fv.is_deleted
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


-- app_student_list_user_videos : ajouter filtres cp.is_deleted/fv.is_deleted
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
    -- Challenge participations
    SELECT
      cp.id AS video_id,
      'challenge' AS video_type,
      cp.id AS participation_id,
      c.title AS challenge_title,
      c.challenge_type,
      c.difficulty,
      c.points,
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

    -- Free videos
    SELECT
      fv.id AS video_id,
      'free' AS video_type,
      NULL::UUID AS participation_id,
      fv.title AS challenge_title,
      NULL::TEXT AS challenge_type,
      NULL::TEXT AS difficulty,
      NULL::INT AS points,
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
GRANT EXECUTE ON FUNCTION public.app_student_list_user_videos(UUID) TO service_role;
