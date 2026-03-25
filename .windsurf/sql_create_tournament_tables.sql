-- =====================================================
-- KELLENGE TOURNAMENTS & LEAGUES - PHASE 5
-- Création des tables et structures pour tournois et ligues
-- =====================================================

-- 1. Table des tournois
CREATE TABLE IF NOT EXISTS app.tournaments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    game_type VARCHAR(50) NOT NULL, -- 'Market Master', 'Consumer Choice', etc.
    tournament_type VARCHAR(20) NOT NULL DEFAULT 'elimination', -- 'elimination', 'round_robin', 'swiss', 'group_stage'
    format VARCHAR(20) NOT NULL DEFAULT 'single_elimination', -- 'single_elimination', 'double_elimination', 'best_of_3', 'best_of_5'
    max_participants INTEGER NOT NULL DEFAULT 16,
    min_participants INTEGER NOT NULL DEFAULT 4,
    current_participants INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'draft', -- 'draft', 'registration', 'active', 'completed', 'cancelled'
    registration_start TIMESTAMPTZ DEFAULT NOW(),
    registration_end TIMESTAMPTZ,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    prize_pool INTEGER DEFAULT 0,
    entry_fee INTEGER DEFAULT 0,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    settings JSONB DEFAULT '{}', -- Configuration spécifique au tournoi
    is_featured BOOLEAN DEFAULT FALSE,
    is_private BOOLEAN DEFAULT FALSE,
    elo_min INTEGER DEFAULT 0,
    elo_max INTEGER DEFAULT 3000,
    auto_start BOOLEAN DEFAULT TRUE
);

-- 2. Table des participants aux tournois
CREATE TABLE IF NOT EXISTS app.tournament_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID NOT NULL REFERENCES app.tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    registration_date TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'registered', -- 'registered', 'checked_in', 'active', 'disqualified', 'eliminated', 'withdrawn', 'winner'
    seed_number INTEGER, -- Pour le bracket
    current_round INTEGER DEFAULT 0,
    current_position INTEGER DEFAULT 0,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    matches_lost INTEGER DEFAULT 0,
    matches_drawn INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    elo_rating_before INTEGER DEFAULT 1000,
    elo_rating_after INTEGER,
    prize_won INTEGER DEFAULT 0,
    eliminated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Qui a éliminé ce participant
    eliminated_at TIMESTAMPTZ,
    notes TEXT,
    UNIQUE(tournament_id, user_id)
);

-- 3. Table des matchs de tournoi
CREATE TABLE IF NOT EXISTS app.tournament_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID NOT NULL REFERENCES app.tournaments(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL,
    match_number INTEGER NOT NULL,
    participant1_id UUID REFERENCES app.tournament_participants(id) ON DELETE SET NULL,
    participant2_id UUID REFERENCES app.tournament_participants(id) ON DELETE SET NULL,
    participant3_id UUID REFERENCES app.tournament_participants(id) ON DELETE SET NULL, -- Pour les matchs 3 joueurs
    participant4_id UUID REFERENCES app.tournament_participants(id) ON DELETE SET NULL, -- Pour les matchs 4 joueurs
    winner_id UUID REFERENCES app.tournament_participants(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled', -- 'scheduled', 'in_progress', 'completed', 'cancelled'
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    best_of INTEGER DEFAULT 1, -- Best of 1, 3, 5
    participant1_score INTEGER DEFAULT 0,
    participant2_score INTEGER DEFAULT 0,
    participant3_score INTEGER DEFAULT 0,
    participant4_score INTEGER DEFAULT 0,
    next_match_id UUID REFERENCES app.tournament_matches(id) ON DELETE SET NULL, -- Pour le bracket
    bracket_position VARCHAR(20), -- Position dans le bracket
    stream_url TEXT,
    notes TEXT
);

-- 4. Table des ligues
CREATE TABLE IF NOT EXISTS app.leagues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    game_type VARCHAR(50) NOT NULL,
    league_type VARCHAR(20) NOT NULL DEFAULT 'seasonal', -- 'seasonal', 'ranked', 'casual'
    division VARCHAR(20) NOT NULL DEFAULT 'main', -- 'bronze', 'silver', 'gold', 'platinum', 'diamond', 'main'
    season_number INTEGER DEFAULT 1,
    season_start TIMESTAMPTZ DEFAULT NOW(),
    season_end TIMESTAMPTZ,
    max_players INTEGER DEFAULT 1000,
    current_players INTEGER DEFAULT 0,
    promotion_division VARCHAR(20), -- Division supérieure pour promotion
    relegation_division VARCHAR(20), -- Division inférieure pour relégation
    promotion_count INTEGER DEFAULT 2, -- Nombre de joueurs promus
    relegation_count INTEGER DEFAULT 2, -- Nombre de joueurs relégués
    min_elo INTEGER DEFAULT 0,
    max_elo INTEGER DEFAULT 3000,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    settings JSONB DEFAULT '{}'
);

-- 5. Table des participations aux ligues
CREATE TABLE IF NOT EXISTS app.league_participations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    league_id UUID NOT NULL REFERENCES app.leagues(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    division VARCHAR(20) NOT NULL DEFAULT 'main',
    rank_position INTEGER,
    points INTEGER DEFAULT 0,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    matches_lost INTEGER DEFAULT 0,
    matches_drawn INTEGER DEFAULT 0,
    win_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN matches_played > 0 THEN (matches_won::DECIMAL / matches_played::DECIMAL) * 100
            ELSE 0
        END
    ) STORED,
    elo_rating INTEGER DEFAULT 1000,
    elo_rating_start INTEGER DEFAULT 1000,
    elo_rating_end INTEGER,
    elo_change INTEGER DEFAULT 0,
    promotion_points INTEGER DEFAULT 0,
    demotion_points INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    best_streak INTEGER DEFAULT 0,
    season_points INTEGER DEFAULT 0, -- Points pour le classement saisonnier
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    last_match_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'promoted', 'relegated', 'banned'
    UNIQUE(league_id, user_id)
);

-- 6. Table des matchs de ligues
CREATE TABLE IF NOT EXISTS app.league_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    league_id UUID NOT NULL REFERENCES app.leagues(id) ON DELETE CASCADE,
    participant1_id UUID NOT NULL REFERENCES app.league_participations(id) ON DELETE CASCADE,
    participant2_id UUID NOT NULL REFERENCES app.league_participations(id) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled', -- 'scheduled', 'in_progress', 'completed', 'cancelled'
    winner_id UUID REFERENCES app.league_participations(id) ON DELETE SET NULL,
    participant1_score INTEGER DEFAULT 0,
    participant2_score INTEGER DEFAULT 0,
    participant1_elo_change INTEGER DEFAULT 0,
    participant2_elo_change INTEGER DEFAULT 0,
    participant1_points INTEGER DEFAULT 0, -- Points de ligue
    participant2_points INTEGER DEFAULT 0,
    notes TEXT
);

-- 7. Table des récompenses
CREATE TABLE IF NOT EXISTS app.tournament_rewards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.tournaments(id) ON DELETE CASCADE,
    league_id UUID REFERENCES app.leagues(id) ON DELETE CASCADE,
    rank_from INTEGER NOT NULL, -- Position de départ
    rank_to INTEGER NOT NULL, -- Position de fin
    reward_type VARCHAR(20) NOT NULL, -- 'cash', 'points', 'item', 'badge', 'promotion'
    reward_value INTEGER NOT NULL,
    reward_name VARCHAR(100),
    reward_description TEXT,
    reward_icon VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table des événements de tournoi/ligue
CREATE TABLE IF NOT EXISTS app.competitive_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.tournaments(id) ON DELETE CASCADE,
    league_id UUID REFERENCES app.leagues(id) ON DELETE CASCADE,
    match_id UUID REFERENCES app.tournament_matches(id) ON DELETE SET NULL,
    league_match_id UUID REFERENCES app.league_matches(id) ON DELETE SET NULL,
    participant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL, -- 'tournament_created', 'match_completed', 'player_eliminated', 'promotion', 'relegation', 'achievement'
    event_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour optimiser les performances
CREATE INDEX IF NOT EXISTS idx_tournaments_status ON app.tournaments(status);
CREATE INDEX IF NOT EXISTS idx_tournaments_game_type ON app.tournaments(game_type);
CREATE INDEX IF NOT EXISTS idx_tournaments_created_by ON app.tournaments(created_by);
CREATE INDEX IF NOT EXISTS idx_tournaments_dates ON app.tournaments(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_tournaments_featured ON app.tournaments(is_featured);

CREATE INDEX IF NOT EXISTS idx_tournament_participants_tournament ON app.tournament_participants(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_participants_user ON app.tournament_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_tournament_participants_status ON app.tournament_participants(status);
CREATE INDEX IF NOT EXISTS idx_tournament_participants_seed ON app.tournament_participants(seed_number);

CREATE INDEX IF NOT EXISTS idx_tournament_matches_tournament ON app.tournament_matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_round ON app.tournament_matches(round_number, match_number);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_status ON app.tournament_matches(status);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_participants ON app.tournament_matches(participant1_id, participant2_id);

CREATE INDEX IF NOT EXISTS idx_leagues_type_division ON app.leagues(league_type, division);
CREATE INDEX IF NOT EXISTS idx_leagues_game_type ON app.leagues(game_type);
CREATE INDEX IF NOT EXISTS idx_leagues_active ON app.leagues(is_active);
CREATE INDEX IF NOT EXISTS idx_leagues_season ON app.leagues(season_number);

CREATE INDEX IF NOT EXISTS idx_league_participations_league ON app.league_participations(league_id);
CREATE INDEX IF NOT EXISTS idx_league_participations_user ON app.league_participations(user_id);
CREATE INDEX IF NOT EXISTS idx_league_participations_division ON app.league_participations(division);
CREATE INDEX IF NOT EXISTS idx_league_participations_rank ON app.league_participations(rank_position);

CREATE INDEX IF NOT EXISTS idx_league_matches_league ON app.league_matches(league_id);
CREATE INDEX IF NOT EXISTS idx_league_matches_participants ON app.league_matches(participant1_id, participant2_id);
CREATE INDEX IF NOT EXISTS idx_league_matches_status ON app.league_matches(status);
CREATE INDEX IF NOT EXISTS idx_league_matches_scheduled ON app.league_matches(scheduled_at);

CREATE INDEX IF NOT EXISTS idx_tournament_rewards_tournament ON app.tournament_rewards(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_rewards_league ON app.tournament_rewards(league_id);
CREATE INDEX IF NOT EXISTS idx_tournament_rewards_rank ON app.tournament_rewards(rank_from, rank_to);

CREATE INDEX IF NOT EXISTS idx_competitive_events_tournament ON app.competitive_events(tournament_id);
CREATE INDEX IF NOT EXISTS idx_competitive_events_league ON app.competitive_events(league_id);
CREATE INDEX IF NOT EXISTS idx_competitive_events_type ON app.competitive_events(event_type);
CREATE INDEX IF NOT EXISTS idx_competitive_events_created ON app.competitive_events(created_at);

-- Activer Realtime pour les tables critiques
ALTER PUBLICATION supabase_realtime ADD TABLE app.tournaments;
ALTER PUBLICATION supabase_realtime ADD TABLE app.tournament_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE app.tournament_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE app.leagues;
ALTER PUBLICATION supabase_realtime ADD TABLE app.league_participations;
ALTER PUBLICATION supabase_realtime ADD TABLE app.league_matches;

-- RLS (Row Level Security) policies
ALTER TABLE app.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tournament_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.league_participations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.league_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tournament_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.competitive_events ENABLE ROW LEVEL SECURITY;

-- Politiques RLS pour les tournois
CREATE POLICY "Users can view tournaments" ON app.tournaments
    FOR SELECT USING (
        is_private = false OR
        created_by = auth.uid() OR
        id IN (
            SELECT tournament_id FROM app.tournament_participants 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create tournaments" ON app.tournaments
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "Creators can update their tournaments" ON app.tournaments
    FOR UPDATE USING (created_by = auth.uid());

CREATE POLICY "Creators can delete their tournaments" ON app.tournaments
    FOR DELETE USING (created_by = auth.uid());

-- Politiques RLS pour les participants
CREATE POLICY "Users can view tournament participants" ON app.tournament_participants
    FOR SELECT USING (
        user_id = auth.uid() OR
        tournament_id IN (
            SELECT id FROM app.tournaments 
            WHERE is_private = false OR created_by = auth.uid()
        )
    );

CREATE POLICY "Users can manage their participation" ON app.tournament_participants
    FOR ALL USING (user_id = auth.uid());

-- Politiques RLS pour les matchs de tournoi
CREATE POLICY "Users can view tournament matches" ON app.tournament_matches
    FOR SELECT USING (
        tournament_id IN (
            SELECT id FROM app.tournaments 
            WHERE is_private = false OR created_by = auth.uid()
        ) OR
        id IN (
            SELECT id FROM app.tournament_participants 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Tournament creators can manage matches" ON app.tournament_matches
    FOR ALL USING (
        tournament_id IN (
            SELECT id FROM app.tournaments WHERE created_by = auth.uid()
        )
    );

-- Politiques RLS pour les ligues
CREATE POLICY "Everyone can view leagues" ON app.leagues
    FOR SELECT USING (is_active = true);

CREATE POLICY "Users can manage their leagues" ON app.leagues
    FOR ALL USING (created_by = auth.uid());

-- Politiques RLS pour les participations aux ligues
CREATE POLICY "Users can view league participations" ON app.league_participations
    FOR SELECT USING (
        user_id = auth.uid() OR
        league_id IN (
            SELECT id FROM app.leagues WHERE is_active = true
        )
    );

CREATE POLICY "Users can manage their league participation" ON app.league_participations
    FOR ALL USING (user_id = auth.uid());

-- Politiques RLS pour les matchs de ligues
CREATE POLICY "Users can view league matches" ON app.league_matches
    FOR SELECT USING (
        participant1_id IN (
            SELECT id FROM app.league_participations WHERE user_id = auth.uid()
        ) OR
        participant2_id IN (
            SELECT id FROM app.league_participations WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "League participants can manage their matches" ON app.league_matches
    FOR ALL USING (
        participant1_id IN (
            SELECT id FROM app.league_participations WHERE user_id = auth.uid()
        ) OR
        participant2_id IN (
            SELECT id FROM app.league_participations WHERE user_id = auth.uid()
        )
    );

-- Politiques RLS pour les récompenses
CREATE POLICY "Everyone can view rewards" ON app.tournament_rewards
    FOR SELECT USING (true);

-- Politiques RLS pour les événements
CREATE POLICY "Users can view competitive events" ON app.competitive_events
    FOR SELECT USING (
        tournament_id IN (
            SELECT id FROM app.tournaments 
            WHERE is_private = false OR created_by = auth.uid()
        ) OR
        league_id IN (
            SELECT id FROM app.leagues WHERE is_active = true
        ) OR
        participant_id = auth.uid()
    );

-- Trigger pour mettre à jour les timestamps
CREATE OR REPLACE FUNCTION app.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_tournaments_updated_at
    BEFORE UPDATE ON app.tournaments
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER tr_leagues_updated_at
    BEFORE UPDATE ON app.leagues
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour mettre à jour le nombre de participants
CREATE OR REPLACE FUNCTION app.update_tournament_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.tournaments 
        SET current_participants = current_participants + 1 
        WHERE id = NEW.tournament_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.tournaments 
        SET current_participants = GREATEST(current_participants - 1, 0) 
        WHERE id = OLD.tournament_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_update_tournament_participant_count
    AFTER INSERT OR DELETE ON app.tournament_participants
    FOR EACH ROW EXECUTE FUNCTION app.update_tournament_participant_count();

-- Trigger pour mettre à jour le nombre de joueurs dans les ligues
CREATE OR REPLACE FUNCTION app.update_league_player_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.leagues 
        SET current_players = current_players + 1 
        WHERE id = NEW.league_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.leagues 
        SET current_players = GREATEST(current_players - 1, 0) 
        WHERE id = OLD.league_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_update_league_player_count
    AFTER INSERT OR DELETE ON app.league_participations
    FOR EACH ROW EXECUTE FUNCTION app.update_league_player_count();

-- Fonction pour générer des brackets de tournoi
CREATE OR REPLACE FUNCTION app.generate_tournament_bracket(
    p_tournament_id UUID,
    p_participant_count INTEGER
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    bracket_data JSONB
) AS $$
DECLARE
    participant_count INTEGER;
    rounds_needed INTEGER;
    bracket_data JSONB := '[]';
BEGIN
    -- Vérifier le tournoi
    SELECT COUNT(*) INTO participant_count
    FROM app.tournament_participants 
    WHERE tournament_id = p_tournament_id AND status = 'registered';
    
    IF participant_count = 0 THEN
        RETURN QUERY SELECT false, 'No registered participants', '[]'::JSONB;
    END IF;
    
    -- Calculer le nombre de rounds nécessaires
    rounds_needed := CEIL(LOG(participant_count, 2));
    
    -- Générer le bracket (simplifié pour single elimination)
    bracket_data := json_build_object(
        'tournament_id', p_tournament_id,
        'participant_count', participant_count,
        'rounds_needed', rounds_needed,
        'matches', json_build_array()
    );
    
    RETURN QUERY SELECT true, 'Bracket generated successfully', bracket_data;
END;
$$ LANGUAGE plpgsql;

-- Données de test (optionnel)
INSERT INTO app.leagues (name, description, game_type, division, season_number) VALUES
    ('Bronze League', 'Entry-level competitive league', 'Market Master', 'bronze', 1),
    ('Silver League', 'Intermediate competitive league', 'Market Master', 'silver', 1),
    ('Gold League', 'Advanced competitive league', 'Market Master', 'gold', 1),
    ('Platinum League', 'Expert competitive league', 'Market Master', 'platinum', 1)
ON CONFLICT (name, season_number) DO NOTHING;
