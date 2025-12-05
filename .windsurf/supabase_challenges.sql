-- ========================================
-- ACADEMIA - MODULE CHALLENGES
-- Challenges (missions + concours) et participations
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE CHALLENGES
-- ========================================

CREATE TABLE IF NOT EXISTS app.challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    challenge_type TEXT NOT NULL, -- mission, contest
    difficulty TEXT,
    points INTEGER NOT NULL DEFAULT 0,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    max_participants INTEGER,
    requires_submission BOOLEAN NOT NULL DEFAULT FALSE,
    requires_admin_review BOOLEAN NOT NULL DEFAULT FALSE,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.challenges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_challenges ON app.challenges;
CREATE POLICY public_select_active_challenges
ON app.challenges FOR SELECT
USING (
  is_active = TRUE
  AND (start_at IS NULL OR start_at <= NOW())
  AND (end_at IS NULL OR end_at >= NOW())
);

GRANT SELECT ON app.challenges TO anon, authenticated;
GRANT ALL ON app.challenges TO service_role;

-- ========================================
-- 2) TABLE PARTICIPATIONS AUX CHALLENGES
-- ========================================

CREATE TABLE IF NOT EXISTS app.challenge_participations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID NOT NULL REFERENCES app.challenges (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'joined', -- joined, submitted, completed, rejected, won
    submission_text TEXT,
    submission_url TEXT,
    score INTEGER,
    rank INTEGER,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    reviewed_by_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    video_url TEXT,
    thumbnail_url TEXT,
    moderation_status TEXT NOT NULL DEFAULT 'pending',
    moderation_flags JSONB,
    moderated_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    moderated_at TIMESTAMPTZ,
    parent_participation_id UUID REFERENCES app.challenge_participations (id) ON DELETE SET NULL,
    remix_type TEXT NOT NULL DEFAULT 'none',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (challenge_id, user_id)
);

-- Migrations idempotentes pour les bases existantes où la table
-- challenge_participations a été créée avant l'ajout des colonnes vidéo / modération
ALTER TABLE app.challenge_participations
    ADD COLUMN IF NOT EXISTS video_url TEXT,
    ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
    ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS moderation_flags JSONB,
    ADD COLUMN IF NOT EXISTS moderated_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS parent_participation_id UUID REFERENCES app.challenge_participations (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS remix_type TEXT NOT NULL DEFAULT 'none';

ALTER TABLE app.challenge_participations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_challenge_participations ON app.challenge_participations;
CREATE POLICY student_select_own_challenge_participations
ON app.challenge_participations FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_challenge_participations ON app.challenge_participations;
CREATE POLICY student_insert_own_challenge_participations
ON app.challenge_participations FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_update_own_challenge_participations ON app.challenge_participations;
CREATE POLICY student_update_own_challenge_participations
ON app.challenge_participations FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.challenge_participations TO authenticated;
GRANT ALL ON app.challenge_participations TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (participation_id, user_id)
);

ALTER TABLE app.challenge_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_challenge_likes ON app.challenge_likes;
CREATE POLICY student_select_challenge_likes
ON app.challenge_likes FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS student_insert_own_challenge_likes ON app.challenge_likes;
CREATE POLICY student_insert_own_challenge_likes
ON app.challenge_likes FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_delete_own_challenge_likes ON app.challenge_likes;
CREATE POLICY student_delete_own_challenge_likes
ON app.challenge_likes FOR DELETE
USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON app.challenge_likes TO authenticated;
GRANT ALL ON app.challenge_likes TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (participation_id, user_id)
);

ALTER TABLE app.challenge_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_challenge_favorites ON app.challenge_favorites;
CREATE POLICY student_select_challenge_favorites
ON app.challenge_favorites FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS student_insert_own_challenge_favorites ON app.challenge_favorites;
CREATE POLICY student_insert_own_challenge_favorites
ON app.challenge_favorites FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_delete_own_challenge_favorites ON app.challenge_favorites;
CREATE POLICY student_delete_own_challenge_favorites
ON app.challenge_favorites FOR DELETE
USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON app.challenge_favorites TO authenticated;
GRANT ALL ON app.challenge_favorites TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.challenge_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_challenge_comments ON app.challenge_comments;
CREATE POLICY student_select_challenge_comments
ON app.challenge_comments FOR SELECT
USING (is_deleted = FALSE);

DROP POLICY IF EXISTS student_insert_own_challenge_comments ON app.challenge_comments;
CREATE POLICY student_insert_own_challenge_comments
ON app.challenge_comments FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_update_own_challenge_comments ON app.challenge_comments;
CREATE POLICY student_update_own_challenge_comments
ON app.challenge_comments FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.challenge_comments TO authenticated;
GRANT ALL ON app.challenge_comments TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    handled_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.challenge_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_challenge_reports ON app.challenge_reports;
CREATE POLICY admin_all_challenge_reports
ON app.challenge_reports
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

DROP POLICY IF EXISTS student_insert_own_challenge_reports ON app.challenge_reports;
CREATE POLICY student_insert_own_challenge_reports
ON app.challenge_reports FOR INSERT
WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS student_select_own_challenge_reports ON app.challenge_reports;
CREATE POLICY student_select_own_challenge_reports
ON app.challenge_reports FOR SELECT
USING (reporter_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON app.challenge_reports TO authenticated;
GRANT ALL ON app.challenge_reports TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_user_bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    banned_until TIMESTAMPTZ,
    created_by_admin_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

ALTER TABLE app.challenge_user_bans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_challenge_user_bans ON app.challenge_user_bans;
CREATE POLICY admin_all_challenge_user_bans
ON app.challenge_user_bans
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.challenge_user_bans TO authenticated;
GRANT ALL ON app.challenge_user_bans TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_video_overlays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    layers JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (participation_id)
);

ALTER TABLE app.challenge_video_overlays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_challenge_video_overlays ON app.challenge_video_overlays;
CREATE POLICY student_select_own_challenge_video_overlays
ON app.challenge_video_overlays FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.challenge_participations cp
    WHERE cp.id = app.challenge_video_overlays.participation_id
      AND cp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_upsert_own_challenge_video_overlays_ins ON app.challenge_video_overlays;
DROP POLICY IF EXISTS student_upsert_own_challenge_video_overlays_upd ON app.challenge_video_overlays;

CREATE POLICY student_upsert_own_challenge_video_overlays_ins
ON app.challenge_video_overlays FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.challenge_participations cp
    WHERE cp.id = app.challenge_video_overlays.participation_id
      AND cp.user_id = auth.uid()
  )
);

CREATE POLICY student_upsert_own_challenge_video_overlays_upd
ON app.challenge_video_overlays FOR UPDATE
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.challenge_participations cp
    WHERE cp.id = app.challenge_video_overlays.participation_id
      AND cp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS admin_all_challenge_video_overlays ON app.challenge_video_overlays;
CREATE POLICY admin_all_challenge_video_overlays
ON app.challenge_video_overlays
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.challenge_video_overlays TO authenticated;
GRANT ALL ON app.challenge_video_overlays TO service_role;

CREATE TABLE IF NOT EXISTS app.challenge_video_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    label TEXT NOT NULL,
    asset_url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.challenge_video_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_challenge_video_assets ON app.challenge_video_assets;
CREATE POLICY public_select_active_challenge_video_assets
ON app.challenge_video_assets FOR SELECT
USING (is_active = TRUE);

DROP POLICY IF EXISTS admin_all_challenge_video_assets ON app.challenge_video_assets;
CREATE POLICY admin_all_challenge_video_assets
ON app.challenge_video_assets
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT ON app.challenge_video_assets TO anon, authenticated;
GRANT ALL ON app.challenge_video_assets TO service_role;

-- ========================================
-- 3) RPC ÉTUDIANT - LISTE DES CHALLENGES
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_challenges(
    p_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_only_joined BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'slug', c.slug,
                'title', c.title,
                'description', c.description,
                'challenge_type', c.challenge_type,
                'difficulty', c.difficulty,
                'points', c.points,
                'start_at', c.start_at,
                'end_at', c.end_at,
                'max_participants', c.max_participants,
                'requires_submission', c.requires_submission,
                'requires_admin_review', c.requires_admin_review,
                'is_featured', c.is_featured,
                'is_active', c.is_active,
                'created_at', c.created_at,
                'updated_at', c.updated_at,
                'participants_count', COALESCE(
                    (
                        SELECT COUNT(*)
                        FROM app.challenge_participations cp
                        WHERE cp.challenge_id = c.id
                          AND cp.is_active = TRUE
                    ),
                    0
                ),
                'is_joined', EXISTS (
                    SELECT 1
                    FROM app.challenge_participations cp2
                    WHERE cp2.challenge_id = c.id
                      AND cp2.user_id = v_user_id
                      AND cp2.is_active = TRUE
                ),
                'my_status', (
                    SELECT cp3.status
                    FROM app.challenge_participations cp3
                    WHERE cp3.challenge_id = c.id
                      AND cp3.user_id = v_user_id
                      AND cp3.is_active = TRUE
                    LIMIT 1
                ),
                'my_score', (
                    SELECT cp4.score
                    FROM app.challenge_participations cp4
                    WHERE cp4.challenge_id = c.id
                      AND cp4.user_id = v_user_id
                      AND cp4.is_active = TRUE
                    LIMIT 1
                )
            )
            ORDER BY c.is_featured DESC, c.start_at NULLS LAST, c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenges c
    WHERE c.is_active = TRUE
      AND (c.start_at IS NULL OR c.start_at <= NOW())
      AND (c.end_at IS NULL OR c.end_at >= NOW())
      AND (v_type IS NULL OR LOWER(c.challenge_type) = LOWER(v_type))
      AND (
        v_search IS NULL
        OR c.title ILIKE '%' || v_search || '%'
        OR c.description ILIKE '%' || v_search || '%'
      )
      AND (
        NOT p_only_joined
        OR EXISTS (
            SELECT 1
            FROM app.challenge_participations cpj
            WHERE cpj.challenge_id = c.id
              AND cpj.user_id = v_user_id
              AND cpj.is_active = TRUE
        )
      );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'challenges', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_challenges(TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_challenges(TEXT, TEXT, BOOLEAN) TO service_role;

-- ========================================
-- 4) RPC ÉTUDIANT - MES PARTICIPATIONS
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_challenge_participations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'participation_id', cp.id,
                'challenge_id', c.id,
                'slug', c.slug,
                'title', c.title,
                'challenge_type', c.challenge_type,
                'difficulty', c.difficulty,
                'points', c.points,
                'status', cp.status,
                'score', cp.score,
                'rank', cp.rank,
                'started_at', cp.started_at,
                'submitted_at', cp.submitted_at,
                'completed_at', cp.completed_at
            )
            ORDER BY cp.started_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.user_id = v_user_id
      AND cp.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participations', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_challenge_participations() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_challenge_participations() TO service_role;

-- ========================================
-- 5) RPC ÉTUDIANT - STATISTIQUES PERSONNELLES
-- ========================================

CREATE OR REPLACE FUNCTION app_student_get_my_challenge_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_total_joined INTEGER := 0;
    v_total_completed INTEGER := 0;
    v_total_points INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE cp.is_active = TRUE) AS total_joined,
        COUNT(*) FILTER (WHERE cp.is_active = TRUE AND cp.status IN ('completed', 'won')) AS total_completed,
        COALESCE(SUM(
            CASE
                WHEN cp.is_active = TRUE AND cp.status IN ('completed', 'won')
                    THEN COALESCE(cp.score, c.points, 0)
                ELSE 0
            END
        ), 0) AS total_points
    INTO v_total_joined, v_total_completed, v_total_points
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'stats', JSONB_BUILD_OBJECT(
            'total_joined', COALESCE(v_total_joined, 0),
            'total_completed', COALESCE(v_total_completed, 0),
            'total_points', COALESCE(v_total_points, 0)
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_get_my_challenge_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_get_my_challenge_stats() TO service_role;

-- ========================================
-- 6) RPC ÉTUDIANT - REJOINDRE / SOUMETTRE / COMPLETER
-- ========================================

CREATE OR REPLACE FUNCTION app_student_join_challenge(
    p_challenge_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_max_participants INTEGER;
    v_current_participants INTEGER;
    v_participation_id UUID;
    v_is_banned BOOLEAN;
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

    SELECT
        c.max_participants,
        (
            SELECT COUNT(*)
            FROM app.challenge_participations cp
            WHERE cp.challenge_id = c.id
              AND cp.is_active = TRUE
        ) AS current_participants
    INTO v_max_participants, v_current_participants
    FROM app.challenges c
    WHERE c.id = p_challenge_id
      AND c.is_active = TRUE
      AND (c.start_at IS NULL OR c.start_at <= NOW())
      AND (c.end_at IS NULL OR c.end_at >= NOW());

    IF v_max_participants IS NULL AND v_current_participants IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'challenge_not_joinable');
    END IF;

    IF v_max_participants IS NOT NULL AND v_current_participants >= v_max_participants THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'max_participants_reached');
    END IF;

    INSERT INTO app.challenge_participations (challenge_id, user_id, status, is_active, started_at)
    VALUES (p_challenge_id, v_user_id, 'joined', TRUE, NOW())
    ON CONFLICT (challenge_id, user_id) DO UPDATE
        SET is_active = TRUE,
            status = 'joined',
            started_at = NOW()
    RETURNING id INTO v_participation_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participation_id', v_participation_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_join_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_join_challenge(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_submit_challenge(
    p_participation_id UUID,
    p_submission_text TEXT,
    p_submission_url TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_challenge_id UUID;
    v_requires_submission BOOLEAN;
    v_requires_admin_review BOOLEAN;
    v_new_status TEXT;
    v_is_banned BOOLEAN;
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

    SELECT
        cp.challenge_id,
        c.requires_submission,
        c.requires_admin_review
    INTO v_challenge_id, v_requires_submission, v_requires_admin_review
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.id = p_participation_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE;

    IF v_challenge_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    IF (p_submission_text IS NULL OR LENGTH(TRIM(p_submission_text)) = 0)
       AND (p_submission_url IS NULL OR LENGTH(TRIM(p_submission_url)) = 0) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_submission');
    END IF;

    IF v_requires_admin_review THEN
        v_new_status := 'submitted';
    ELSE
        v_new_status := 'completed';
    END IF;

    UPDATE app.challenge_participations cp
    SET
        submission_text = TRIM(COALESCE(p_submission_text, '')),
        submission_url = NULLIF(TRIM(COALESCE(p_submission_url, '')), ''),
        video_url = NULLIF(TRIM(COALESCE(p_submission_url, '')), ''),
        moderation_status = 'pending',
        moderation_flags = NULL,
        moderated_by_admin_id = NULL,
        moderated_at = NULL,
        status = v_new_status,
        submitted_at = NOW(),
        completed_at = CASE
            WHEN v_new_status = 'completed' THEN COALESCE(cp.completed_at, NOW())
            ELSE cp.completed_at
        END,
        score = CASE
            WHEN v_new_status = 'completed' THEN COALESCE(cp.score, (
                SELECT c2.points FROM app.challenges c2 WHERE c2.id = v_challenge_id
            ), 0)
            ELSE cp.score
        END
    WHERE cp.id = p_participation_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participation_id', p_participation_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_submit_challenge(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_submit_challenge(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_student_mark_challenge_completed(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_challenge_id UUID;
    v_requires_admin_review BOOLEAN;
    v_is_banned BOOLEAN;
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

    SELECT
        cp.challenge_id,
        c.requires_admin_review
    INTO v_challenge_id, v_requires_admin_review
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.id = p_participation_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE;

    IF v_challenge_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    IF v_requires_admin_review THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'requires_admin_review');
    END IF;

    UPDATE app.challenge_participations cp
    SET
        status = 'completed',
        completed_at = COALESCE(cp.completed_at, NOW()),
        score = COALESCE(cp.score, (
            SELECT c2.points FROM app.challenges c2 WHERE c2.id = v_challenge_id
        ), 0)
    WHERE cp.id = p_participation_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participation_id', p_participation_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_mark_challenge_completed(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_mark_challenge_completed(UUID) TO service_role;

-- ========================================
-- 6 bis) RPC ÉTUDIANT - VIDÉOS DE CHALLENGES
-- ========================================

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

CREATE OR REPLACE FUNCTION app_student_start_duo_challenge_video(
    p_parent_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_parent_challenge_id UUID;
    v_participation_id UUID;
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

    SELECT
        cp.challenge_id
    INTO v_parent_challenge_id
    FROM app.challenge_participations cp
    WHERE cp.id = p_parent_participation_id
      AND cp.is_active = TRUE
      AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
      AND cp.moderation_status = 'approved';

    IF v_parent_challenge_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'parent_video_not_found');
    END IF;

    INSERT INTO app.challenge_participations (
        challenge_id,
        user_id,
        status,
        is_active,
        started_at,
        parent_participation_id,
        remix_type
    )
    VALUES (
        v_parent_challenge_id,
        v_user_id,
        'joined',
        TRUE,
        NOW(),
        p_parent_participation_id,
        'duo'
    )
    ON CONFLICT (challenge_id, user_id) DO UPDATE
        SET is_active = TRUE,
            status = 'joined',
            started_at = NOW(),
            parent_participation_id = EXCLUDED.parent_participation_id,
            remix_type = EXCLUDED.remix_type
    RETURNING id INTO v_participation_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'participation_id', v_participation_id,
        'challenge_id', v_parent_challenge_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_start_duo_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_start_duo_challenge_video(UUID) TO service_role;

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
        'video_url', COALESCE(cp.video_url, cp.submission_url),
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

-- ========================================
-- 6 ter) RPC ÉTUDIANT - INTERACTIONS VIDÉOS
-- ========================================

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
          AND cp.moderation_status = 'approved'
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

CREATE OR REPLACE FUNCTION app_student_unlike_challenge_video(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
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

    DELETE FROM app.challenge_likes
    WHERE participation_id = p_participation_id
      AND user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_unlike_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_unlike_challenge_video(UUID) TO service_role;

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
          AND cp.moderation_status = 'approved'
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

CREATE OR REPLACE FUNCTION app_student_unfavorite_challenge_video(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
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

    DELETE FROM app.challenge_favorites
    WHERE participation_id = p_participation_id
      AND user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_unfavorite_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_unfavorite_challenge_video(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_add_challenge_comment(
    p_participation_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_participation_exists BOOLEAN;
    v_comment_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
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

    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_participations cp
        WHERE cp.id = p_participation_id
          AND cp.is_active = TRUE
          AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
    ) INTO v_participation_exists;

    IF NOT v_participation_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    INSERT INTO app.challenge_comments (participation_id, user_id, content)
    VALUES (p_participation_id, v_user_id, TRIM(p_content))
    RETURNING id INTO v_comment_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'comment_id', v_comment_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_challenge_comment(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_challenge_comment(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_student_list_challenge_comments(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'participation_id', c.participation_id,
                'user_id', c.user_id,
                'content', c.content,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
            ORDER BY c.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_comments c
    WHERE c.participation_id = p_participation_id
      AND c.is_deleted = FALSE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'comments', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_challenge_comments(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_challenge_comments(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_report_challenge_video(
    p_participation_id UUID,
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
    v_participation_exists BOOLEAN;
    v_report_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
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

    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_participations cp
        WHERE cp.id = p_participation_id
          AND cp.is_active = TRUE
          AND COALESCE(cp.video_url, cp.submission_url) IS NOT NULL
    ) INTO v_participation_exists;

    IF NOT v_participation_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    INSERT INTO app.challenge_reports (
        participation_id,
        reporter_id,
        reason,
        details,
        status,
        handled_by_admin_id
    ) VALUES (
        p_participation_id,
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

GRANT EXECUTE ON FUNCTION app_student_report_challenge_video(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_report_challenge_video(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_student_update_challenge_video_overlays(
    p_participation_id UUID,
    p_layers JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
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

    IF p_layers IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_layers');
    END IF;

    INSERT INTO app.challenge_video_overlays (participation_id, layers)
    VALUES (p_participation_id, p_layers)
    ON CONFLICT (participation_id) DO UPDATE
    SET
        layers = EXCLUDED.layers,
        updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_update_challenge_video_overlays(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_update_challenge_video_overlays(UUID, JSONB) TO service_role;

-- ========================================
-- 7) RPC PUBLIC - LEADERBOARD D'UN CHALLENGE
-- ========================================

CREATE OR REPLACE FUNCTION app_public_get_challenge_leaderboard(
    p_challenge_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'user_id', cp.user_id,
                'score', cp.score,
                'rank', cp.rank,
                'status', cp.status,
                'completed_at', cp.completed_at
            )
            ORDER BY cp.score DESC NULLS LAST,
                     cp.rank ASC NULLS LAST,
                     cp.completed_at ASC NULLS LAST
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_participations cp
    WHERE cp.challenge_id = p_challenge_id
      AND cp.is_active = TRUE
      AND cp.status IN ('completed', 'won');

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'leaderboard', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_get_challenge_leaderboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_public_get_challenge_leaderboard(UUID) TO service_role;

-- ========================================
-- 8) RPC ADMIN - GESTION DES CHALLENGES
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_challenges()
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
                'id', c.id,
                'slug', c.slug,
                'title', c.title,
                'description', c.description,
                'challenge_type', c.challenge_type,
                'difficulty', c.difficulty,
                'points', c.points,
                'start_at', c.start_at,
                'end_at', c.end_at,
                'max_participants', c.max_participants,
                'requires_submission', c.requires_submission,
                'requires_admin_review', c.requires_admin_review,
                'is_featured', c.is_featured,
                'is_active', c.is_active,
                'created_by_user_id', c.created_by_user_id,
                'created_at', c.created_at,
                'updated_at', c.updated_at,
                'participants_count', COALESCE(
                    (
                        SELECT COUNT(*)
                        FROM app.challenge_participations cp
                        WHERE cp.challenge_id = c.id
                          AND cp.is_active = TRUE
                    ),
                    0
                ),
                'completed_count', COALESCE(
                    (
                        SELECT COUNT(*)
                        FROM app.challenge_participations cp2
                        WHERE cp2.challenge_id = c.id
                          AND cp2.is_active = TRUE
                          AND cp2.status IN ('completed', 'won')
                    ),
                    0
                ),
                'average_score', (
                    SELECT AVG(cp3.score)::DOUBLE PRECISION
                    FROM app.challenge_participations cp3
                    WHERE cp3.challenge_id = c.id
                      AND cp3.is_active = TRUE
                      AND cp3.score IS NOT NULL
                )
            )
            ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenges c;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'challenges', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_challenges() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_challenge(
    p_challenge_id UUID,
    p_slug TEXT,
    p_title TEXT,
    p_description TEXT,
    p_challenge_type TEXT,
    p_difficulty TEXT,
    p_points INTEGER,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ,
    p_max_participants INTEGER,
    p_requires_submission BOOLEAN,
    p_requires_admin_review BOOLEAN,
    p_is_active BOOLEAN,
    p_is_featured BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_slug TEXT := NULLIF(TRIM(COALESCE(p_slug, '')), '');
    v_title TEXT := NULLIF(TRIM(COALESCE(p_title, '')), '');
    v_type TEXT := LOWER(TRIM(COALESCE(p_challenge_type, 'mission')));
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

    IF v_title IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF v_slug IS NULL THEN
        v_slug := LOWER(REGEXP_REPLACE(v_title, '[^a-zA-Z0-9]+', '-', 'g'));
    END IF;

    IF v_type NOT IN ('mission', 'contest') THEN
        v_type := 'mission';
    END IF;

    IF p_challenge_id IS NULL THEN
        INSERT INTO app.challenges (
            slug,
            title,
            description,
            challenge_type,
            difficulty,
            points,
            start_at,
            end_at,
            max_participants,
            requires_submission,
            requires_admin_review,
            is_active,
            is_featured,
            created_by_user_id
        )
        VALUES (
            v_slug,
            v_title,
            p_description,
            v_type,
            p_difficulty,
            COALESCE(p_points, 0),
            p_start_at,
            p_end_at,
            p_max_participants,
            COALESCE(p_requires_submission, FALSE),
            COALESCE(p_requires_admin_review, FALSE),
            COALESCE(p_is_active, TRUE),
            COALESCE(p_is_featured, FALSE),
            v_user_id
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.challenges
        SET
            slug = v_slug,
            title = v_title,
            description = p_description,
            challenge_type = v_type,
            difficulty = p_difficulty,
            points = COALESCE(p_points, points),
            start_at = p_start_at,
            end_at = p_end_at,
            max_participants = p_max_participants,
            requires_submission = COALESCE(p_requires_submission, requires_submission),
            requires_admin_review = COALESCE(p_requires_admin_review, requires_admin_review),
            is_active = COALESCE(p_is_active, is_active),
            is_featured = COALESCE(p_is_featured, is_featured),
            updated_at = NOW()
        WHERE id = p_challenge_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'challenge_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'challenge_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_challenge(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_challenge(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_update_challenge_status(
    p_challenge_id UUID,
    p_is_active BOOLEAN,
    p_is_featured BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
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

    UPDATE app.challenges
    SET
        is_active = COALESCE(p_is_active, is_active),
        is_featured = COALESCE(p_is_featured, is_featured),
        updated_at = NOW()
    WHERE id = p_challenge_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'challenge_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'challenge_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_challenge_status(UUID, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_challenge_status(UUID, BOOLEAN, BOOLEAN) TO service_role;

-- ========================================
-- 9) RPC ADMIN - PARTICIPATIONS & CLASSEMENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_challenge_participations(
    p_challenge_id UUID
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
                'id', cp.id,
                'challenge_id', cp.challenge_id,
                'user_id', cp.user_id,
                'status', cp.status,
                'submission_text', cp.submission_text,
                'submission_url', cp.submission_url,
                'score', cp.score,
                'rank', cp.rank,
                'started_at', cp.started_at,
                'submitted_at', cp.submitted_at,
                'completed_at', cp.completed_at,
                'reviewed_at', cp.reviewed_at,
                'reviewed_by_user_id', cp.reviewed_by_user_id
            )
            ORDER BY cp.started_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_participations cp
    WHERE cp.challenge_id = p_challenge_id
      AND cp.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participations', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_challenge_participations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_challenge_participations(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_review_challenge_participation(
    p_participation_id UUID,
    p_status TEXT,
    p_score INTEGER,
    p_rank INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_status TEXT := LOWER(TRIM(COALESCE(p_status, '')));
    v_challenge_id UUID;
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

    IF v_status NOT IN ('completed', 'rejected', 'won') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    SELECT challenge_id
    INTO v_challenge_id
    FROM app.challenge_participations
    WHERE id = p_participation_id
      AND is_active = TRUE;

    IF v_challenge_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    UPDATE app.challenge_participations cp
    SET
        status = v_status,
        score = COALESCE(p_score, cp.score),
        rank = COALESCE(p_rank, cp.rank),
        completed_at = CASE
            WHEN v_status IN ('completed', 'won') THEN COALESCE(cp.completed_at, NOW())
            ELSE cp.completed_at
        END,
        reviewed_at = NOW(),
        reviewed_by_user_id = v_user_id
    WHERE cp.id = p_participation_id
      AND cp.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participation_id', p_participation_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_review_challenge_participation(UUID, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_review_challenge_participation(UUID, TEXT, INTEGER, INTEGER) TO service_role;

-- ========================================
-- 10) RPC ADMIN - VIDÉOS DE CHALLENGES
-- ========================================

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
                'video_url', COALESCE(cp.video_url, cp.submission_url),
                'thumbnail_url', cp.thumbnail_url,
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

CREATE OR REPLACE FUNCTION app_admin_review_challenge_video(
    p_participation_id UUID,
    p_moderation_status TEXT,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_status TEXT := LOWER(TRIM(COALESCE(p_moderation_status, '')));
    v_participation_id UUID;
    v_flags JSONB;
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

    IF v_status NOT IN ('approved', 'rejected', 'blocked_ai') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    SELECT moderation_flags
    INTO v_flags
    FROM app.challenge_participations
    WHERE id = p_participation_id
      AND is_active = TRUE;

    IF v_flags IS NULL THEN
        v_flags := '{}'::JSONB;
    END IF;

    IF p_reason IS NOT NULL AND LENGTH(TRIM(p_reason)) > 0 THEN
        v_flags := v_flags || JSONB_BUILD_OBJECT('last_reason', TRIM(p_reason));
    END IF;

    UPDATE app.challenge_participations cp
    SET
        moderation_status = v_status,
        moderation_flags = v_flags,
        moderated_by_admin_id = v_user_id,
        moderated_at = NOW(),
        is_active = CASE
            WHEN v_status IN ('rejected', 'blocked_ai') THEN FALSE
            ELSE is_active
        END
    WHERE cp.id = p_participation_id
    RETURNING id INTO v_participation_id;

    IF v_participation_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participation_id', v_participation_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_review_challenge_video(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_review_challenge_video(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_challenge_video(
    p_participation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_participation_id UUID;
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

    UPDATE app.challenge_participations cp
    SET
        is_active = FALSE,
        moderation_status = CASE
            WHEN moderation_status IS NULL OR moderation_status = 'pending' THEN 'rejected'
            ELSE moderation_status
        END,
        moderated_by_admin_id = COALESCE(moderated_by_admin_id, v_user_id),
        moderated_at = COALESCE(moderated_at, NOW()),
        status = CASE
            WHEN status IN ('submitted', 'joined') THEN 'rejected'
            ELSE status
        END
    WHERE cp.id = p_participation_id
    RETURNING id INTO v_participation_id;

    IF v_participation_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participation_id', v_participation_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_challenge_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_challenge_video(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_ban_user_from_challenges(
    p_user_id UUID,
    p_reason TEXT,
    p_banned_until TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_ban_id UUID;
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

    IF p_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_user');
    END IF;

    IF p_reason IS NULL OR LENGTH(TRIM(p_reason)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_reason');
    END IF;

    INSERT INTO app.challenge_user_bans (user_id, reason, banned_until, created_by_admin_id)
    VALUES (p_user_id, TRIM(p_reason), p_banned_until, v_user_id)
    ON CONFLICT (user_id) DO UPDATE
    SET
        reason = EXCLUDED.reason,
        banned_until = EXCLUDED.banned_until,
        created_by_admin_id = EXCLUDED.created_by_admin_id,
        created_at = NOW()
    RETURNING id INTO v_ban_id;

    UPDATE app.challenge_participations
    SET is_active = FALSE
    WHERE user_id = p_user_id
      AND is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'ban_id', v_ban_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_ban_user_from_challenges(UUID, TEXT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_ban_user_from_challenges(UUID, TEXT, TIMESTAMPTZ) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_challenge_reports(
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_status_filter TEXT := NULLIF(TRIM(COALESCE(p_status, '')), '');
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
                'id', r.id,
                'participation_id', r.participation_id,
                'reporter_id', r.reporter_id,
                'reason', r.reason,
                'details', r.details,
                'status', r.status,
                'handled_by_admin_id', r.handled_by_admin_id,
                'created_at', r.created_at,
                'updated_at', r.updated_at,
                'challenge_id', cp.challenge_id,
                'challenge_title', c.title,
                'video_url', COALESCE(cp.video_url, cp.submission_url)
            )
            ORDER BY r.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_reports r
    JOIN app.challenge_participations cp ON cp.id = r.participation_id
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE (v_status_filter IS NULL OR r.status = v_status_filter);

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'reports', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_challenge_reports(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_challenge_reports(TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_update_challenge_report_status(
    p_report_id UUID,
    p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_status TEXT := LOWER(TRIM(COALESCE(p_status, '')));
    v_id UUID;
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

    IF v_status NOT IN ('pending', 'reviewed', 'dismissed') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    UPDATE app.challenge_reports
    SET
        status = v_status,
        handled_by_admin_id = v_user_id,
        updated_at = NOW()
    WHERE id = p_report_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'report_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'report_id', v_id, 'status', v_status);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_challenge_report_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_challenge_report_status(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_challenge_video_assets()
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
                'id', a.id,
                'category', a.category,
                'label', a.label,
                'asset_url', a.asset_url,
                'is_active', a.is_active,
                'created_at', a.created_at,
                'updated_at', a.updated_at
            )
            ORDER BY a.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_video_assets a;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'assets', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_challenge_video_assets() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_challenge_video_assets() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_challenge_video_asset(
    p_asset_id UUID,
    p_category TEXT,
    p_label TEXT,
    p_asset_url TEXT,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_category TEXT := NULLIF(TRIM(COALESCE(p_category, '')), '');
    v_label TEXT := NULLIF(TRIM(COALESCE(p_label, '')), '');
    v_asset_url TEXT := NULLIF(TRIM(COALESCE(p_asset_url, '')), '');
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

    IF v_category IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_category');
    END IF;

    IF v_label IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_label');
    END IF;

    IF v_asset_url IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_asset_url');
    END IF;

    IF p_asset_id IS NULL THEN
        INSERT INTO app.challenge_video_assets (
            category,
            label,
            asset_url,
            is_active
        ) VALUES (
            v_category,
            v_label,
            v_asset_url,
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.challenge_video_assets
        SET
            category = v_category,
            label = v_label,
            asset_url = v_asset_url,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_asset_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'asset_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'asset_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_challenge_video_asset(UUID, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_challenge_video_asset(UUID, TEXT, TEXT, TEXT, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_challenge_video_asset(
    p_asset_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
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

    UPDATE app.challenge_video_assets
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_asset_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'asset_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'asset_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_challenge_video_asset(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_challenge_video_asset(UUID) TO service_role;

-- ========================================
-- 11) TABLE & RPC ÉTUDIANT - VIDÉOS MULTIPLES PAR PARTICIPATION
-- ========================================

CREATE TABLE IF NOT EXISTS app.challenge_participation_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.challenge_participation_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_challenge_participation_videos ON app.challenge_participation_videos;
CREATE POLICY student_select_own_challenge_participation_videos
ON app.challenge_participation_videos FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.challenge_participations cp
    WHERE cp.id = app.challenge_participation_videos.participation_id
      AND cp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_own_challenge_participation_videos ON app.challenge_participation_videos;
CREATE POLICY student_insert_own_challenge_participation_videos
ON app.challenge_participation_videos FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.challenge_participations cp
    WHERE cp.id = app.challenge_participation_videos.participation_id
      AND cp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS admin_all_challenge_participation_videos ON app.challenge_participation_videos;
CREATE POLICY admin_all_challenge_participation_videos
ON app.challenge_participation_videos
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.challenge_participation_videos TO authenticated;
GRANT ALL ON app.challenge_participation_videos TO service_role;

CREATE OR REPLACE FUNCTION app_student_add_challenge_video(
    p_participation_id UUID,
    p_video_url TEXT,
    p_thumbnail_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
    v_url_trim TEXT;
    v_video_id UUID;
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

    v_url_trim := NULLIF(TRIM(COALESCE(p_video_url, '')), '');
    IF v_url_trim IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_url');
    END IF;

    INSERT INTO app.challenge_participation_videos (
        participation_id,
        video_url,
        thumbnail_url
    ) VALUES (
        p_participation_id,
        v_url_trim,
        NULLIF(TRIM(COALESCE(p_thumbnail_url, '')), '')
    )
    RETURNING id INTO v_video_id;

    IF v_video_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_id', v_video_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_challenge_video(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_challenge_video(UUID, TEXT, TEXT) TO service_role;

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
                'video_url', v.video_url,
                'thumbnail_url', v.thumbnail_url,
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

CREATE OR REPLACE FUNCTION app_student_set_challenge_main_video(
    p_participation_id UUID,
    p_video_url TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
    v_url_trim TEXT;
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

    v_url_trim := NULLIF(TRIM(COALESCE(p_video_url, '')), '');
    IF v_url_trim IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_url');
    END IF;

    UPDATE app.challenge_participations cp
    SET video_url = v_url_trim
    WHERE cp.id = p_participation_id
      AND cp.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_set_challenge_main_video(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_set_challenge_main_video(UUID, TEXT) TO service_role;

-- ========================================
-- 12) RPC ADMIN - VIDÉOS MULTIPLES PAR PARTICIPATION
-- ========================================

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
                'video_url', v.video_url,
                'thumbnail_url', v.thumbnail_url,
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

CREATE OR REPLACE FUNCTION app_admin_delete_challenge_participation_video(
    p_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
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

    DELETE FROM app.challenge_participation_videos
    WHERE id = p_video_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_challenge_participation_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_challenge_participation_video(UUID) TO service_role;

-- ========================================
-- 13) TABLE & RPC ÉTUDIANT - JOBS DE RENDU VIDÉO
-- ========================================

CREATE TABLE IF NOT EXISTS app.challenge_video_render_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES app.challenge_participations (id) ON DELETE CASCADE,
    job_type TEXT NOT NULL,
    status TEXT NOT NULL,
    source_video_url TEXT,
    result_video_url TEXT,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

ALTER TABLE app.challenge_video_render_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_challenge_video_render_jobs ON app.challenge_video_render_jobs;
CREATE POLICY student_select_own_challenge_video_render_jobs
ON app.challenge_video_render_jobs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.challenge_participations cp
    WHERE cp.id = app.challenge_video_render_jobs.participation_id
      AND cp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS admin_all_challenge_video_render_jobs ON app.challenge_video_render_jobs;
CREATE POLICY admin_all_challenge_video_render_jobs
ON app.challenge_video_render_jobs
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT ON app.challenge_video_render_jobs TO authenticated;
GRANT ALL ON app.challenge_video_render_jobs TO service_role;

CREATE OR REPLACE FUNCTION app_student_list_challenge_video_render_jobs(
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
                'id', j.id,
                'participation_id', j.participation_id,
                'job_type', j.job_type,
                'status', j.status,
                'source_video_url', j.source_video_url,
                'result_video_url', j.result_video_url,
                'error_message', j.error_message,
                'metadata', j.metadata,
                'created_at', j.created_at,
                'started_at', j.started_at,
                'completed_at', j.completed_at
            )
            ORDER BY j.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.challenge_video_render_jobs j
    WHERE j.participation_id = p_participation_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'jobs', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_challenge_video_render_jobs(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_challenge_video_render_jobs(UUID) TO service_role;
