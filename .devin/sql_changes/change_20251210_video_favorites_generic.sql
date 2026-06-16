-- Generic video favorites system (challenge + free)
-- Apply via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251210_video_favorites_generic.sql

CREATE TABLE IF NOT EXISTS app.video_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_type TEXT NOT NULL,
    video_id UUID NOT NULL,
    user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_favorites_video_type_check CHECK (LOWER(video_type) IN ('challenge', 'free')),
    CONSTRAINT video_favorites_unique_per_user UNIQUE (video_type, video_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_video_favorites_video ON app.video_favorites (video_type, video_id);
CREATE INDEX IF NOT EXISTS idx_video_favorites_user ON app.video_favorites (user_id);

-- RPC: app_student_video_favorite
CREATE OR REPLACE FUNCTION app_student_video_favorite(
    p_video_type TEXT,
    p_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_exists BOOLEAN;
    v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_type NOT IN ('challenge', 'free') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
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

    IF v_type = 'challenge' THEN
        SELECT EXISTS (
            SELECT 1
            FROM app.challenge_participations cp
            WHERE cp.id = p_video_id
              AND cp.is_active = TRUE
              AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
        ) INTO v_exists;
    ELSIF v_type = 'free' THEN
        SELECT EXISTS (
            SELECT 1
            FROM app.free_videos fv
            WHERE fv.id = p_video_id
              AND fv.is_active = TRUE
              AND COALESCE(fv.video_url, '') <> ''
        ) INTO v_exists;
    END IF;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    INSERT INTO app.video_favorites (video_type, video_id, user_id)
    VALUES (v_type, p_video_id, v_user_id)
    ON CONFLICT (video_type, video_id, user_id) DO NOTHING;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_video_favorite(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_video_favorite(TEXT, UUID) TO service_role;

-- RPC: app_student_video_unfavorite
CREATE OR REPLACE FUNCTION app_student_video_unfavorite(
    p_video_type TEXT,
    p_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_type NOT IN ('challenge', 'free') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
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

    DELETE FROM app.video_favorites
    WHERE video_type = v_type
      AND video_id = p_video_id
      AND user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_video_unfavorite(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_video_unfavorite(TEXT, UUID) TO service_role;

-- Update unified video feed (v3) favorites for free videos only
-- We re-create app_student_unified_video_feed with favorites_count/has_favorited
-- on free videos based on app.video_favorites.

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
            (
                SELECT COUNT(*)
                FROM app.video_likes vl
                WHERE vl.video_type = 'free'
                  AND vl.video_id = fv.id
            ) AS likes_count,
            (
                SELECT COUNT(*)
                FROM app.video_favorites vf
                WHERE vf.video_type = 'free'
                  AND vf.video_id = fv.id
            ) AS favorites_count,
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
            EXISTS (
                SELECT 1
                FROM app.video_favorites vf2
                WHERE vf2.video_type = 'free'
                  AND vf2.video_id = fv.id
                  AND vf2.user_id = v_user_id
            ) AS has_favorited,
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
