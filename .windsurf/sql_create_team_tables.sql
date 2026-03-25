-- ========================================
-- PHASE 6: ADVANCED COMPETITIVE FEATURES
-- TABLES TEAMS ET TEAM TOURNAMENTS
-- ========================================

-- Table des équipes/teams
CREATE TABLE IF NOT EXISTS app.teams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    tag TEXT, -- Tag d'équipe (ex: [ABC], [XYZ])
    description TEXT,
    logo_url TEXT,
    captain_id UUID REFERENCES app.students(id),
    max_members INTEGER DEFAULT 5,
    team_type TEXT DEFAULT 'casual', -- casual, competitive, professional
    status TEXT DEFAULT 'active', -- active, inactive, disbanded
    elo_rating DECIMAL(10,2) DEFAULT 1200.00,
    total_wins INTEGER DEFAULT 0,
    total_losses INTEGER DEFAULT 0,
    total_matches INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    best_streak INTEGER DEFAULT 0,
    points_earned INTEGER DEFAULT 0,
    achievements JSONB DEFAULT '[]',
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des membres d'équipes
CREATE TABLE IF NOT EXISTS app.team_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    team_id UUID REFERENCES app.teams(id) ON DELETE CASCADE,
    player_id UUID REFERENCES app.students(id),
    role TEXT DEFAULT 'member', -- captain, co_captain, member, recruit
    status TEXT DEFAULT 'active', -- active, inactive, kicked, left
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    left_at TIMESTAMP WITH TIME ZONE,
    contribution_points INTEGER DEFAULT 0,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    matches_lost INTEGER DEFAULT 0,
    personal_elo_contribution DECIMAL(10,2) DEFAULT 0.00,
    notes TEXT,
    UNIQUE(team_id, player_id)
);

-- Table des tournois par équipes
CREATE TABLE IF NOT EXISTS app.team_tournaments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    banner_url TEXT,
    tournament_type TEXT DEFAULT 'elimination', -- elimination, round_robin, swiss, league
    format TEXT DEFAULT 'single_elimination', -- single_elimination, double_elimination, best_of_3, best_of_5
    game_type TEXT NOT NULL,
    max_teams INTEGER DEFAULT 16,
    min_teams INTEGER DEFAULT 4,
    team_size INTEGER DEFAULT 5,
    registration_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    registration_end TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'),
    start_date TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '8 days'),
    end_date TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '15 days'),
    prize_pool INTEGER DEFAULT 0,
    entry_fee INTEGER DEFAULT 0,
    elo_min DECIMAL(10,2) DEFAULT 0.00,
    elo_max DECIMAL(10,2) DEFAULT 9999.99,
    is_featured BOOLEAN DEFAULT FALSE,
    is_private BOOLEAN DEFAULT FALSE,
    auto_start BOOLEAN DEFAULT TRUE,
    spectator_enabled BOOLEAN DEFAULT TRUE,
    stream_enabled BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'draft', -- draft, registration, active, completed, cancelled
    current_round INTEGER DEFAULT 0,
    total_rounds INTEGER DEFAULT 0,
    settings JSONB DEFAULT '{}',
    created_by UUID REFERENCES app.students(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des inscriptions aux tournois par équipes
CREATE TABLE IF NOT EXISTS app.team_tournament_registrations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.team_tournaments(id) ON DELETE CASCADE,
    team_id UUID REFERENCES app.teams(id) ON DELETE CASCADE,
    registration_status TEXT DEFAULT 'registered', -- registered, confirmed, withdrawn, disqualified
    seed_number INTEGER,
    current_round INTEGER DEFAULT 0,
    current_position INTEGER DEFAULT 0,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    matches_lost INTEGER DEFAULT 0,
    matches_drawn INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    elo_rating_before DECIMAL(10,2),
    elo_rating_after DECIMAL(10,2),
    elo_change DECIMAL(10,2) DEFAULT 0.00,
    prize_won INTEGER DEFAULT 0,
    eliminated_by UUID REFERENCES app.teams(id),
    eliminated_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tournament_id, team_id)
);

-- Table des matchs de tournois par équipes
CREATE TABLE IF NOT EXISTS app.team_tournament_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.team_tournaments(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL,
    match_number INTEGER NOT NULL,
    team1_id UUID REFERENCES app.teams(id),
    team2_id UUID REFERENCES app.teams(id),
    winner_id UUID REFERENCES app.teams(id),
    status TEXT DEFAULT 'scheduled', -- scheduled, in_progress, completed, cancelled
    scheduled_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    best_of INTEGER DEFAULT 1,
    team1_score INTEGER DEFAULT 0,
    team2_score INTEGER DEFAULT 0,
    team1_points INTEGER DEFAULT 0,
    team2_points INTEGER DEFAULT 0,
    next_match_id UUID REFERENCES app.team_tournament_matches(id),
    bracket_position TEXT,
    spectator_count INTEGER DEFAULT 0,
    stream_url TEXT,
    replay_url TEXT,
    match_data JSONB DEFAULT '{}', -- Données détaillées du match
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des classements de tournois par équipes
CREATE TABLE IF NOT EXISTS app.team_tournament_standings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.team_tournaments(id) ON DELETE CASCADE,
    team_id UUID REFERENCES app.teams(id) ON DELETE CASCADE,
    rank_position INTEGER NOT NULL,
    division TEXT,
    status TEXT DEFAULT 'active', -- active, eliminated, winner, disqualified
    current_round INTEGER DEFAULT 0,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    matches_lost INTEGER DEFAULT 0,
    matches_drawn INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    win_rate DECIMAL(5,2) DEFAULT 0.00,
    elo_rating_before DECIMAL(10,2),
    elo_rating_after DECIMAL(10,2),
    elo_change DECIMAL(10,2) DEFAULT 0.00,
    prize_won INTEGER DEFAULT 0,
    promotion_points INTEGER DEFAULT 0,
    demotion_points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tournament_id, team_id)
);

-- Table des récompenses de tournois par équipes
CREATE TABLE IF NOT EXISTS app.team_tournament_rewards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.team_tournaments(id) ON DELETE CASCADE,
    rank_from INTEGER NOT NULL,
    rank_to INTEGER NOT NULL,
    reward_type TEXT NOT NULL, -- cash, points, badge, item, promotion, trophy
    reward_value INTEGER DEFAULT 0,
    reward_name TEXT,
    reward_description TEXT,
    reward_icon TEXT,
    reward_data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des événements compétitifs par équipes
CREATE TABLE IF NOT EXISTS app.team_competitive_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.team_tournaments(id),
    match_id UUID REFERENCES app.team_tournament_matches(id),
    team_id UUID REFERENCES app.teams(id),
    event_type TEXT NOT NULL, -- team_created, team_disbanded, tournament_created, match_completed, team_eliminated, promotion, relegation, achievement
    event_data JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table du mode spectateur
CREATE TABLE IF NOT EXISTS app.spectator_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES app.students(id),
    tournament_id UUID REFERENCES app.team_tournaments(id),
    match_id UUID REFERENCES app.team_tournament_matches(id),
    session_type TEXT DEFAULT 'live', -- live, replay, highlight
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER DEFAULT 0,
    interactions_count INTEGER DEFAULT 0, -- chats, reactions, etc.
    quality_preference TEXT DEFAULT 'auto', -- auto, low, medium, high
    device_info JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des statistiques avancées
CREATE TABLE IF NOT EXISTS app.advanced_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES app.students(id),
    team_id UUID REFERENCES app.teams(id),
    tournament_id UUID REFERENCES app.team_tournaments(id),
    match_id UUID REFERENCES app.team_tournament_matches(id),
    event_type TEXT NOT NULL, -- game_session, tournament_participation, team_performance, spectator_session
    event_data JSONB DEFAULT '{}',
    performance_metrics JSONB DEFAULT '{}', -- FPS, latency, device performance
    behavior_analytics JSONB DEFAULT '{}', -- Time spent, actions taken, patterns
    engagement_metrics JSONB DEFAULT '{}', -- Interactions, social features used
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des saisons compétitives
CREATE TABLE IF NOT EXISTS app.competitive_seasons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    season_number INTEGER NOT NULL,
    game_type TEXT NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    end_date TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '3 months'),
    status TEXT DEFAULT 'upcoming', -- upcoming, active, completed, archived
    prize_pool INTEGER DEFAULT 0,
    featured_teams JSONB DEFAULT '[]',
    rules JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des participations saisonnières par équipes
CREATE TABLE IF NOT EXISTS app.team_season_participations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    season_id UUID REFERENCES app.competitive_seasons(id) ON DELETE CASCADE,
    team_id UUID REFERENCES app.teams(id) ON DELETE CASCADE,
    division TEXT DEFAULT 'main',
    rank_position INTEGER,
    points INTEGER DEFAULT 0,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    matches_lost INTEGER DEFAULT 0,
    matches_drawn INTEGER DEFAULT 0,
    elo_rating_start DECIMAL(10,2),
    elo_rating_end DECIMAL(10,2),
    elo_change DECIMAL(10,2) DEFAULT 0.00,
    promotion_status TEXT DEFAULT 'none', -- promoted, relegated, none
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(season_id, team_id)
);

-- ========================================
-- INDEXES
-- ========================================

-- Indexes pour teams
CREATE INDEX IF NOT EXISTS idx_teams_captain_id ON app.teams(captain_id);
CREATE INDEX IF NOT EXISTS idx_teams_status ON app.teams(status);
CREATE INDEX IF NOT EXISTS idx_teams_team_type ON app.teams(team_type);
CREATE INDEX IF NOT EXISTS idx_teams_elo_rating ON app.teams(elo_rating DESC);
CREATE INDEX IF NOT EXISTS idx_teams_created_at ON app.teams(created_at DESC);

-- Indexes pour team_members
CREATE INDEX IF NOT EXISTS idx_team_members_team_id ON app.team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_player_id ON app.team_members(player_id);
CREATE INDEX IF NOT EXISTS idx_team_members_role ON app.team_members(role);
CREATE INDEX IF NOT EXISTS idx_team_members_status ON app.team_members(status);

-- Indexes pour team_tournaments
CREATE INDEX IF NOT EXISTS idx_team_tournaments_status ON app.team_tournaments(status);
CREATE INDEX IF NOT EXISTS idx_team_tournaments_game_type ON app.team_tournaments(game_type);
CREATE INDEX IF NOT EXISTS idx_team_tournaments_start_date ON app.team_tournaments(start_date);
CREATE INDEX IF NOT EXISTS idx_team_tournaments_is_featured ON app.team_tournaments(is_featured);
CREATE INDEX IF NOT EXISTS idx_team_tournaments_created_at ON app.team_tournaments(created_at DESC);

-- Indexes pour team_tournament_registrations
CREATE INDEX IF NOT EXISTS idx_team_tournament_regs_tournament_id ON app.team_tournament_registrations(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_regs_team_id ON app.team_tournament_registrations(team_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_regs_status ON app.team_tournament_registrations(registration_status);
CREATE INDEX IF NOT EXISTS idx_team_tournament_regs_seed_number ON app.team_tournament_registrations(seed_number);

-- Indexes pour team_tournament_matches
CREATE INDEX IF NOT EXISTS idx_team_tournament_matches_tournament_id ON app.team_tournament_matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_matches_team1_id ON app.team_tournament_matches(team1_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_matches_team2_id ON app.team_tournament_matches(team2_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_matches_status ON app.team_tournament_matches(status);
CREATE INDEX IF NOT EXISTS idx_team_tournament_matches_round_number ON app.team_tournament_matches(round_number);
CREATE INDEX IF NOT EXISTS idx_team_tournament_matches_scheduled_at ON app.team_tournament_matches(scheduled_at);

-- Indexes pour team_tournament_standings
CREATE INDEX IF NOT EXISTS idx_team_tournament_standings_tournament_id ON app.team_tournament_standings(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_standings_team_id ON app.team_tournament_standings(team_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_standings_rank_position ON app.team_tournament_standings(rank_position);
CREATE INDEX IF NOT EXISTS idx_team_tournament_standings_points ON app.team_tournament_standings(points DESC);

-- Indexes pour team_tournament_rewards
CREATE INDEX IF NOT EXISTS idx_team_tournament_rewards_tournament_id ON app.team_tournament_rewards(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_tournament_rewards_rank_from ON app.team_tournament_rewards(rank_from);
CREATE INDEX IF NOT EXISTS idx_team_tournament_rewards_rank_to ON app.team_tournament_rewards(rank_to);

-- Indexes pour team_competitive_events
CREATE INDEX IF NOT EXISTS idx_team_competitive_events_tournament_id ON app.team_competitive_events(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_competitive_events_team_id ON app.team_competitive_events(team_id);
CREATE INDEX IF NOT EXISTS idx_team_competitive_events_event_type ON app.team_competitive_events(event_type);
CREATE INDEX IF NOT EXISTS idx_team_competitive_events_created_at ON app.team_competitive_events(created_at DESC);

-- Indexes pour spectator_sessions
CREATE INDEX IF NOT EXISTS idx_spectator_sessions_user_id ON app.spectator_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_spectator_sessions_tournament_id ON app.spectator_sessions(tournament_id);
CREATE INDEX IF NOT EXISTS idx_spectator_sessions_match_id ON app.spectator_sessions(match_id);
CREATE INDEX IF NOT EXISTS idx_spectator_sessions_started_at ON app.spectator_sessions(started_at DESC);

-- Indexes pour advanced_analytics
CREATE INDEX IF NOT EXISTS idx_advanced_analytics_user_id ON app.advanced_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_advanced_analytics_team_id ON app.advanced_analytics(team_id);
CREATE INDEX IF NOT EXISTS idx_advanced_analytics_event_type ON app.advanced_analytics(event_type);
CREATE INDEX IF NOT EXISTS idx_advanced_analytics_created_at ON app.advanced_analytics(created_at DESC);

-- Indexes pour competitive_seasons
CREATE INDEX IF NOT EXISTS idx_competitive_seasons_status ON app.competitive_seasons(status);
CREATE INDEX IF NOT EXISTS idx_competitive_seasons_game_type ON app.competitive_seasons(game_type);
CREATE INDEX IF NOT EXISTS idx_competitive_seasons_start_date ON app.competitive_seasons(start_date);

-- Indexes pour team_season_participations
CREATE INDEX IF NOT EXISTS idx_team_season_participations_season_id ON app.team_season_participations(season_id);
CREATE INDEX IF NOT EXISTS idx_team_season_participations_team_id ON app.team_season_participations(team_id);
CREATE INDEX IF NOT EXISTS idx_team_season_participations_division ON app.team_season_participations(division);
CREATE INDEX IF NOT EXISTS idx_team_season_participations_rank_position ON app.team_season_participations(rank_position);
CREATE INDEX IF NOT EXISTS idx_team_season_participations_points ON app.team_season_participations(points DESC);

-- ========================================
-- RLS POLICIES
-- ========================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_tournament_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_tournament_standings ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_tournament_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_competitive_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.spectator_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.advanced_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.competitive_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.team_season_participations ENABLE ROW LEVEL SECURITY;

-- Policies pour teams
CREATE POLICY "Users can view teams" ON app.teams
    FOR SELECT USING (status = 'active');

CREATE POLICY "Users can create teams" ON app.teams
    FOR INSERT WITH CHECK (captain_id = auth.uid());

CREATE POLICY "Team captains can update their teams" ON app.teams
    FOR UPDATE USING (captain_id = auth.uid());

CREATE POLICY "Team captains can delete their teams" ON app.teams
    FOR DELETE USING (captain_id = auth.uid());

-- Policies pour team_members
CREATE POLICY "Users can view team members" ON app.team_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_members tm 
            WHERE tm.team_id = team_members.team_id 
            AND tm.player_id = auth.uid() 
            AND tm.status = 'active'
        )
    );

CREATE POLICY "Team captains can manage members" ON app.team_members
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM app.teams t 
            WHERE t.id = team_members.team_id 
            AND t.captain_id = auth.uid()
        )
    );

CREATE POLICY "Users can view their own team memberships" ON app.team_members
    FOR SELECT USING (player_id = auth.uid());

-- Policies pour team_tournaments
CREATE POLICY "Users can view tournaments" ON app.team_tournaments
    FOR SELECT USING (status IN ('registration', 'active', 'completed'));

CREATE POLICY "Users can create tournaments" ON app.team_tournaments
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "Tournament creators can update their tournaments" ON app.team_tournaments
    FOR UPDATE USING (created_by = auth.uid());

CREATE POLICY "Tournament creators can delete their tournaments" ON app.team_tournaments
    FOR DELETE USING (created_by = auth.uid() AND status = 'draft');

-- Policies pour team_tournament_registrations
CREATE POLICY "Users can view tournament registrations" ON app.team_tournament_registrations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_members tm 
            WHERE tm.team_id = team_tournament_registrations.team_id 
            AND tm.player_id = auth.uid() 
            AND tm.status = 'active'
        )
    );

CREATE POLICY "Team captains can register their teams" ON app.team_tournament_registrations
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM app.team_members tm 
            WHERE tm.team_id = team_tournament_registrations.team_id 
            AND tm.player_id = auth.uid() 
            AND tm.role IN ('captain', 'co_captain')
        )
    );

-- Policies pour team_tournament_matches
CREATE POLICY "Users can view tournament matches" ON app.team_tournament_matches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_tournament_registrations tr 
            WHERE tr.tournament_id = team_tournament_matches.tournament_id 
            AND EXISTS (
                SELECT 1 FROM app.team_members tm 
                WHERE tm.team_id = tr.team_id 
                AND tm.player_id = auth.uid() 
                AND tm.status = 'active'
            )
        )
    );

-- Policies pour team_tournament_standings
CREATE POLICY "Users can view tournament standings" ON app.team_tournament_standings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_tournament_registrations tr 
            WHERE tr.tournament_id = team_tournament_standings.tournament_id 
            AND EXISTS (
                SELECT 1 FROM app.team_members tm 
                WHERE tm.team_id = tr.team_id 
                AND tm.player_id = auth.uid() 
                AND tm.status = 'active'
            )
        )
    );

-- Policies pour team_tournament_rewards
CREATE POLICY "Users can view tournament rewards" ON app.team_tournament_rewards
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_tournaments t 
            WHERE t.id = team_tournament_rewards.tournament_id 
            AND t.status IN ('registration', 'active', 'completed')
        )
    );

-- Policies pour team_competitive_events
CREATE POLICY "Users can view competitive events" ON app.team_competitive_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_members tm 
            WHERE tm.team_id = team_competitive_events.team_id 
            AND tm.player_id = auth.uid() 
            AND tm.status = 'active'
        )
    );

-- Policies pour spectator_sessions
CREATE POLICY "Users can manage their spectator sessions" ON app.spectator_sessions
    FOR ALL USING (user_id = auth.uid());

-- Policies pour advanced_analytics
CREATE POLICY "Users can manage their analytics" ON app.advanced_analytics
    FOR ALL USING (user_id = auth.uid());

-- Policies pour competitive_seasons
CREATE POLICY "Users can view seasons" ON app.competitive_seasons
    FOR SELECT USING (status IN ('active', 'completed'));

-- Policies pour team_season_participations
CREATE POLICY "Users can view season participations" ON app.team_season_participations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.team_members tm 
            WHERE tm.team_id = team_season_participations.team_id 
            AND tm.player_id = auth.uid() 
            AND tm.status = 'active'
        )
    );

-- ========================================
-- REALTIME PUBLICATIONS
-- ========================================

-- Activer Realtime sur les tables pertinentes
ALTER PUBLICATION supabase_realtime ADD TABLE app.teams;
ALTER PUBLICATION supabase_realtime ADD TABLE app.team_tournaments;
ALTER PUBLICATION supabase_realtime ADD TABLE app.team_tournament_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE app.team_tournament_standings;
ALTER PUBLICATION supabase_realtime ADD TABLE app.team_competitive_events;
ALTER PUBLICATION supabase_realtime ADD TABLE app.spectator_sessions;

-- ========================================
-- TRIGGERS AND FUNCTIONS
-- ========================================

-- Fonction pour mettre à jour le statut d'une équipe
CREATE OR REPLACE FUNCTION app_update_team_status()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Mettre à jour updated_at
        NEW.updated_at = NOW();
        
        -- Si tous les membres sont inactifs, marquer l'équipe comme inactive
        IF OLD.status = 'active' THEN
            DECLARE
                active_members_count INTEGER;
            BEGIN
                SELECT COUNT(*) INTO active_members_count
                FROM app.team_members
                WHERE team_id = NEW.id AND status = 'active';
                
                IF active_members_count = 0 THEN
                    NEW.status = 'inactive';
                END IF;
            END;
        END IF;
        
        RETURN NEW;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour le statut des équipes
CREATE TRIGGER trigger_update_team_status
    BEFORE UPDATE ON app.teams
    FOR EACH ROW
    EXECUTE FUNCTION app_update_team_status();

-- Fonction pour calculer l'ELO d'une équipe
CREATE OR REPLACE FUNCTION app_calculate_team_elo(p_team_id UUID)
RETURNS DECIMAL AS $$
DECLARE
    team_elo DECIMAL;
BEGIN
    -- Calculer l'ELO moyen de l'équipe basé sur les membres actifs
    SELECT COALESCE(AVG(
        CASE 
            WHEN tm.role = 'captain' THEN pr.elo_rating * 1.1  -- Captain a plus de poids
            WHEN tm.role = 'co_captain' THEN pr.elo_rating * 1.05
            ELSE pr.elo_rating
        END
    ), 1200.00)
    INTO team_elo
    FROM app.team_members tm
    JOIN app.player_rankings pr ON tm.player_id = pr.player_id
    WHERE tm.team_id = p_team_id AND tm.status = 'active';
    
    -- Mettre à jour l'ELO de l'équipe
    UPDATE app.teams
    SET elo_rating = team_elo,
        updated_at = NOW()
    WHERE id = p_team_id;
    
    RETURN team_elo;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour générer un bracket de tournoi par équipes
CREATE OR REPLACE FUNCTION app_generate_team_tournament_bracket(p_tournament_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_teams JSONB;
    v_matches JSONB := '[]'::jsonb;
    v_team_count INTEGER;
    v_current_round INTEGER := 1;
    v_match_index INTEGER := 1;
    v_rounds_needed INTEGER;
BEGIN
    -- Récupérer les équipes inscrites
    SELECT jsonb_agg(
        jsonb_build_object(
            'team_id', tr.team_id,
            'seed', tr.seed_number,
            'team_name', t.name,
            'team_elo', t.elo_rating
        )
    ) INTO v_teams
    FROM app.team_tournament_registrations tr
    JOIN app.teams t ON tr.team_id = t.id
    WHERE tr.tournament_id = p_tournament_id 
      AND tr.registration_status = 'confirmed'
    ORDER BY tr.seed_number, t.elo_rating DESC;
    
    v_team_count := jsonb_array_length(v_teams);
    
    -- Calculer le nombre de rounds nécessaires
    v_rounds_needed := CEIL(LOG2(v_team_count));
    
    -- Mettre à jour le tournoi
    UPDATE app.team_tournaments
    SET total_rounds = v_rounds_needed,
        current_round = 1,
        status = 'active'
    WHERE id = p_tournament_id;
    
    -- Générer les matchs du premier round
    FOR i IN 0..v_team_count-1 BY 2 LOOP
        DECLARE
            v_team1 JSONB;
            v_team2 JSONB;
            v_match_id UUID := gen_random_uuid();
        BEGIN
            v_team1 := v_teams -> i;
            v_team2 := CASE 
                WHEN i + 1 < v_team_count THEN v_teams -> (i + 1)
                ELSE NULL  -- Bye pour l'équipe si nombre impair
            END;
            
            -- Insérer le match
            INSERT INTO app.team_tournament_matches (
                id, tournament_id, round_number, match_number, 
                team1_id, team2_id, status
            ) VALUES (
                v_match_id, p_tournament_id, v_current_round, v_match_index,
                (v_team1 ->> 'team_id')::uuid,
                CASE WHEN v_team2 IS NOT NULL THEN (v_team2 ->> 'team_id')::uuid ELSE NULL END,
                'scheduled'
            );
            
            -- Mettre à jour les inscriptions
            UPDATE app.team_tournament_registrations
            SET current_round = v_current_round
            WHERE tournament_id = p_tournament_id 
              AND team_id IN ((v_team1 ->> 'team_id')::uuid, CASE WHEN v_team2 IS NOT NULL THEN (v_team2 ->> 'team_id')::uuid ELSE NULL END);
            
            -- Ajouter au résultat
            v_matches := v_matches || jsonb_build_object(
                'match_id', v_match_id,
                'round', v_current_round,
                'team1', v_team1,
                'team2', v_team2,
                'status', 'scheduled'
            );
            
            v_match_index := v_match_index + 1;
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'matches', v_matches,
        'rounds', v_rounds_needed,
        'teams', v_team_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour traiter le résultat d'un match d'équipe
CREATE OR REPLACE FUNCTION app_process_team_match_result(
    p_match_id UUID,
    p_winner_id UUID,
    p_team1_score INTEGER DEFAULT 0,
    p_team2_score INTEGER DEFAULT 0,
    p_team1_points INTEGER DEFAULT 0,
    p_team2_points INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    v_match RECORD;
    v_tournament_id UUID;
    v_round_number INTEGER;
    v_next_match_id UUID;
    v_elo_change1 DECIMAL;
    v_elo_change2 DECIMAL;
BEGIN
    -- Récupérer les informations du match
    SELECT * INTO v_match
    FROM app.team_tournament_matches
    WHERE id = p_match_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;
    
    v_tournament_id := v_match.tournament_id;
    v_round_number := v_match.round_number;
    v_next_match_id := v_match.next_match_id;
    
    -- Calculer les changements d'ELO
    SELECT app_calculate_elo_change(
        v_match.team1_id, 
        v_match.team2_id, 
        CASE WHEN p_winner_id = v_match.team1_id THEN 'win' ELSE 'loss' END
    ) INTO v_elo_change1;
    
    SELECT app_calculate_elo_change(
        v_match.team2_id, 
        v_match.team1_id, 
        CASE WHEN p_winner_id = v_match.team2_id THEN 'win' ELSE 'loss' END
    ) INTO v_elo_change2;
    
    -- Mettre à jour le match
    UPDATE app.team_tournament_matches
    SET winner_id = p_winner_id,
        team1_score = p_team1_score,
        team2_score = p_team2_score,
        team1_points = p_team1_points,
        team2_points = p_team2_points,
        status = 'completed',
        completed_at = NOW()
    WHERE id = p_match_id;
    
    -- Mettre à jour les ELO des équipes
    UPDATE app.teams
    SET elo_rating = elo_rating + v_elo_change1,
        total_matches = total_matches + 1,
        total_wins = CASE WHEN p_winner_id = id THEN total_wins + 1 ELSE total_wins END,
        total_losses = CASE WHEN p_winner_id != id THEN total_losses + 1 ELSE total_losses END,
        updated_at = NOW()
    WHERE id = v_match.team1_id;
    
    UPDATE app.teams
    SET elo_rating = elo_rating + v_elo_change2,
        total_matches = total_matches + 1,
        total_wins = CASE WHEN p_winner_id = id THEN total_wins + 1 ELSE total_wins END,
        total_losses = CASE WHEN p_winner_id != id THEN total_losses + 1 ELSE total_losses END,
        updated_at = NOW()
    WHERE id = v_match.team2_id;
    
    -- Mettre à jour les inscriptions
    UPDATE app.team_tournament_registrations
    SET matches_played = matches_played + 1,
        matches_won = CASE WHEN p_winner_id = team_id THEN matches_won + 1 ELSE matches_won END,
        matches_lost = CASE WHEN p_winner_id != team_id THEN matches_lost + 1 ELSE matches_lost END,
        points = points + CASE WHEN team_id = v_match.team1_id THEN p_team1_points ELSE p_team2_points END,
        elo_change = CASE WHEN team_id = v_match.team1_id THEN v_elo_change1 ELSE v_elo_change2 END
    WHERE tournament_id = v_tournament_id 
      AND team_id IN (v_match.team1_id, v_match.team2_id);
    
    -- Éliminer l'équipe perdante
    IF v_next_match_id IS NULL THEN
        -- Fin du tournoi
        UPDATE app.team_tournament_registrations
        SET status = CASE WHEN team_id = p_winner_id THEN 'winner' ELSE 'eliminated' END,
            eliminated_at = NOW()
        WHERE tournament_id = v_tournament_id 
          AND team_id IN (v_match.team1_id, v_match.team2_id);
    ELSE
        -- Éliminer l'équipe perdante et qualifier le vainqueur
        UPDATE app.team_tournament_registrations
        SET status = CASE WHEN team_id = p_winner_id THEN 'active' ELSE 'eliminated' END,
            eliminated_at = CASE WHEN team_id != p_winner_id THEN NOW() ELSE NULL END,
            current_round = CASE WHEN team_id = p_winner_id THEN v_round_number + 1 ELSE current_round END
        WHERE tournament_id = v_tournament_id 
          AND team_id IN (v_match.team1_id, v_match.team2_id);
        
        -- Mettre à jour le match suivant
        UPDATE app.team_tournament_matches
        SET team1_id = CASE WHEN team1_id IS NULL THEN p_winner_id ELSE team1_id END,
            team2_id = CASE WHEN team2_id IS NULL THEN p_winner_id ELSE team2_id END
        WHERE id = v_next_match_id;
    END IF;
    
    -- Enregistrer l'événement compétitif
    INSERT INTO app.team_competitive_events (
        tournament_id, match_id, team_id, event_type, event_data
    ) VALUES (
        v_tournament_id, p_match_id, p_winner_id, 'match_completed',
        jsonb_build_object(
            'winner_id', p_winner_id,
            'team1_score', p_team1_score,
            'team2_score', p_team2_score,
            'elo_change1', v_elo_change1,
            'elo_change2', v_elo_change2
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'winner_id', p_winner_id,
        'elo_change1', v_elo_change1,
        'elo_change2', v_elo_change2
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour calculer le changement d'ELO entre deux équipes
CREATE OR REPLACE FUNCTION app_calculate_elo_change(
    p_team1_id UUID,
    p_team2_id UUID,
    p_result TEXT
) RETURNS DECIMAL AS $$
DECLARE
    v_team1_elo DECIMAL;
    v_team2_elo DECIMAL;
    v_elo_change DECIMAL;
    v_k_factor DECIMAL := 32.0;
BEGIN
    -- Récupérer les ELO actuels
    SELECT elo_rating INTO v_team1_elo FROM app.teams WHERE id = p_team1_id;
    SELECT elo_rating INTO v_team2_elo FROM app.teams WHERE id = p_team2_id;
    
    -- Calculer le changement d'ELO
    v_elo_change := v_k_factor * (
        CASE p_result
            WHEN 'win' THEN 1.0
            WHEN 'draw' THEN 0.5
            ELSE 0.0
        END - (1.0 / (1.0 + POWER(10.0, (v_team2_elo - v_team1_elo) / 400.0)))
    );
    
    RETURN v_elo_change;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
