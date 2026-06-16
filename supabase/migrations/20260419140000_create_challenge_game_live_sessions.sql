-- ============================================================================
-- Migration: challenge_game_live_sessions
-- Table + RPCs pour le live gameplay dans le feed Challenges
-- ============================================================================

-- 1. Table des sessions live de jeu
CREATE TABLE IF NOT EXISTS app.challenge_game_live_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_type     TEXT NOT NULL DEFAULT 'unknown',
  mode          TEXT NOT NULL DEFAULT 'solo',
  status        TEXT NOT NULL DEFAULT 'live'
                  CHECK (status IN ('live', 'ended', 'cancelled')),
  score_final   INT DEFAULT 0,
  replay_video_asset_id UUID,
  livekit_room_name TEXT,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at      TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_cgls_user_id ON app.challenge_game_live_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_cgls_status ON app.challenge_game_live_sessions(status);
CREATE INDEX IF NOT EXISTS idx_cgls_started_at ON app.challenge_game_live_sessions(started_at DESC);

-- RLS : chaque utilisateur voit toutes les sessions (pour le feed) mais ne modifie que les siennes
ALTER TABLE app.challenge_game_live_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY cgls_select_all ON app.challenge_game_live_sessions
  FOR SELECT USING (true);

CREATE POLICY cgls_insert_own ON app.challenge_game_live_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY cgls_update_own ON app.challenge_game_live_sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================================
-- 2. RPC: challenge_game_start_live
-- Crée une session live et retourne son ID + room name LiveKit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.challenge_game_start_live(
  p_game_type TEXT DEFAULT 'unknown',
  p_mode      TEXT DEFAULT 'solo'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_session_id UUID;
  v_room_name TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Non authentifié.');
  END IF;

  -- Annuler toute session live précédente non terminée
  UPDATE app.challenge_game_live_sessions
  SET status = 'cancelled', ended_at = now()
  WHERE user_id = v_user_id AND status = 'live';

  -- Créer la nouvelle session
  v_session_id := gen_random_uuid();
  v_room_name := 'game_' || v_session_id::TEXT;

  INSERT INTO app.challenge_game_live_sessions (id, user_id, game_type, mode, status, livekit_room_name)
  VALUES (v_session_id, v_user_id, p_game_type, p_mode, 'live', v_room_name);

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'room_name', v_room_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.challenge_game_start_live(TEXT, TEXT) TO authenticated;

-- ============================================================================
-- 3. RPC: challenge_game_end_live
-- Termine une session live, enregistre le score et l'ID du replay
-- ============================================================================
CREATE OR REPLACE FUNCTION public.challenge_game_end_live(
  p_session_id          UUID,
  p_score_final         INT DEFAULT 0,
  p_replay_video_asset_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Non authentifié.');
  END IF;

  UPDATE app.challenge_game_live_sessions
  SET status = 'ended',
      score_final = p_score_final,
      replay_video_asset_id = p_replay_video_asset_id,
      ended_at = now()
  WHERE id = p_session_id
    AND user_id = v_user_id
    AND status = 'live';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session introuvable ou déjà terminée.');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.challenge_game_end_live(UUID, INT, UUID) TO authenticated;

-- ============================================================================
-- 4. RPC: challenge_game_list_live
-- Liste les sessions live en cours (pour le feed)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.challenge_game_list_live()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sessions JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.started_at DESC), '[]'::jsonb)
  INTO v_sessions
  FROM (
    SELECT
      s.id AS session_id,
      s.user_id,
      s.game_type,
      s.mode,
      s.livekit_room_name,
      s.started_at,
      COALESCE(st.full_name, '') AS player_name,
      COALESCE(st.avatar_url, '') AS player_avatar
    FROM app.challenge_game_live_sessions s
    LEFT JOIN app.students st ON st.id = s.user_id
    WHERE s.status = 'live'
      AND s.started_at > now() - INTERVAL '4 hours'
  ) t;

  RETURN jsonb_build_object('success', true, 'sessions', v_sessions);
END;
$$;

GRANT EXECUTE ON FUNCTION public.challenge_game_list_live() TO authenticated;
