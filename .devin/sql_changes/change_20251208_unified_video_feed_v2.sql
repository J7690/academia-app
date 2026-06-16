-- Version 2 du feed unifié : utilise challenge_participations pour les vidéos de challenges
-- et free_videos pour les vidéos libres, sans dépendre de app.challenge_videos.

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
            COALESCE(cp.video_url, cp.submission_url) AS video_url,
            cp.video_renditions AS video_renditions,
            cp.thumbnail_url,
            NULL::TEXT AS title,
            cp.submission_text AS description,
            COALESCE(cp.submitted_at, cp.started_at) AS created_at,
            COALESCE(cp.updated_at, cp.submitted_at, cp.started_at, NOW()) AS updated_at,
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
                FROM app.challenge_likes l
                WHERE l.participation_id = cp.id
            ) AS likes_count,
            (
                SELECT COUNT(*)
                FROM app.challenge_favorites f
                WHERE f.participation_id = cp.id
            ) AS favorites_count,
            (
                SELECT COUNT(*)
                FROM app.challenge_comments cc
                WHERE cc.participation_id = cp.id
                  AND cc.is_deleted = FALSE
            ) AS comments_count,
            (
                SELECT COUNT(*)
                FROM app.challenge_reports r
                WHERE r.participation_id = cp.id
                  AND r.status = 'pending'
            ) AS reports_count,
            EXISTS (
                SELECT 1
                FROM app.challenge_likes l2
                WHERE l2.participation_id = cp.id
                  AND l2.user_id = v_user_id
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
          AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
          AND COALESCE(cp.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
          AND c.is_active = TRUE
    ),
    free_feed AS (
        SELECT
            'free'::TEXT AS video_type,
            fv.id AS video_id,
            fv.user_id,
            fv.video_url,
            fv.video_renditions,
            fv.thumbnail_url,
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
            0::BIGINT AS likes_count,
            0::BIGINT AS favorites_count,
            0::BIGINT AS comments_count,
            0::BIGINT AS reports_count,
            FALSE AS has_liked,
            FALSE AS has_favorited,
            NULL::JSONB AS overlays
        FROM app.free_videos fv
        WHERE fv.is_active = TRUE
          AND COALESCE(fv.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
          AND COALESCE(fv.video_url, '') <> ''
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
    WHERE (
        p_cursor IS NULL
        OR u.created_at < p_cursor
    )
    LIMIT v_limit;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_unified_video_feed(TIMESTAMPTZ, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_unified_video_feed(TIMESTAMPTZ, INTEGER) TO service_role;
