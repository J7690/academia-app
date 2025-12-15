-- Étape 7e (cutover non-destructif) : enrichit les RPC Challenges/Studio avec video_asset_id + playback (best_url/poster_url)
-- AUCUNE suppression legacy (video_url, video_renditions, thumbnail_url restent)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step7_challenges_videoasset.sql

-- 1) RPC étudiant - feed vidéos challenges
CREATE OR REPLACE FUNCTION app_student_challenge_video_feed(
    p_cursor TIMESTAMPTZ DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_challenge_id UUID DEFAULT NULL
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

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'participation_id', s.id,
                'challenge_id', s.challenge_id,
                'user_id', s.user_id,
                'parent_participation_id', s.parent_participation_id,
                'remix_type', s.remix_type,
                'challenge_title', s.challenge_title,
                'challenge_type', s.challenge_type,
                'difficulty', s.difficulty,
                'points', s.points,
                -- legacy
                'video_url', s.video_url,
                'video_renditions', s.video_renditions,
                'thumbnail_url', s.thumbnail_url,
                -- new
                'video_asset_id', s.video_asset_id,
                'playback', JSONB_BUILD_OBJECT(
                  'best_url', s.playback_best_url,
                  'poster_url', s.playback_poster_url
                ),
                'status', s.status,
                'moderation_status', s.moderation_status,
                'created_at', s.created_at,
                'likes_count', s.likes_count,
                'favorites_count', s.favorites_count,
                'comments_count', s.comments_count,
                'reports_count', s.reports_count,
                'has_liked', s.has_liked,
                'has_favorited', s.has_favorited,
                'overlays', s.overlays
            )
            ORDER BY s.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
        FROM (
            SELECT
                cp.id,
                cp.challenge_id,
                cp.user_id,
                cp.parent_participation_id,
                cp.remix_type,
                c.title AS challenge_title,
                c.challenge_type,
                c.difficulty,
                c.points,
                COALESCE(cp.video_url, cp.submission_url) AS video_url,
                cp.video_renditions AS video_renditions,
                cp.thumbnail_url,
                cp.video_asset_id,
                (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = cp.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
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
                cp.status,
                cp.moderation_status,
                COALESCE(cp.submitted_at, cp.started_at) AS created_at,
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
              AND cp.moderation_status = 'approved'
              AND c.is_active = TRUE
              AND (p_challenge_id IS NULL OR cp.challenge_id = p_challenge_id)
              AND (
                p_cursor IS NULL
                OR COALESCE(cp.submitted_at, cp.started_at) < p_cursor
              )
            ORDER BY COALESCE(cp.submitted_at, cp.started_at) DESC
            LIMIT v_limit
        ) s;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_challenge_video_feed(TIMESTAMPTZ, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_challenge_video_feed(TIMESTAMPTZ, INTEGER, UUID) TO service_role;


-- 2) RPC étudiant - détail vidéo challenge
CREATE OR REPLACE FUNCTION app_student_get_challenge_video(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_result JSONB;
    v_owner_id UUID;
    v_moderation_status TEXT;
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

    SELECT user_id, moderation_status
    INTO v_owner_id, v_moderation_status
    FROM app.challenge_participations
    WHERE id = p_participation_id
      AND is_active = TRUE;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    IF v_owner_id <> v_user_id AND v_moderation_status <> 'approved' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_available');
    END IF;

    SELECT JSONB_BUILD_OBJECT(
        'participation_id', cp.id,
        'challenge_id', cp.challenge_id,
        'user_id', cp.user_id,
        'parent_participation_id', cp.parent_participation_id,
        'remix_type', cp.remix_type,
        'challenge_title', c.title,
        'challenge_type', c.challenge_type,
        'difficulty', c.difficulty,
        'points', c.points,
        -- legacy
        'video_url', COALESCE(cp.video_url, cp.submission_url),
        'video_renditions', cp.video_renditions,
        'thumbnail_url', cp.thumbnail_url,
        -- new
        'video_asset_id', cp.video_asset_id,
        'playback', JSONB_BUILD_OBJECT(
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = cp.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = cp.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        ),
        'status', cp.status,
        'moderation_status', cp.moderation_status,
        'created_at', COALESCE(cp.submitted_at, cp.started_at),
        'likes_count', (
            SELECT COUNT(*)
            FROM app.challenge_likes l
            WHERE l.participation_id = cp.id
        ),
        'favorites_count', (
            SELECT COUNT(*)
            FROM app.challenge_favorites f
            WHERE f.participation_id = cp.id
        ),
        'comments_count', (
            SELECT COUNT(*)
            FROM app.challenge_comments cc
            WHERE cc.participation_id = cp.id
              AND cc.is_deleted = FALSE
        ),
        'has_liked', EXISTS (
            SELECT 1
            FROM app.challenge_likes l2
            WHERE l2.participation_id = cp.id
              AND l2.user_id = v_user_id
        ),
        'has_favorited', EXISTS (
            SELECT 1
            FROM app.challenge_favorites f2
            WHERE f2.participation_id = cp.id
              AND f2.user_id = v_user_id
        ),
        'overlays', (
            SELECT o.layers
            FROM app.challenge_video_overlays o
            WHERE o.participation_id = cp.id
        )
    ) INTO v_result
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.id = p_participation_id
      AND cp.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_get_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_get_challenge_video(UUID) TO service_role;


-- 3) RPC admin - liste vidéos challenges (modération)
CREATE OR REPLACE FUNCTION app_admin_list_challenge_videos(
    p_challenge_id UUID DEFAULT NULL,
    p_moderation_status TEXT DEFAULT NULL,
    p_has_pending_reports BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_status_filter TEXT := NULLIF(TRIM(COALESCE(p_moderation_status, '')), '');
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'participation_id', cp.id,
                'challenge_id', cp.challenge_id,
                'user_id', cp.user_id,
                'challenge_title', c.title,
                'challenge_type', c.challenge_type,
                'difficulty', c.difficulty,
                'points', c.points,
                -- legacy
                'video_url', COALESCE(cp.video_url, cp.submission_url),
                'thumbnail_url', cp.thumbnail_url,
                -- new
                'video_asset_id', cp.video_asset_id,
                'playback', JSONB_BUILD_OBJECT(
                  'best_url', (
                    SELECT r.public_url_hint
                    FROM app.video_renditions r
                    WHERE r.video_asset_id = cp.video_asset_id
                      AND r.status = 'ready'
                      AND r.kind IN ('hls','mp4')
                    ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                    LIMIT 1
                  ),
                  'poster_url', (
                    SELECT r.public_url_hint
                    FROM app.video_renditions r
                    WHERE r.video_asset_id = cp.video_asset_id
                      AND r.status = 'ready'
                      AND r.kind IN ('poster','thumbnail')
                    ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                    LIMIT 1
                  )
                ),
                'status', cp.status,
                'moderation_status', cp.moderation_status,
                'moderation_flags', cp.moderation_flags,
                'created_at', COALESCE(cp.submitted_at, cp.started_at),
                'likes_count', (
                    SELECT COUNT(*)
                    FROM app.challenge_likes l
                    WHERE l.participation_id = cp.id
                ),
                'comments_count', (
                    SELECT COUNT(*)
                    FROM app.challenge_comments cc
                    WHERE cc.participation_id = cp.id
                      AND cc.is_deleted = FALSE
                ),
                'reports_count', (
                    SELECT COUNT(*)
                    FROM app.challenge_reports r
                    WHERE r.participation_id = cp.id
                ),
                'pending_reports_count', (
                    SELECT COUNT(*)
                    FROM app.challenge_reports r2
                    WHERE r2.participation_id = cp.id
                      AND r2.status = 'pending'
                )
            )
            ORDER BY COALESCE(cp.submitted_at, cp.started_at) DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.is_active = TRUE
      AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
      AND c.is_active = TRUE
      AND (p_challenge_id IS NULL OR cp.challenge_id = p_challenge_id)
      AND (
        v_status_filter IS NULL
        OR LOWER(cp.moderation_status) = LOWER(v_status_filter)
      )
      AND (
        p_has_pending_reports IS NULL
        OR (
          p_has_pending_reports = TRUE AND EXISTS (
            SELECT 1 FROM app.challenge_reports r3
            WHERE r3.participation_id = cp.id
              AND r3.status = 'pending'
          )
        )
        OR (
          p_has_pending_reports = FALSE AND NOT EXISTS (
            SELECT 1 FROM app.challenge_reports r4
            WHERE r4.participation_id = cp.id
              AND r4.status = 'pending'
          )
        )
      );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_challenge_videos(UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_challenge_videos(UUID, TEXT, BOOLEAN) TO service_role;


-- 4) RPC étudiant - liste de ses vidéos multiples (challenge_participation_videos)
CREATE OR REPLACE FUNCTION app_student_list_my_challenge_videos(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
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
                -- legacy
                'video_url', v.video_url,
                'thumbnail_url', v.thumbnail_url,
                -- new
                'video_asset_id', v.video_asset_id,
                'playback', JSONB_BUILD_OBJECT(
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
                ),
                'created_at', v.created_at
            )
            ORDER BY v.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_participation_videos v
    WHERE v.participation_id = p_participation_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_challenge_videos(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_challenge_videos(UUID) TO service_role;


-- 5) RPC admin - liste des vidéos multiples (challenge_participation_videos)
CREATE OR REPLACE FUNCTION app_admin_list_challenge_participation_videos(
    p_challenge_id UUID DEFAULT NULL,
    p_participation_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', v.id,
                'participation_id', v.participation_id,
                -- legacy
                'video_url', v.video_url,
                'thumbnail_url', v.thumbnail_url,
                -- new
                'video_asset_id', v.video_asset_id,
                'playback', JSONB_BUILD_OBJECT(
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
                ),
                'created_at', v.created_at,
                'challenge_id', cp.challenge_id,
                'user_id', cp.user_id,
                'challenge_title', c.title
            )
            ORDER BY v.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_participation_videos v
    JOIN app.challenge_participations cp ON cp.id = v.participation_id
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE (p_challenge_id IS NULL OR cp.challenge_id = p_challenge_id)
      AND (p_participation_id IS NULL OR v.participation_id = p_participation_id);

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'videos', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_challenge_participation_videos(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_challenge_participation_videos(UUID, UUID) TO service_role;
