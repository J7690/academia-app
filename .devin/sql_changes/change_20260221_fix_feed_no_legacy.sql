-- Fix: Réécriture complète de app_student_unified_video_feed
-- SANS colonnes legacy (video_url, video_renditions, thumbnail_url, submission_url)
-- qui ont été supprimées par la migration step10b.
-- Toutes les URLs viennent de app.video_renditions via video_asset_id.

CREATE OR REPLACE FUNCTION app_student_unified_video_feed(
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
            COALESCE(
              (
                SELECT r.public_url_hint
                FROM app.video_renditions r
                WHERE r.video_asset_id = cp.video_asset_id
                  AND r.status = 'ready'
                  AND r.kind IN ('hls','mp4')
                ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                LIMIT 1
              ),
              (
                SELECT r.public_url_hint
                FROM app.video_renditions r
                WHERE r.video_asset_id = cp.video_asset_id
                  AND r.status = 'ready'
                ORDER BY COALESCE(r.width, 0) DESC
                LIMIT 1
              )
            ) AS playback_best_url,
            (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = cp.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('poster','thumbnail')
              ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            ) AS playback_poster_url,
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
            COALESCE(
              (
                SELECT r.public_url_hint
                FROM app.video_renditions r
                WHERE r.video_asset_id = fv.video_asset_id
                  AND r.status = 'ready'
                  AND r.kind IN ('hls','mp4')
                ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                LIMIT 1
              ),
              (
                SELECT r.public_url_hint
                FROM app.video_renditions r
                WHERE r.video_asset_id = fv.video_asset_id
                  AND r.status = 'ready'
                ORDER BY COALESCE(r.width, 0) DESC
                LIMIT 1
              )
            ) AS playback_best_url,
            (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = fv.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('poster','thumbnail')
              ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            ) AS playback_poster_url,
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
            COALESCE(fv.remix_type, 'none')::TEXT AS remix_type,
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
            NULL::JSONB AS overlays
        FROM app.free_videos fv
        WHERE fv.is_active = TRUE
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
                'playback', JSONB_BUILD_OBJECT(
                  'best_url', u.playback_best_url,
                  'poster_url', u.playback_poster_url
                ),
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
    WHERE (
        p_cursor IS NULL
        OR u.created_at < p_cursor
    )
    LIMIT v_limit;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$
