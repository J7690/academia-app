-- Phase 8 : RPCs pour le tracking de présence dans AcademiaSession
-- Table cible : app.academia_session_presence (créée en Phase 2)

-- 1. Heartbeat de présence (appelé toutes les 30s par le client)
CREATE OR REPLACE FUNCTION public.app_learning_presence_heartbeat(
  p_session_id UUID
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  INSERT INTO app.academia_session_presence (
    session_id, user_id, joined_at, last_heartbeat, is_online
  ) VALUES (
    p_session_id, v_user_id, NOW(), NOW(), TRUE
  )
  ON CONFLICT (session_id, user_id) DO UPDATE
    SET last_heartbeat = NOW(),
        is_online = TRUE;
END;
$$;

-- 2. Marquer offline (appelé au départ)
CREATE OR REPLACE FUNCTION public.app_learning_presence_offline(
  p_session_id UUID
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  UPDATE app.academia_session_presence
  SET is_online = FALSE,
      left_at = NOW(),
      duration_seconds = EXTRACT(EPOCH FROM (NOW() - joined_at))::INT
  WHERE session_id = p_session_id AND user_id = v_user_id;
END;
$$;

-- 3. Lister les participants présents (en ligne)
CREATE OR REPLACE FUNCTION public.app_learning_presence_list(
  p_session_id UUID
)
RETURNS TABLE(
  user_id UUID,
  display_name TEXT,
  joined_at TIMESTAMPTZ,
  last_heartbeat TIMESTAMPTZ,
  is_online BOOLEAN,
  duration_seconds INT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    COALESCE(s.full_name, s.email, p.user_id::TEXT) AS display_name,
    p.joined_at,
    p.last_heartbeat,
    p.is_online,
    COALESCE(p.duration_seconds, EXTRACT(EPOCH FROM (NOW() - p.joined_at))::INT) AS duration_seconds
  FROM app.academia_session_presence p
  LEFT JOIN app.students s ON s.user_id = p.user_id
  WHERE p.session_id = p_session_id
  ORDER BY p.is_online DESC, p.joined_at ASC;
END;
$$;

-- 4. Marquer offline les heartbeats stale (> 2 minutes)
CREATE OR REPLACE FUNCTION public.app_learning_presence_cleanup()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE app.academia_session_presence
  SET is_online = FALSE,
      left_at = last_heartbeat,
      duration_seconds = EXTRACT(EPOCH FROM (last_heartbeat - joined_at))::INT
  WHERE is_online = TRUE
    AND last_heartbeat < NOW() - INTERVAL '2 minutes';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.app_learning_presence_heartbeat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_presence_offline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_presence_list(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_presence_cleanup() TO authenticated;
