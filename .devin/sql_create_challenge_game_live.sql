-- =====================================================
-- CHALLENGE GAME LIVE SESSIONS — Table + RPCs
-- Sessions live de jeux dans l'onglet Challenge
-- Séparé des autres lives (prep, cours, TD)
-- =====================================================

-- 1. Table des sessions live de jeux
CREATE TABLE IF NOT EXISTS app.challenge_game_live_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_type TEXT NOT NULL,
    mode TEXT NOT NULL DEFAULT 'solo',
    status TEXT NOT NULL DEFAULT 'live',
    score_final INT DEFAULT 0,
    spectator_count INT DEFAULT 0,
    replay_video_asset_id UUID,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Index pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_challenge_game_live_user ON app.challenge_game_live_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_challenge_game_live_status ON app.challenge_game_live_sessions(status) WHERE status = 'live';

-- 3. RLS
ALTER TABLE app.challenge_game_live_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all live sessions"
    ON app.challenge_game_live_sessions FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own sessions"
    ON app.challenge_game_live_sessions FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own sessions"
    ON app.challenge_game_live_sessions FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid());

-- 4. Ajouter à la publication Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE app.challenge_game_live_sessions;

-- 5. RPC: Démarrer une session live de jeu
CREATE OR REPLACE FUNCTION app.challenge_game_start_live(
    p_game_type TEXT,
    p_mode TEXT DEFAULT 'solo'
) RETURNS JSONB AS $$
DECLARE
    v_session_id UUID;
BEGIN
    INSERT INTO app.challenge_game_live_sessions (user_id, game_type, mode, status, started_at)
    VALUES (auth.uid(), p_game_type, p_mode, 'live', NOW())
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Terminer une session live de jeu
CREATE OR REPLACE FUNCTION app.challenge_game_end_live(
    p_session_id UUID,
    p_score_final INT DEFAULT 0,
    p_replay_video_asset_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
    UPDATE app.challenge_game_live_sessions
    SET status = 'ended',
        score_final = p_score_final,
        replay_video_asset_id = p_replay_video_asset_id,
        ended_at = NOW()
    WHERE id = p_session_id AND user_id = auth.uid();

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: Lister les sessions live en cours (pour le feed)
CREATE OR REPLACE FUNCTION app.challenge_game_list_live()
RETURNS JSONB AS $$
BEGIN
    RETURN COALESCE((
        SELECT jsonb_agg(row_to_json(t))
        FROM (
            SELECT
                s.id,
                s.user_id,
                s.game_type,
                s.mode,
                s.score_final,
                s.spectator_count,
                s.started_at,
                p.display_name,
                p.avatar_url
            FROM app.challenge_game_live_sessions s
            LEFT JOIN app.profiles p ON p.id = s.user_id
            WHERE s.status = 'live'
            ORDER BY s.started_at DESC
            LIMIT 20
        ) t
    ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
