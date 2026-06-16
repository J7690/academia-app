-- ============================================================
-- Academia Learning Engine — RPCs
-- Migration: 2026-06-07
-- ============================================================

-- ─── 1. Créer / modifier une session ────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_upsert_session(
  p_session_id UUID DEFAULT NULL,
  p_session_type TEXT DEFAULT 'course',
  p_title TEXT DEFAULT '',
  p_description TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_concours_type TEXT DEFAULT NULL,
  p_course_id UUID DEFAULT NULL,
  p_program_id UUID DEFAULT NULL,
  p_provider TEXT DEFAULT 'livekit',
  p_scheduled_start TIMESTAMPTZ DEFAULT NULL,
  p_scheduled_end TIMESTAMPTZ DEFAULT NULL,
  p_max_participants INT DEFAULT 100,
  p_is_recording_enabled BOOLEAN DEFAULT TRUE,
  p_is_whiteboard_enabled BOOLEAN DEFAULT FALSE,
  p_is_quiz_enabled BOOLEAN DEFAULT TRUE,
  p_is_chat_enabled BOOLEAN DEFAULT TRUE,
  p_is_screen_share_enabled BOOLEAN DEFAULT TRUE,
  p_is_hand_raise_enabled BOOLEAN DEFAULT TRUE,
  p_thumbnail_url TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session_id UUID;
  v_room_name TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  IF p_title IS NULL OR char_length(p_title) = 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Titre obligatoire.');
  END IF;

  -- Génère un room_name unique pour LiveKit
  v_room_name := 'session_' || COALESCE(p_session_id, gen_random_uuid())::TEXT;

  IF p_session_id IS NOT NULL THEN
    -- Update existant
    UPDATE app.academia_sessions SET
      title = p_title,
      description = p_description,
      subject = p_subject,
      concours_type = p_concours_type,
      course_id = p_course_id,
      program_id = p_program_id,
      provider = p_provider,
      scheduled_start = p_scheduled_start,
      scheduled_end = p_scheduled_end,
      max_participants = p_max_participants,
      is_recording_enabled = p_is_recording_enabled,
      is_whiteboard_enabled = p_is_whiteboard_enabled,
      is_quiz_enabled = p_is_quiz_enabled,
      is_chat_enabled = p_is_chat_enabled,
      is_screen_share_enabled = p_is_screen_share_enabled,
      is_hand_raise_enabled = p_is_hand_raise_enabled,
      thumbnail_url = p_thumbnail_url,
      metadata = p_metadata
    WHERE id = p_session_id AND host_id = v_user_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'Session introuvable ou accès refusé.');
    END IF;
    v_session_id := p_session_id;
  ELSE
    -- Insert nouvelle session
    INSERT INTO app.academia_sessions (
      session_type, status, provider, title, description, subject, concours_type,
      host_id, course_id, program_id, scheduled_start, scheduled_end,
      max_participants, is_recording_enabled, is_whiteboard_enabled,
      is_quiz_enabled, is_chat_enabled, is_screen_share_enabled,
      is_hand_raise_enabled, thumbnail_url, metadata, livekit_room_name
    ) VALUES (
      p_session_type::app.academia_session_type, 'draft'::app.academia_session_status,
      p_provider, p_title, p_description, p_subject, p_concours_type,
      v_user_id, p_course_id, p_program_id, p_scheduled_start, p_scheduled_end,
      p_max_participants, p_is_recording_enabled, p_is_whiteboard_enabled,
      p_is_quiz_enabled, p_is_chat_enabled, p_is_screen_share_enabled,
      p_is_hand_raise_enabled, p_thumbnail_url, p_metadata, v_room_name
    ) RETURNING id INTO v_session_id;
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'session_id', v_session_id,
    'livekit_room_name', v_room_name
  );
END;
$$;

-- ─── 2. Lister les sessions (filtrable) ─────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_list_sessions(
  p_session_type TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_host_id UUID DEFAULT NULL,
  p_course_id UUID DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sessions JSONB;
  v_total INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT COUNT(*), COALESCE(jsonb_agg(row_to_json(sub)::JSONB ORDER BY sub.scheduled_start DESC NULLS LAST), '[]'::JSONB)
  INTO v_total, v_sessions
  FROM (
    SELECT
      s.id, s.session_type, s.status, s.provider, s.title, s.description,
      s.subject, s.concours_type, s.host_id, s.course_id, s.program_id,
      s.scheduled_start, s.scheduled_end, s.actual_start, s.actual_end,
      s.max_participants, s.current_participants,
      s.is_recording_enabled, s.is_whiteboard_enabled, s.is_quiz_enabled,
      s.is_chat_enabled, s.is_screen_share_enabled, s.is_hand_raise_enabled,
      s.replay_url, s.livekit_room_name, s.thumbnail_url,
      s.created_at, s.updated_at,
      COALESCE(st.full_name, u.email) AS host_display_name
    FROM app.academia_sessions s
    LEFT JOIN app.students st ON st.id = s.host_id
    LEFT JOIN auth.users u ON u.id = s.host_id
    WHERE (p_session_type IS NULL OR s.session_type::TEXT = p_session_type)
      AND (p_status IS NULL OR s.status::TEXT = p_status)
      AND (p_host_id IS NULL OR s.host_id = p_host_id)
      AND (p_course_id IS NULL OR s.course_id = p_course_id)
    ORDER BY s.scheduled_start DESC NULLS LAST
    LIMIT p_limit OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object('success', TRUE, 'sessions', v_sessions, 'total', v_total);
END;
$$;

-- ─── 3. Obtenir une session par ID ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_get_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT row_to_json(sub)::JSONB INTO v_session FROM (
    SELECT
      s.*,
      COALESCE(st.full_name, u.email) AS host_display_name
    FROM app.academia_sessions s
    LEFT JOIN app.students st ON st.id = s.host_id
    LEFT JOIN auth.users u ON u.id = s.host_id
    WHERE s.id = p_session_id
  ) sub;

  IF v_session IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Session introuvable.');
  END IF;

  RETURN jsonb_build_object('success', TRUE, 'session', v_session);
END;
$$;

-- ─── 4. Démarrer une session ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_start_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT * INTO v_session FROM app.academia_sessions
  WHERE id = p_session_id AND host_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Session introuvable ou accès refusé.');
  END IF;

  IF v_session.status NOT IN ('draft', 'scheduled', 'approved') THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'La session ne peut pas être démarrée (statut: ' || v_session.status::TEXT || ').');
  END IF;

  UPDATE app.academia_sessions SET
    status = 'running'::app.academia_session_status,
    actual_start = NOW()
  WHERE id = p_session_id;

  -- Ajouter l'hôte comme participant
  INSERT INTO app.academia_session_participants (session_id, user_id, role, joined_at)
  VALUES (p_session_id, v_user_id, 'host', NOW())
  ON CONFLICT (session_id, user_id) DO UPDATE SET joined_at = NOW(), left_at = NULL;

  -- Log présence
  INSERT INTO app.academia_session_presence (session_id, user_id, event_type)
  VALUES (p_session_id, v_user_id, 'join');

  RETURN jsonb_build_object(
    'success', TRUE,
    'session_id', p_session_id,
    'livekit_room_name', v_session.livekit_room_name,
    'status', 'running'
  );
END;
$$;

-- ─── 5. Terminer une session ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_end_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session RECORD;
  v_duration INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT * INTO v_session FROM app.academia_sessions
  WHERE id = p_session_id AND host_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Session introuvable ou accès refusé.');
  END IF;

  IF v_session.status != 'running' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'La session n''est pas en cours.');
  END IF;

  v_duration := EXTRACT(EPOCH FROM (NOW() - v_session.actual_start))::INT;

  UPDATE app.academia_sessions SET
    status = 'ended'::app.academia_session_status,
    actual_end = NOW()
  WHERE id = p_session_id;

  -- Marquer tous les participants comme partis
  UPDATE app.academia_session_participants SET
    left_at = NOW(),
    duration_seconds = EXTRACT(EPOCH FROM (NOW() - joined_at))::INT
  WHERE session_id = p_session_id AND left_at IS NULL;

  RETURN jsonb_build_object(
    'success', TRUE,
    'session_id', p_session_id,
    'duration_seconds', v_duration
  );
END;
$$;

-- ─── 6. Rejoindre une session ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_join_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session RECORD;
  v_display_name TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT * INTO v_session FROM app.academia_sessions WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Session introuvable.');
  END IF;

  IF v_session.status != 'running' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'La session n''est pas en cours.');
  END IF;

  IF v_session.max_participants IS NOT NULL AND v_session.current_participants >= v_session.max_participants THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Session complète.');
  END IF;

  -- Récupérer display_name
  SELECT COALESCE(full_name, 'Étudiant') INTO v_display_name
  FROM app.students WHERE id = v_user_id;

  -- Upsert participant
  INSERT INTO app.academia_session_participants (session_id, user_id, role, joined_at)
  VALUES (p_session_id, v_user_id, 'participant', NOW())
  ON CONFLICT (session_id, user_id) DO UPDATE SET joined_at = NOW(), left_at = NULL;

  -- Incrémenter compteur
  UPDATE app.academia_sessions SET current_participants = current_participants + 1
  WHERE id = p_session_id;

  -- Log présence
  INSERT INTO app.academia_session_presence (session_id, user_id, event_type)
  VALUES (p_session_id, v_user_id, 'join');

  RETURN jsonb_build_object(
    'success', TRUE,
    'session_id', p_session_id,
    'livekit_room_name', v_session.livekit_room_name,
    'display_name', v_display_name,
    'is_host', (v_session.host_id = v_user_id)
  );
END;
$$;

-- ─── 7. Quitter une session ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_leave_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_participant RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT * INTO v_participant FROM app.academia_session_participants
  WHERE session_id = p_session_id AND user_id = v_user_id AND left_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', TRUE, 'message', 'Déjà parti.');
  END IF;

  UPDATE app.academia_session_participants SET
    left_at = NOW(),
    duration_seconds = EXTRACT(EPOCH FROM (NOW() - joined_at))::INT
  WHERE session_id = p_session_id AND user_id = v_user_id;

  -- Décrémenter compteur
  UPDATE app.academia_sessions SET
    current_participants = GREATEST(0, current_participants - 1)
  WHERE id = p_session_id;

  -- Log présence
  INSERT INTO app.academia_session_presence (session_id, user_id, event_type)
  VALUES (p_session_id, v_user_id, 'leave');

  RETURN jsonb_build_object(
    'success', TRUE,
    'duration_seconds', v_participant.duration_seconds
  );
END;
$$;

-- ─── 8. Obtenir les statistiques de présence ────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_get_presence_stats(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_stats JSONB;
  v_participants JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(sub)::JSONB), '[]'::JSONB)
  INTO v_participants
  FROM (
    SELECT
      p.user_id,
      COALESCE(st.full_name, 'Utilisateur') AS display_name,
      p.role,
      p.joined_at,
      p.left_at,
      p.duration_seconds,
      p.is_hand_raised
    FROM app.academia_session_participants p
    LEFT JOIN app.students st ON st.id = p.user_id
    WHERE p.session_id = p_session_id
    ORDER BY p.joined_at
  ) sub;

  SELECT jsonb_build_object(
    'total_participants', (SELECT COUNT(*) FROM app.academia_session_participants WHERE session_id = p_session_id),
    'currently_connected', (SELECT COUNT(*) FROM app.academia_session_participants WHERE session_id = p_session_id AND left_at IS NULL),
    'avg_duration_seconds', (SELECT COALESCE(AVG(duration_seconds), 0) FROM app.academia_session_participants WHERE session_id = p_session_id AND duration_seconds > 0),
    'hands_raised', (SELECT COUNT(*) FROM app.academia_session_participants WHERE session_id = p_session_id AND is_hand_raised = TRUE)
  ) INTO v_stats;

  RETURN jsonb_build_object('success', TRUE, 'stats', v_stats, 'participants', v_participants);
END;
$$;

-- ─── 9. Lister mes sessions (enseignant) ────────────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_list_my_sessions(
  p_session_type TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sessions JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(sub)::JSONB ORDER BY sub.scheduled_start DESC NULLS LAST), '[]'::JSONB)
  INTO v_sessions
  FROM (
    SELECT
      s.id, s.session_type, s.status, s.provider, s.title, s.description,
      s.subject, s.concours_type, s.host_id, s.course_id, s.program_id,
      s.scheduled_start, s.scheduled_end, s.actual_start, s.actual_end,
      s.max_participants, s.current_participants,
      s.is_recording_enabled, s.is_whiteboard_enabled, s.is_quiz_enabled,
      s.replay_url, s.livekit_room_name, s.thumbnail_url,
      s.created_at, s.updated_at
    FROM app.academia_sessions s
    WHERE s.host_id = v_user_id
      AND (p_session_type IS NULL OR s.session_type::TEXT = p_session_type)
      AND (p_status IS NULL OR s.status::TEXT = p_status)
    ORDER BY s.scheduled_start DESC NULLS LAST
    LIMIT p_limit
  ) sub;

  RETURN jsonb_build_object('success', TRUE, 'sessions', v_sessions);
END;
$$;

-- ─── 10. Lister sessions disponibles (étudiant) ─────────────────────
CREATE OR REPLACE FUNCTION public.app_learning_list_available_sessions(
  p_session_type TEXT DEFAULT NULL,
  p_limit INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sessions JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(sub)::JSONB ORDER BY sub.scheduled_start ASC NULLS LAST), '[]'::JSONB)
  INTO v_sessions
  FROM (
    SELECT
      s.id, s.session_type, s.status, s.provider, s.title, s.description,
      s.subject, s.concours_type, s.host_id,
      s.scheduled_start, s.scheduled_end,
      s.max_participants, s.current_participants,
      s.is_recording_enabled, s.replay_url, s.livekit_room_name,
      s.thumbnail_url, s.created_at,
      COALESCE(st.full_name, 'Enseignant') AS host_display_name
    FROM app.academia_sessions s
    LEFT JOIN app.students st ON st.id = s.host_id
    WHERE s.status IN ('scheduled', 'approved', 'running')
      AND (p_session_type IS NULL OR s.session_type::TEXT = p_session_type)
    ORDER BY
      CASE WHEN s.status = 'running' THEN 0 ELSE 1 END,
      s.scheduled_start ASC NULLS LAST
    LIMIT p_limit
  ) sub;

  RETURN jsonb_build_object('success', TRUE, 'sessions', v_sessions);
END;
$$;

-- ─── 11. Admin: approuver/rejeter une session ───────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_learning_update_session_status(
  p_session_id UUID,
  p_new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Non authentifié.');
  END IF;

  SELECT EXISTS(SELECT 1 FROM app.students WHERE id = v_user_id AND role = 'admin')
  INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Accès refusé. Admin requis.');
  END IF;

  UPDATE app.academia_sessions SET
    status = p_new_status::app.academia_session_status
  WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Session introuvable.');
  END IF;

  RETURN jsonb_build_object('success', TRUE, 'session_id', p_session_id, 'new_status', p_new_status);
END;
$$;
