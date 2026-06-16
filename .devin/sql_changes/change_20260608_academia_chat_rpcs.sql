-- Phase 7 : RPCs pour le chat académique persistant
-- Table cible : app.academia_session_messages (créée en Phase 2)

-- 1. Envoyer un message
CREATE OR REPLACE FUNCTION public.app_learning_send_message(
  p_session_id UUID,
  p_content TEXT,
  p_message_type TEXT DEFAULT 'text'
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_message_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  INSERT INTO app.academia_session_messages (
    session_id, sender_id, content, message_type
  ) VALUES (
    p_session_id, v_user_id, p_content, p_message_type
  )
  RETURNING id INTO v_message_id;

  RETURN v_message_id;
END;
$$;

-- 2. Lister les messages d'une session (paginé)
CREATE OR REPLACE FUNCTION public.app_learning_list_messages(
  p_session_id UUID,
  p_limit INT DEFAULT 50,
  p_before TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
  id UUID,
  session_id UUID,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  message_type TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.session_id,
    m.sender_id,
    COALESCE(s.full_name, s.email, m.sender_id::TEXT) AS sender_name,
    m.content,
    m.message_type,
    m.created_at
  FROM app.academia_session_messages m
  LEFT JOIN app.students s ON s.user_id = m.sender_id
  WHERE m.session_id = p_session_id
    AND (p_before IS NULL OR m.created_at < p_before)
  ORDER BY m.created_at DESC
  LIMIT p_limit;
END;
$$;

-- 3. Supprimer un message (propre ou admin)
CREATE OR REPLACE FUNCTION public.app_learning_delete_message(
  p_message_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sender_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  SELECT sender_id INTO v_sender_id
  FROM app.academia_session_messages
  WHERE id = p_message_id;

  IF v_sender_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Vérifier si admin
  SELECT EXISTS(
    SELECT 1 FROM app.user_admin_status WHERE user_id = v_user_id AND is_active = TRUE
  ) INTO v_is_admin;

  IF v_sender_id != v_user_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Non autorisé';
  END IF;

  DELETE FROM app.academia_session_messages WHERE id = p_message_id;
  RETURN TRUE;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.app_learning_send_message(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_list_messages(UUID, INT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_delete_message(UUID) TO authenticated;
