-- =====================================================
-- KELLENGE MULTIPLAYER FOUNDATION - PHASE 4
-- Création des tables et RPCs pour le multiplayer
-- =====================================================

-- 1. Table des sessions de jeu multiplayer
CREATE TABLE IF NOT EXISTS app.game_multiplayer_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_type VARCHAR(50) NOT NULL, -- 'Market Master', 'Consumer Choice', etc.
    game_mode VARCHAR(20) NOT NULL DEFAULT 'battle', -- 'battle', 'tournament', 'league'
    max_players INTEGER NOT NULL DEFAULT 2,
    current_players INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'waiting', -- 'waiting', 'active', 'completed', 'cancelled'
    host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    game_config JSONB DEFAULT '{}', -- Configuration spécifique au jeu
    room_code VARCHAR(8) UNIQUE, -- Code d'invitation à 6 caractères
    is_private BOOLEAN DEFAULT FALSE,
    elo_min INTEGER DEFAULT 0,
    elo_max INTEGER DEFAULT 3000
);

-- 2. Table des participants aux sessions
CREATE TABLE IF NOT EXISTS app.game_multiplayer_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.game_multiplayer_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'joined', -- 'joined', 'ready', 'playing', 'disconnected'
    score INTEGER DEFAULT 0,
    final_rank INTEGER,
    elo_rating_before INTEGER DEFAULT 1000, -- ELO avant la partie
    elo_rating_after INTEGER, -- ELO après la partie
    game_data JSONB DEFAULT '{}', -- Données spécifiques au joueur
    UNIQUE(session_id, user_id)
);

-- 3. Table des matchs de matchmaking
CREATE TABLE IF NOT EXISTS app.game_multiplayer_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.game_multiplayer_sessions(id) ON DELETE CASCADE,
    player1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    player2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    player1_elo INTEGER NOT NULL,
    player2_elo INTEGER NOT NULL,
    elo_difference INTEGER GENERATED ALWAYS AS (player2_elo - player1_elo) STORED,
    winner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    match_result VARCHAR(20), -- 'player1_win', 'player2_win', 'draw', 'abandoned'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    rating_change_player1 INTEGER, -- Changement ELO joueur 1
    rating_change_player2 INTEGER, -- Changement ELO joueur 2
    UNIQUE(player1_id, player2_id, created_at)
);

-- 4. Table des classements (leaderboards)
CREATE TABLE IF NOT EXISTS app.game_multiplayer_leaderboards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_type VARCHAR(50) NOT NULL,
    elo_rating INTEGER NOT NULL DEFAULT 1000,
    matches_played INTEGER NOT NULL DEFAULT 0,
    matches_won INTEGER NOT NULL DEFAULT 0,
    matches_lost INTEGER NOT NULL DEFAULT 0,
    matches_drawn INTEGER NOT NULL DEFAULT 0,
    win_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN matches_played > 0 THEN (matches_won::DECIMAL / matches_played::DECIMAL) * 100
            ELSE 0
        END
    ) STORED,
    current_streak INTEGER NOT NULL DEFAULT 0, -- Série de victoires/défaites actuelle
    best_streak INTEGER NOT NULL DEFAULT 0,
    total_score BIGINT NOT NULL DEFAULT 0,
    avg_score DECIMAL(10,2) GENERATED ALWAYS AS (
        CASE 
            WHEN matches_played > 0 THEN (total_score::DECIMAL / matches_played::DECIMAL)
            ELSE 0
        END
    ) STORED,
    rank_global INTEGER, -- Classement global
    rank_game_type INTEGER, -- Classement par type de jeu
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, game_type)
);

-- 5. Table des invitations
CREATE TABLE IF NOT EXISTS app.game_multiplayer_invitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.game_multiplayer_sessions(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'declined', 'expired'
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '10 minutes'),
    UNIQUE(sender_id, recipient_id, session_id)
);

-- 6. Table des messages de chat en jeu
CREATE TABLE IF NOT EXISTS app.game_multiplayer_chat (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.game_multiplayer_sessions(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'system', 'emoji', 'game_event'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMPTZ
);

-- 7. Table des statistiques de matchmaking
CREATE TABLE IF NOT EXISTS app.game_matchmaking_stats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_type VARCHAR(50) NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    searches_initiated INTEGER NOT NULL DEFAULT 0,
    matches_found INTEGER NOT NULL DEFAULT 0,
    avg_wait_time_seconds DECIMAL(8,2) DEFAULT 0,
    success_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN searches_initiated > 0 THEN (matches_found::DECIMAL / searches_initiated::DECIMAL) * 100
            ELSE 0
        END
    ) STORED,
    UNIQUE(user_id, game_type, date)
);

-- Index pour optimiser les performances
CREATE INDEX IF NOT EXISTS idx_game_sessions_status ON app.game_multiplayer_sessions(status);
CREATE INDEX IF NOT EXISTS idx_game_sessions_game_type ON app.game_multiplayer_sessions(game_type);
CREATE INDEX IF NOT EXISTS idx_game_sessions_host ON app.game_multiplayer_sessions(host_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_room_code ON app.game_multiplayer_sessions(room_code);
CREATE INDEX IF NOT EXISTS idx_game_sessions_created_at ON app.game_multiplayer_sessions(created_at);

CREATE INDEX IF NOT EXISTS idx_participants_session ON app.game_multiplayer_participants(session_id);
CREATE INDEX IF NOT EXISTS idx_participants_user ON app.game_multiplayer_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_participants_status ON app.game_multiplayer_participants(status);

CREATE INDEX IF NOT EXISTS idx_matches_players ON app.game_multiplayer_matches(player1_id, player2_id);
CREATE INDEX IF NOT EXISTS idx_matches_session ON app.game_multiplayer_matches(session_id);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON app.game_multiplayer_matches(created_at);

CREATE INDEX IF NOT EXISTS idx_leaderboards_user_game ON app.game_multiplayer_leaderboards(user_id, game_type);
CREATE INDEX IF NOT EXISTS idx_leaderboards_elo ON app.game_multiplayer_leaderboards(elo_rating DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboards_rank_global ON app.game_multiplayer_leaderboards(rank_global);
CREATE INDEX IF NOT EXISTS idx_leaderboards_rank_game ON app.game_multiplayer_leaderboards(rank_game_type);

CREATE INDEX IF NOT EXISTS idx_invitations_recipient ON app.game_multiplayer_invitations(recipient_id);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON app.game_multiplayer_invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_expires ON app.game_multiplayer_invitations(expires_at);

CREATE INDEX IF NOT EXISTS idx_chat_session ON app.game_multiplayer_chat(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_created_at ON app.game_multiplayer_chat(created_at);

-- Activer Realtime pour les tables critiques
ALTER PUBLICATION supabase_realtime ADD TABLE app.game_multiplayer_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE app.game_multiplayer_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE app.game_multiplayer_chat;

-- RLS (Row Level Security) policies
ALTER TABLE app.game_multiplayer_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_multiplayer_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_multiplayer_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_multiplayer_leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_multiplayer_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_multiplayer_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_matchmaking_stats ENABLE ROW LEVEL SECURITY;

-- Politiques RLS pour les sessions
CREATE POLICY "Users can view their sessions and public sessions" ON app.game_multiplayer_sessions
    FOR SELECT USING (
        host_id = auth.uid() OR 
        is_private = FALSE OR
        id IN (
            SELECT session_id FROM app.game_multiplayer_participants 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create sessions" ON app.game_multiplayer_sessions
    FOR INSERT WITH CHECK (host_id = auth.uid());

CREATE POLICY "Hosts can update their sessions" ON app.game_multiplayer_sessions
    FOR UPDATE USING (host_id = auth.uid());

CREATE POLICY "Hosts can delete their sessions" ON app.game_multiplayer_sessions
    FOR DELETE USING (host_id = auth.uid());

-- Politiques RLS pour les participants
CREATE POLICY "Users can view participants in their sessions" ON app.game_multiplayer_participants
    FOR SELECT USING (
        user_id = auth.uid() OR
        session_id IN (
            SELECT id FROM app.game_multiplayer_sessions 
            WHERE host_id = auth.uid() OR
            id IN (
                SELECT session_id FROM app.game_multiplayer_participants 
                WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can join sessions" ON app.game_multiplayer_participants
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        session_id IN (
            SELECT id FROM app.game_multiplayer_sessions 
            WHERE status = 'waiting' AND
            current_players < max_players
        )
    );

CREATE POLICY "Users can update their participation" ON app.game_multiplayer_participants
    FOR UPDATE USING (user_id = auth.uid());

-- Politiques RLS pour les classements (lecture seule pour tous)
CREATE POLICY "Everyone can view leaderboards" ON app.game_multiplayer_leaderboards
    FOR SELECT USING (true);

-- Politiques RLS pour les invitations
CREATE POLICY "Users can manage their invitations" ON app.game_multiplayer_invitations
    FOR ALL USING (
        sender_id = auth.uid() OR 
        recipient_id = auth.uid()
    );

-- Politiques RLS pour le chat
CREATE POLICY "Participants can view chat in their sessions" ON app.game_multiplayer_chat
    FOR SELECT USING (
        session_id IN (
            SELECT session_id FROM app.game_multiplayer_participants 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Participants can send chat messages" ON app.game_multiplayer_chat
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        session_id IN (
            SELECT session_id FROM app.game_multiplayer_participants 
            WHERE user_id = auth.uid() AND status = 'playing'
        )
    );

-- Politiques RLS pour les stats
CREATE POLICY "Users can view their own stats" ON app.game_matchmaking_stats
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update their own stats" ON app.game_matchmaking_stats
    FOR ALL USING (user_id = auth.uid());

-- Fonction pour générer des codes de room uniques
CREATE OR REPLACE FUNCTION app.generate_room_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    code TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        code := code || SUBSTR(chars, FLOOR(RANDOM() * LENGTH(chars)) + 1, 1);
    END LOOP;
    
    -- Vérifier si le code existe déjà
    IF EXISTS (SELECT 1 FROM app.game_multiplayer_sessions WHERE room_code = code) THEN
        RETURN app.generate_room_code(); -- Récursif si collision
    END IF;
    
    RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour générer automatiquement les codes de room
CREATE OR REPLACE FUNCTION app.set_room_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.room_code IS NULL OR NEW.room_code = '' THEN
        NEW.room_code := app.generate_room_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_game_sessions_set_room_code
    BEFORE INSERT ON app.game_multiplayer_sessions
    FOR EACH ROW EXECUTE FUNCTION app.set_room_code();

-- Trigger pour mettre à jour les statistiques des participants
CREATE OR REPLACE FUNCTION app.update_session_participants()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.game_multiplayer_sessions 
        SET current_players = current_players + 1 
        WHERE id = NEW.session_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.game_multiplayer_sessions 
        SET current_players = GREATEST(current_players - 1, 0) 
        WHERE id = OLD.session_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_update_session_participants_count
    AFTER INSERT OR DELETE ON app.game_multiplayer_participants
    FOR EACH ROW EXECUTE FUNCTION app.update_session_participants();

-- Fonction pour calculer les changements ELO
CREATE OR REPLACE FUNCTION app.calculate_elo_change(
    player_elo INTEGER,
    opponent_elo INTEGER,
    result VARCHAR(20) -- 'win', 'loss', 'draw'
)
RETURNS INTEGER AS $$
DECLARE
    k_factor INTEGER := 32;
    expected_score DECIMAL;
    actual_score DECIMAL;
    elo_change INTEGER;
BEGIN
    -- Calcul du score attendu
    expected_score := 1.0 / (1.0 + POWER(10.0, (opponent_elo - player_elo) / 400.0));
    
    -- Score réel
    IF result = 'win' THEN
        actual_score := 1.0;
    ELSIF result = 'loss' THEN
        actual_score := 0.0;
    ELSE -- draw
        actual_score := 0.5;
    END IF;
    
    -- Calcul du changement ELO
    elo_change := ROUND(k_factor * (actual_score - expected_score));
    
    RETURN elo_change;
END;
$$ LANGUAGE plpgsql;

-- Insertion de données de test (optionnel)
INSERT INTO app.game_multiplayer_leaderboards (user_id, game_type, elo_rating) VALUES
    ('00000000-0000-0000-0000-000000000000', 'Market Master', 1200),
    ('00000000-0000-0000-0000-000000000000', 'Consumer Choice', 1150),
    ('00000000-0000-0000-0000-000000000000', 'Firm Tycoon', 1300),
    ('00000000-0000-0000-0000-000000000000', 'Market Structures', 1100)
ON CONFLICT (user_id, game_type) DO NOTHING;
