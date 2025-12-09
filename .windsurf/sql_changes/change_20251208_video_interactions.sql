-- Système générique d'interactions vidéo (likes, commentaires, signalements)
-- Utilisable pour les vidéos de challenge et les vidéos libres.

-- ========================================
-- 1) TABLES GÉNÉRIQUES D'INTERACTIONS VIDÉO
-- ========================================

CREATE TABLE IF NOT EXISTS app.video_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_type TEXT NOT NULL,
    video_id UUID NOT NULL,
    user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_likes_video_type_check CHECK (LOWER(video_type) IN ('challenge', 'free')),
    CONSTRAINT video_likes_unique_per_user UNIQUE (video_type, video_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_video_likes_video ON app.video_likes (video_type, video_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_user ON app.video_likes (user_id);

CREATE TABLE IF NOT EXISTS app.video_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_type TEXT NOT NULL,
    video_id UUID NOT NULL,
    user_id UUID NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT video_comments_video_type_check CHECK (LOWER(video_type) IN ('challenge', 'free'))
);

CREATE INDEX IF NOT EXISTS idx_video_comments_video ON app.video_comments (video_type, video_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_user ON app.video_comments (user_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_created_at ON app.video_comments (created_at);

CREATE TABLE IF NOT EXISTS app.video_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_type TEXT NOT NULL,
    video_id UUID NOT NULL,
    reporter_id UUID NOT NULL,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    handled_by_admin_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    handled_at TIMESTAMPTZ,
    CONSTRAINT video_reports_video_type_check CHECK (LOWER(video_type) IN ('challenge', 'free')),
    CONSTRAINT video_reports_status_check CHECK (LOWER(status) IN ('pending', 'resolved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_video_reports_video ON app.video_reports (video_type, video_id);
CREATE INDEX IF NOT EXISTS idx_video_reports_status ON app.video_reports (status);
CREATE INDEX IF NOT EXISTS idx_video_reports_reporter ON app.video_reports (reporter_id);


-- ========================================
-- 2) RPC ÉTUDIANT - LIKES VIDÉO GÉNÉRIQUES
-- ========================================

CREATE OR REPLACE FUNCTION app_student_video_like(
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

    -- Réutilise le bannissement challenges comme bannissement global vidéo
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

    INSERT INTO app.video_likes (video_type, video_id, user_id)
    VALUES (v_type, p_video_id, v_user_id)
    ON CONFLICT (video_type, video_id, user_id) DO NOTHING;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_video_like(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_video_like(TEXT, UUID) TO service_role;


CREATE OR REPLACE FUNCTION app_student_video_unlike(
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

    DELETE FROM app.video_likes
    WHERE video_type = v_type
      AND video_id = p_video_id
      AND user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_video_unlike(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_video_unlike(TEXT, UUID) TO service_role;


-- ========================================
-- 3) RPC ÉTUDIANT - COMMENTAIRES VIDÉO
-- ========================================

CREATE OR REPLACE FUNCTION app_student_add_video_comment(
    p_video_type TEXT,
    p_video_id UUID,
    p_content TEXT
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
    v_comment_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_type NOT IN ('challenge', 'free') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_content');
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

    INSERT INTO app.video_comments (video_type, video_id, user_id, content)
    VALUES (v_type, p_video_id, v_user_id, TRIM(p_content))
    RETURNING id INTO v_comment_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'comment_id', v_comment_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_video_comment(TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_video_comment(TEXT, UUID, TEXT) TO service_role;


CREATE OR REPLACE FUNCTION app_student_list_video_comments(
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
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_type NOT IN ('challenge', 'free') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'video_type', c.video_type,
                'video_id', c.video_id,
                'user_id', c.user_id,
                'content', c.content,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
            ORDER BY c.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.video_comments c
    WHERE c.video_type = v_type
      AND c.video_id = p_video_id
      AND c.is_deleted = FALSE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'comments', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_video_comments(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_video_comments(TEXT, UUID) TO service_role;


-- ========================================
-- 4) RPC ÉTUDIANT - SIGNALEMENTS VIDÉO
-- ========================================

CREATE OR REPLACE FUNCTION app_student_report_video(
    p_video_type TEXT,
    p_video_id UUID,
    p_reason TEXT,
    p_details TEXT
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
    v_report_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_type NOT IN ('challenge', 'free') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
    END IF;

    IF p_reason IS NULL OR LENGTH(TRIM(p_reason)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_reason');
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

    INSERT INTO app.video_reports (
        video_type,
        video_id,
        reporter_id,
        reason,
        details,
        status,
        handled_by_admin_id
    ) VALUES (
        v_type,
        p_video_id,
        v_user_id,
        TRIM(p_reason),
        NULLIF(TRIM(COALESCE(p_details, '')), ''),
        'pending',
        NULL
    )
    RETURNING id INTO v_report_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'report_id', v_report_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_report_video(TEXT, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_report_video(TEXT, UUID, TEXT, TEXT) TO service_role;
