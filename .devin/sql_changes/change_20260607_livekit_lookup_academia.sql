-- ============================================================
-- RPC: livekit_lookup_academia_session
-- Utilisée par l'Edge Function livekit-token pour
-- récupérer les données d'une session unifiée academia_sessions.
-- Migration: 2026-06-07
-- ============================================================

CREATE OR REPLACE FUNCTION public.livekit_lookup_academia_session(
  p_session_id UUID,
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_session RECORD;
BEGIN
  SELECT
    s.id,
    s.session_type::TEXT AS session_type,
    s.status::TEXT AS status,
    s.provider,
    s.title,
    s.host_id,
    s.livekit_room_name,
    s.is_recording_enabled,
    s.is_whiteboard_enabled,
    s.is_quiz_enabled,
    s.is_chat_enabled,
    s.is_screen_share_enabled,
    s.is_hand_raise_enabled,
    s.max_participants,
    s.current_participants,
    s.scheduled_start,
    s.actual_start
  INTO v_session
  FROM app.academia_sessions s
  WHERE s.id = p_session_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'id', v_session.id,
    'session_type', v_session.session_type,
    'status', v_session.status,
    'provider', v_session.provider,
    'title', v_session.title,
    'host_id', v_session.host_id,
    'livekit_room_name', v_session.livekit_room_name,
    'is_recording_enabled', v_session.is_recording_enabled,
    'is_whiteboard_enabled', v_session.is_whiteboard_enabled,
    'is_quiz_enabled', v_session.is_quiz_enabled,
    'is_chat_enabled', v_session.is_chat_enabled,
    'is_screen_share_enabled', v_session.is_screen_share_enabled,
    'is_hand_raise_enabled', v_session.is_hand_raise_enabled,
    'max_participants', v_session.max_participants,
    'current_participants', v_session.current_participants
  );
END;
$$;
