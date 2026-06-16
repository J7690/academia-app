-- Mise à jour du workflow de modération des vidéos de challenges
-- Objectif : suppression de l’obligation d’"approved" pour la publication,
-- tout en conservant la possibilité de bloquer/supprimer a posteriori.

-- 1) Feed étudiant des vidéos de challenges

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
                'video_url', s.video_url,
                'video_renditions', s.video_renditions,
                'thumbnail_url', s.thumbnail_url,
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
              -- On exclut uniquement les vidéos explicitement bloquées/rejetées
              AND COALESCE(cp.moderation_status, 'pending') NOT IN ('blocked_ai', 'rejected')
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


-- 2) Accès à une vidéo de challenge par participation

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

    -- Le propriétaire voit toujours sa vidéo ; les autres ne voient pas les vidéos bloquées/rejetées
    IF v_owner_id <> v_user_id
       AND COALESCE(v_moderation_status, 'pending') IN ('blocked_ai', 'rejected') THEN
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
        'video_url', COALESCE(cp.video_url, cp.submission_url),
        'video_renditions', cp.video_renditions,
        'thumbnail_url', cp.thumbnail_url,
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


-- 3) Like / Favorite : autoriser toutes les vidéos non bloquées

CREATE OR REPLACE FUNCTION app_student_like_challenge_video(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_exists BOOLEAN;
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

    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_participations cp
        WHERE cp.id = p_participation_id
          AND cp.is_active = TRUE
          AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
          AND COALESCE(cp.moderation_status, 'pending') NOT IN ('blocked_ai', 'rejected')
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    INSERT INTO app.challenge_likes (participation_id, user_id)
    VALUES (p_participation_id, v_user_id)
    ON CONFLICT (participation_id, user_id) DO NOTHING;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_like_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_like_challenge_video(UUID) TO service_role;


CREATE OR REPLACE FUNCTION app_student_favorite_challenge_video(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_exists BOOLEAN;
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

    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_participations cp
        WHERE cp.id = p_participation_id
          AND cp.is_active = TRUE
          AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
          AND COALESCE(cp.moderation_status, 'pending') NOT IN ('blocked_ai', 'rejected')
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    INSERT INTO app.challenge_favorites (participation_id, user_id)
    VALUES (p_participation_id, v_user_id)
    ON CONFLICT (participation_id, user_id) DO NOTHING;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_favorite_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_favorite_challenge_video(UUID) TO service_role;
