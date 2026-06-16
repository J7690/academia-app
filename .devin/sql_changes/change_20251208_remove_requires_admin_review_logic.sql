-- Suppression du workflow d'approbation admin pour les challenges
-- On garde la modération a posteriori (delete / block) mais on ne bloque plus
-- la complétion ni la publication sur requires_admin_review.

-- 1) app_student_submit_challenge : toujours marquer comme 'completed',
--    et marquer la vidéo comme 'published' côté moderation_status.

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
        c.requires_submission
    INTO v_challenge_id, v_requires_submission
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

    -- Plus de validation admin : la soumission complète directement le challenge
    v_new_status := 'completed';

    UPDATE app.challenge_participations cp
    SET
        submission_text = TRIM(COALESCE(p_submission_text, '')),
        submission_url = NULLIF(TRIM(COALESCE(p_submission_url, '')), ''),
        video_url = NULLIF(TRIM(COALESCE(p_submission_url, '')), ''),
        moderation_status = 'published',
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


-- 2) app_student_mark_challenge_completed : ne plus bloquer sur requires_admin_review.

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
        cp.challenge_id
    INTO v_challenge_id
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.id = p_participation_id
      AND cp.user_id = v_user_id
      AND cp.is_active = TRUE;

    IF v_challenge_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participation_not_found');
    END IF;

    -- Plus de blocage "requires_admin_review" : l'étudiant peut marquer comme complété.
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


-- 3) app_admin_upsert_challenge : forcer requires_admin_review à FALSE pour tous
--    les challenges (colonne conservée mais neutralisée).

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
            FALSE, -- requires_admin_review neutralisé
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
            requires_admin_review = FALSE, -- toujours FALSE désormais
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
