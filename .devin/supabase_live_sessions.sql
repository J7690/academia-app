-- ========================================
-- ACADEMIA - MODULE LIVES COURS EN LIGNE
-- Extension du module online_courses pour la gestion des sessions live
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) EXTENSION DE app.online_course_live_sessions
-- ========================================

ALTER TABLE app.online_course_live_sessions
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft',
    ADD COLUMN IF NOT EXISTS host_id UUID REFERENCES app.instructors (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS livekit_room_name TEXT,
    ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL;

-- ========================================
-- 2) TABLE PARTICIPANTS DES LIVES
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_live_session_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.online_course_live_sessions (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('student', 'instructor', 'admin')),
    livekit_identity TEXT,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.online_course_live_session_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_online_course_live_session_participants ON app.online_course_live_session_participants;
CREATE POLICY admin_all_online_course_live_session_participants
ON app.online_course_live_session_participants
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

GRANT SELECT, INSERT, UPDATE, DELETE ON app.online_course_live_session_participants TO authenticated;
GRANT ALL ON app.online_course_live_session_participants TO service_role;

-- ========================================
-- 3) RPC ADMIN - LISTE DES LIVES
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_online_course_live_sessions(
    p_status TEXT DEFAULT NULL,
    p_course_id UUID DEFAULT NULL,
    p_instructor_id UUID DEFAULT NULL
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
                'id', s.id,
                'course_id', s.course_id,
                'course_title', c.title,
                'host_id', s.host_id,
                'title', s.title,
                'description', s.description,
                'provider', s.provider,
                'join_url', s.join_url,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'started_at', s.started_at,
                'ended_at', s.ended_at,
                'status', s.status,
                'replay_video_url', s.replay_video_url,
                'is_active', s.is_active,
                'created_at', s.created_at,
                'updated_at', s.updated_at
            )
            ORDER BY s.start_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_live_sessions s
    JOIN app.online_courses c ON c.id = s.course_id
    WHERE (p_status IS NULL OR s.status = p_status)
      AND (p_course_id IS NULL OR s.course_id = p_course_id)
      AND (
        p_instructor_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM app.online_course_instructors ci
          WHERE ci.course_id = s.course_id
            AND ci.instructor_id = p_instructor_id
        )
      );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_online_course_live_sessions(TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_online_course_live_sessions(TEXT, UUID, UUID) TO service_role;

-- ========================================
-- 4) RPC ADMIN - MISE À JOUR DU STATUT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_update_online_course_live_session_status(
    p_session_id UUID,
    p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_old_status TEXT;
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

    IF p_status NOT IN ('approved', 'rejected', 'cancelled', 'ended') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    SELECT status INTO v_old_status
    FROM app.online_course_live_sessions
    WHERE id = p_session_id;

    IF v_old_status IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    -- Transitions simples, la logique fine pourra être enrichie si besoin
    UPDATE app.online_course_live_sessions
    SET status = p_status,
        approved_by_admin_id = CASE WHEN p_status = 'approved' THEN v_user_id ELSE approved_by_admin_id END,
        ended_at = CASE WHEN p_status = 'ended' THEN NOW() ELSE ended_at END,
        updated_at = NOW()
    WHERE id = p_session_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'session_id', p_session_id, 'status', p_status);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_online_course_live_session_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_online_course_live_session_status(UUID, TEXT) TO service_role;

-- ========================================
-- 5) RPC ADMIN - PARTICIPANTS & BANNISSEMENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_online_course_live_session_participants(
    p_session_id UUID
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
          'id', p.id,
          'user_id', p.user_id,
          'role', p.role,
          'livekit_identity', p.livekit_identity,
          'joined_at', p.joined_at,
          'left_at', p.left_at,
          'is_banned', p.is_banned
        )
        ORDER BY p.joined_at DESC
      ),
      '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_live_session_participants p
    WHERE p.session_id = p_session_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participants', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_online_course_live_session_participants(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_online_course_live_session_participants(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_ban_user_from_online_course_live_session(
    p_session_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_participant_id UUID;
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

    UPDATE app.online_course_live_session_participants
    SET is_banned = TRUE,
        left_at = COALESCE(left_at, NOW())
    WHERE session_id = p_session_id
      AND user_id = p_user_id
    RETURNING id INTO v_participant_id;

    IF v_participant_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'participant_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'participant_id', v_participant_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_ban_user_from_online_course_live_session(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_ban_user_from_online_course_live_session(UUID, UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_get_live_session_participant_livekit_identity(
    p_session_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_course_id UUID;
    v_room_name TEXT;
    v_identity TEXT;
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

    SELECT s.course_id, s.livekit_room_name
    INTO v_course_id, v_room_name
    FROM app.online_course_live_sessions s
    WHERE s.id = p_session_id;

    IF v_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    IF v_room_name IS NULL OR LENGTH(TRIM(v_room_name)) = 0 THEN
        v_room_name := 'online_' || v_course_id::TEXT || '_' || p_session_id::TEXT;
    END IF;

    SELECT livekit_identity
    INTO v_identity
    FROM app.online_course_live_session_participants
    WHERE session_id = p_session_id
      AND user_id = p_user_id
    ORDER BY joined_at DESC
    LIMIT 1;

    IF v_identity IS NULL OR LENGTH(TRIM(v_identity)) = 0 THEN
        v_identity := 'user_' || p_user_id::TEXT;
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'session_id', p_session_id,
        'course_id', v_course_id,
        'livekit_room_name', v_room_name,
        'identity', v_identity
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_live_session_participant_livekit_identity(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_live_session_participant_livekit_identity(UUID, UUID) TO service_role;

-- ========================================
-- 6) RPC INSTRUCTEUR (CI) - SOUMISSION & DÉMARRAGE
-- ========================================

CREATE OR REPLACE FUNCTION app_ci_submit_online_course_live_session(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_course_id UUID;
    v_status TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT course_id, status
    INTO v_course_id, v_status
    FROM app.online_course_live_sessions
    WHERE id = p_session_id;

    IF v_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    IF v_status <> 'draft' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status_for_submit');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM app.online_course_instructors ci
        WHERE ci.course_id = v_course_id
          AND ci.instructor_id = v_user_id
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    UPDATE app.online_course_live_sessions
    SET status = 'pending_approval',
        host_id = COALESCE(host_id, v_user_id),
        updated_at = NOW()
    WHERE id = p_session_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'session_id', p_session_id, 'status', 'pending_approval');
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_submit_online_course_live_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_submit_online_course_live_session(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_ci_start_online_course_live_session(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_course_id UUID;
    v_status TEXT;
    v_room_name TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT course_id, status, livekit_room_name
    INTO v_course_id, v_status, v_room_name
    FROM app.online_course_live_sessions
    WHERE id = p_session_id;

    IF v_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    IF v_status <> 'approved' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_approved');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM app.online_course_instructors ci
        WHERE ci.course_id = v_course_id
          AND ci.instructor_id = v_user_id
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    IF v_room_name IS NULL OR LENGTH(TRIM(v_room_name)) = 0 THEN
        v_room_name := 'online_' || v_course_id::TEXT || '_' || p_session_id::TEXT;
    END IF;

    UPDATE app.online_course_live_sessions
    SET status = 'running',
        started_at = COALESCE(started_at, NOW()),
        host_id = COALESCE(host_id, v_user_id),
        livekit_room_name = v_room_name,
        updated_at = NOW()
    WHERE id = p_session_id;

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'session_id', p_session_id,
      'course_id', v_course_id,
      'livekit_room_name', v_room_name
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_start_online_course_live_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_start_online_course_live_session(UUID) TO service_role;

-- ========================================
-- 7) RPC ÉTUDIANT - LISTE GLOBALE DE MES LIVES
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_online_course_live_sessions()
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
                'id', s.id,
                'course_id', s.course_id,
                'title', s.title,
                'description', s.description,
                'provider', s.provider,
                'join_url', s.join_url,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'status', s.status,
                'replay_video_url', s.replay_video_url,
                'is_active', s.is_active,
                'course_title', c.title
            )
            ORDER BY s.start_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_live_sessions s
    JOIN app.online_course_enrollments e ON e.course_id = s.course_id
    JOIN app.online_courses c ON c.id = s.course_id
    WHERE e.student_id = v_user_id
      AND s.is_active = TRUE
      AND s.status IN ('approved', 'running');

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_online_course_live_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_online_course_live_sessions() TO service_role;

-- ========================================
-- 8) RPC CI - LISTE DES LIVES AVEC STATUT
-- ========================================

CREATE OR REPLACE FUNCTION app_ci_list_my_online_course_live_sessions()
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

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', s.id,
                'course_id', s.course_id,
                'lesson_id', s.lesson_id,
                'title', s.title,
                'description', s.description,
                'provider', s.provider,
                'join_url', s.join_url,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'replay_video_url', s.replay_video_url,
                'is_active', s.is_active,
                'status', s.status,
                'started_at', s.started_at,
                'ended_at', s.ended_at,
                'course_title', c.title
            )
            ORDER BY s.start_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_live_sessions s
    JOIN app.online_course_instructors ci ON ci.course_id = s.course_id
    JOIN app.online_courses c ON c.id = s.course_id
    WHERE ci.instructor_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_list_my_online_course_live_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_list_my_online_course_live_sessions() TO service_role;

-- ========================================
-- 9) RPC - ENREGISTRER UN PARTICIPANT LIVE
-- ========================================

CREATE OR REPLACE FUNCTION app_register_online_course_live_session_participant(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_course_id UUID;
    v_status TEXT;
    v_room_name TEXT;
    v_is_active BOOLEAN;
    v_is_banned BOOLEAN;
    v_is_instructor BOOLEAN := FALSE;
    v_is_student BOOLEAN := FALSE;
    v_effective_role TEXT;
    v_participant_id UUID;
    v_identity TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    SELECT course_id, status, livekit_room_name, is_active
    INTO v_course_id, v_status, v_room_name, v_is_active
    FROM app.online_course_live_sessions
    WHERE id = p_session_id;

    IF v_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    IF NOT v_is_active THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_active');
    END IF;

    IF v_status <> 'running' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_running');
    END IF;

    IF v_room_name IS NULL OR LENGTH(TRIM(v_room_name)) = 0 THEN
        v_room_name := 'online_' || v_course_id::TEXT || '_' || p_session_id::TEXT;
        UPDATE app.online_course_live_sessions
        SET livekit_room_name = v_room_name,
            updated_at = NOW()
        WHERE id = p_session_id;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.online_course_live_session_participants p
        WHERE p.session_id = p_session_id
          AND p.user_id = v_user_id
          AND p.is_banned = TRUE
    ) INTO v_is_banned;

    IF v_is_banned THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_session');
    END IF;

    IF v_role = 'admin' THEN
        v_effective_role := 'admin';
    ELSIF v_role = 'instructor' THEN
        SELECT EXISTS (
            SELECT 1
            FROM app.online_course_instructors ci
            WHERE ci.course_id = v_course_id
              AND ci.instructor_id = v_user_id
        ) INTO v_is_instructor;

        IF NOT v_is_instructor THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
        END IF;

        v_effective_role := 'instructor';
    ELSIF v_role = 'student' THEN
        SELECT EXISTS (
            SELECT 1
            FROM app.online_course_enrollments e
            WHERE e.course_id = v_course_id
              AND e.student_id = v_user_id
        ) INTO v_is_student;

        IF NOT v_is_student THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_enrolled');
        END IF;

        v_effective_role := 'student';
    ELSE
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unsupported_role');
    END IF;

    SELECT id, livekit_identity
    INTO v_participant_id, v_identity
    FROM app.online_course_live_session_participants
    WHERE session_id = p_session_id
      AND user_id = v_user_id
    ORDER BY joined_at DESC
    LIMIT 1;

    IF v_identity IS NULL OR LENGTH(TRIM(v_identity)) = 0 THEN
        v_identity := 'user_' || v_user_id::TEXT;
    END IF;

    IF v_participant_id IS NULL THEN
        INSERT INTO app.online_course_live_session_participants (
            session_id,
            user_id,
            role,
            livekit_identity,
            joined_at
        ) VALUES (
            p_session_id,
            v_user_id,
            v_effective_role,
            v_identity,
            NOW()
        )
        RETURNING id INTO v_participant_id;
    ELSE
        UPDATE app.online_course_live_session_participants
        SET role = v_effective_role,
            livekit_identity = v_identity,
            left_at = NULL
        WHERE id = v_participant_id;
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'session_id', p_session_id,
        'course_id', v_course_id,
        'role', v_effective_role,
        'livekit_room_name', v_room_name,
        'identity', v_identity
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_register_online_course_live_session_participant(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_register_online_course_live_session_participant(UUID) TO service_role;


