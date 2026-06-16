-- Phase 11 : RPCs pour le replay intelligent AcademiaSession

-- 1. Récupérer les infos de replay d'une session
CREATE OR REPLACE FUNCTION public.app_learning_get_replay(
  p_session_id UUID
)
RETURNS TABLE(
  session_id UUID,
  title TEXT,
  replay_url TEXT,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_seconds INT,
  host_name TEXT,
  participant_count INT,
  quiz_count INT,
  message_count INT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id AS session_id,
    s.title,
    s.replay_url,
    s.started_at,
    s.ended_at,
    EXTRACT(EPOCH FROM (COALESCE(s.ended_at, NOW()) - s.started_at))::INT AS duration_seconds,
    COALESCE(st.full_name, s.host_id::TEXT) AS host_name,
    (SELECT COUNT(*)::INT FROM app.academia_session_participants p WHERE p.session_id = s.id) AS participant_count,
    (SELECT COUNT(*)::INT FROM app.academia_session_quiz_questions q WHERE q.session_id = s.id) AS quiz_count,
    (SELECT COUNT(*)::INT FROM app.academia_session_messages m WHERE m.session_id = s.id) AS message_count
  FROM app.academia_sessions s
  LEFT JOIN app.students st ON st.user_id = s.host_id
  WHERE s.id = p_session_id
    AND s.replay_url IS NOT NULL;
END;
$$;

-- 2. Timeline des événements pour la barre de navigation replay
CREATE OR REPLACE FUNCTION public.app_learning_replay_timeline(
  p_session_id UUID
)
RETURNS TABLE(
  event_type TEXT,
  event_time TIMESTAMPTZ,
  event_data JSONB
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_start TIMESTAMPTZ;
BEGIN
  SELECT started_at INTO v_start
  FROM app.academia_sessions WHERE id = p_session_id;

  -- Quiz events
  RETURN QUERY
  SELECT
    'quiz'::TEXT AS event_type,
    q.created_at AS event_time,
    jsonb_build_object(
      'question_id', q.id,
      'question', q.question,
      'options', q.options,
      'correct_index', q.correct_index,
      'offset_seconds', EXTRACT(EPOCH FROM (q.created_at - v_start))::INT
    ) AS event_data
  FROM app.academia_session_quiz_questions q
  WHERE q.session_id = p_session_id
  ORDER BY q.created_at;

  -- Presence events (join/leave)
  RETURN QUERY
  SELECT
    'join'::TEXT AS event_type,
    p.joined_at AS event_time,
    jsonb_build_object(
      'user_id', p.user_id,
      'offset_seconds', EXTRACT(EPOCH FROM (p.joined_at - v_start))::INT
    ) AS event_data
  FROM app.academia_session_presence p
  WHERE p.session_id = p_session_id
  ORDER BY p.joined_at;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.app_learning_get_replay(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_replay_timeline(UUID) TO authenticated;
