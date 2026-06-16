-- Schéma unifié pour vidéos de challenge et vidéos libres + feed unifié
-- Conforme aux règles .windsurf : passer par admin_execute_sql via apply_one_sql_via_admin_rpc.py

-- 1) Table des vidéos de challenges (1 par challenge / user)

CREATE TABLE IF NOT EXISTS app.challenge_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID NOT NULL REFERENCES app.challenges (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    participation_id UUID REFERENCES app.challenge_participations (id) ON DELETE SET NULL,
    video_url TEXT NOT NULL,
    video_renditions JSONB,
    thumbnail_url TEXT,
    title TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    moderation_status TEXT NOT NULL DEFAULT 'published',
    moderation_flags JSONB,
    moderated_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    moderated_at TIMESTAMPTZ
);

ALTER TABLE app.challenge_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_active_challenge_videos ON app.challenge_videos;
CREATE POLICY student_select_active_challenge_videos
ON app.challenge_videos FOR SELECT
USING (
  is_active = TRUE
  AND COALESCE(moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
);

GRANT SELECT ON app.challenge_videos TO authenticated;
GRANT ALL ON app.challenge_videos TO service_role;

-- Indice pour (challenge_id, user_id) si besoin de requêtes futures
CREATE INDEX IF NOT EXISTS idx_challenge_videos_challenge_user
ON app.challenge_videos (challenge_id, user_id);


-- 2) Table des vidéos libres (free videos), non liées à un challenge

CREATE TABLE IF NOT EXISTS app.free_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    video_renditions JSONB,
    thumbnail_url TEXT,
    title TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    moderation_status TEXT NOT NULL DEFAULT 'published',
    moderation_flags JSONB,
    moderated_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    moderated_at TIMESTAMPTZ
);

ALTER TABLE app.free_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_active_free_videos ON app.free_videos;
CREATE POLICY student_select_active_free_videos
ON app.free_videos FOR SELECT
USING (
  is_active = TRUE
  AND COALESCE(moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
);

GRANT SELECT ON app.free_videos TO authenticated;
GRANT ALL ON app.free_videos TO service_role;

CREATE INDEX IF NOT EXISTS idx_free_videos_user
ON app.free_videos (user_id);


-- 3) Table des événements d'upload (journalisation)

CREATE TABLE IF NOT EXISTS app.video_upload_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    video_type TEXT NOT NULL, -- 'challenge' ou 'free' ou autre
    challenge_id UUID REFERENCES app.challenges (id) ON DELETE SET NULL,
    participation_id UUID REFERENCES app.challenge_participations (id) ON DELETE SET NULL,
    video_id UUID NOT NULL,
    source TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

GRANT SELECT, INSERT ON app.video_upload_events TO service_role;


-- 4) Table d'historique de modération

CREATE TABLE IF NOT EXISTS app.video_moderation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_type TEXT NOT NULL, -- 'challenge' ou 'free'
    video_id UUID NOT NULL,
    previous_status TEXT,
    new_status TEXT NOT NULL,
    reason TEXT,
    flags JSONB,
    moderated_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

GRANT SELECT, INSERT ON app.video_moderation_history TO service_role;


-- 5) RPC feed unifié pour l'app étudiante

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
            cv.id AS video_id,
            cv.user_id,
            cv.video_url,
            cv.video_renditions,
            cv.thumbnail_url,
            cv.title,
            cv.description,
            cv.created_at,
            cv.updated_at,
            cv.challenge_id,
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
        FROM app.challenge_videos cv
        JOIN app.challenges c ON c.id = cv.challenge_id
        LEFT JOIN app.challenge_participations cp
          ON cp.id = cv.participation_id
        WHERE cv.is_active = TRUE
          AND COALESCE(cv.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
          AND COALESCE(cv.video_url, '') <> ''
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
