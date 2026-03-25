-- =====================================================
-- KELLENGE TOURNAMENTS & LEAGUES RPCs - PHASE 5
-- Procédures stockées pour tournois et ligues
-- =====================================================

-- 1. RPC: Créer un tournoi
CREATE OR REPLACE FUNCTION app.tournament_create(
    p_name VARCHAR(100),
    p_description TEXT,
    p_game_type VARCHAR(50),
    p_tournament_type VARCHAR(20) DEFAULT 'elimination',
    p_format VARCHAR(20) DEFAULT 'single_elimination',
    p_max_participants INTEGER DEFAULT 16,
    p_min_participants INTEGER DEFAULT 4,
    p_registration_start TIMESTAMPTZ DEFAULT NOW(),
    p_registration_end TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
    p_start_date TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 day',
    p_end_date TIMESTAMPTZ DEFAULT NOW() + INTERVAL '2 days',
    p_prize_pool INTEGER DEFAULT 0,
    p_entry_fee INTEGER DEFAULT 0,
    p_is_featured BOOLEAN DEFAULT FALSE,
    p_is_private BOOLEAN DEFAULT FALSE,
    p_elo_min INTEGER DEFAULT 0,
    p_elo_max INTEGER DEFAULT 3000,
    p_auto_start BOOLEAN DEFAULT TRUE,
    p_settings JSONB DEFAULT '{}'
)
RETURNS TABLE (
    success BOOLEAN,
    tournament_id UUID,
    message TEXT
) AS $$
DECLARE
    new_tournament_id UUID;
BEGIN
    -- Créer le tournoi
    INSERT INTO app.tournaments (
        name, description, game_type, tournament_type, format,
        max_participants, min_participants, registration_start, registration_end,
        start_date, end_date, prize_pool, entry_fee, is_featured, is_private,
        elo_min, elo_max, auto_start, settings, created_by
    ) VALUES (
        p_name, p_description, p_game_type, p_tournament_type, p_format,
        p_max_participants, p_min_participants, p_registration_start, p_registration_end,
        p_start_date, p_end_date, p_prize_pool, p_entry_fee, p_is_featured, p_is_private,
        p_elo_min, p_elo_max, p_auto_start, p_settings, auth.uid()
    ) RETURNING id INTO new_tournament_id;
    
    RETURN QUERY SELECT true, new_tournament_id, 'Tournament created successfully';
END;
$$ LANGUAGE plpgsql;

-- 2. RPC: S'inscrire à un tournoi
CREATE OR REPLACE FUNCTION app.tournament_register(
    p_tournament_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    tournament_info RECORD;
    user_elo INTEGER;
    existing_registration RECORD;
BEGIN
    -- Vérifier le tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = p_tournament_id AND status = 'registration';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Tournament not found or not in registration phase';
    END IF;
    
    -- Vérifier si le tournoi est plein
    IF tournament_info.current_participants >= tournament_info.max_participants THEN
        RETURN QUERY SELECT false, 'Tournament is full';
    END IF;
    
    -- Vérifier les contraintes ELO
    SELECT COALESCE(elo_rating, 1000) INTO user_elo
    FROM app.game_multiplayer_leaderboards 
    WHERE user_id = auth.uid() AND game_type = tournament_info.game_type;
    
    IF user_elo < tournament_info.elo_min OR user_elo > tournament_info.elo_max THEN
        RETURN QUERY SELECT false, 'ELO rating not in allowed range';
    END IF;
    
    -- Vérifier si déjà inscrit
    SELECT * INTO existing_registration
    FROM app.tournament_participants 
    WHERE tournament_id = p_tournament_id AND user_id = auth.uid();
    
    IF FOUND THEN
        RETURN QUERY SELECT false, 'Already registered for this tournament';
    END IF;
    
    -- S'inscrire
    INSERT INTO app.tournament_participants (
        tournament_id, user_id, elo_rating_before
    ) VALUES (
        p_tournament_id, auth.uid(), user_elo
    );
    
    RETURN QUERY SELECT true, 'Successfully registered for tournament';
END;
$$ LANGUAGE plpgsql;

-- 3. RPC: Démarrer un tournoi
CREATE OR REPLACE FUNCTION app.tournament_start(
    p_tournament_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    tournament_info RECORD;
    participant_count INTEGER;
    bracket_data JSONB;
BEGIN
    -- Vérifier le tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = p_tournament_id AND status = 'registration'
      AND created_by = auth.uid();
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Tournament not found or not in registration phase';
    END IF;
    
    -- Vérifier le nombre minimum de participants
    SELECT COUNT(*) INTO participant_count
    FROM app.tournament_participants 
    WHERE tournament_id = p_tournament_id AND status = 'registered';
    
    IF participant_count < tournament_info.min_participants THEN
        RETURN QUERY SELECT false, 'Not enough participants to start tournament';
    END IF;
    
    -- Mettre à jour le statut
    UPDATE app.tournaments 
    SET status = 'active', start_date = NOW()
    WHERE id = p_tournament_id;
    
    -- Mettre à jour le statut des participants
    UPDATE app.tournament_participants 
    SET status = 'active'
    WHERE tournament_id = p_tournament_id AND status = 'registered';
    
    -- Générer le bracket
    SELECT * INTO bracket_data FROM app.generate_tournament_bracket(p_tournament_id, participant_count);
    
    -- Créer les matchs du premier round
    INSERT INTO app.tournament_matches (
        tournament_id, round_number, match_number, participant1_id, participant2_id,
        status, scheduled_at
    )
    SELECT 
        p_tournament_id, 
        1, 
        ROW_NUMBER() OVER (ORDER BY seed_number),
        p1.id,
        p2.id,
        'scheduled',
        NOW()
    FROM (
        SELECT 
            tp.id,
            tp.seed_number,
            ROW_NUMBER() OVER (ORDER BY tp.seed_number) as rn
        FROM app.tournament_participants tp
        WHERE tp.tournament_id = p_tournament_id AND tp.status = 'active'
        ORDER BY tp.seed_number
    ) p1
    JOIN (
        SELECT 
            tp.id,
            tp.seed_number,
            ROW_NUMBER() OVER (ORDER BY tp.seed_number) as rn
        FROM app.tournament_participants tp
        WHERE tp.tournament_id = p_tournament_id AND tp.status = 'active'
        ORDER BY tp.seed_number
    ) p2 ON p1.rn = p2.rn + 1 AND p1.rn % 2 = 0
    WHERE p1.rn < participant_count / 2;
    
    RETURN QUERY SELECT true, 'Tournament started successfully';
END;
$$ LANGUAGE plpgsql;

-- 4. RPC: Créer une ligue
CREATE OR REPLACE FUNCTION app.league_create(
    p_name VARCHAR(100),
    p_description TEXT,
    p_game_type VARCHAR(50),
    p_league_type VARCHAR(20) DEFAULT 'seasonal',
    p_division VARCHAR(20) DEFAULT 'main',
    p_season_number INTEGER DEFAULT 1,
    p_season_start TIMESTAMPTZ DEFAULT NOW(),
    p_season_end TIMESTAMPTZ DEFAULT NOW() + INTERVAL '3 months',
    p_max_players INTEGER DEFAULT 1000,
    p_min_elo INTEGER DEFAULT 0,
    p_max_elo INTEGER DEFAULT 3000,
    p_promotion_division VARCHAR(20),
    p_relegation_division VARCHAR(20),
    p_promotion_count INTEGER DEFAULT 2,
    p_relegation_count INTEGER DEFAULT 2,
    p_settings JSONB DEFAULT '{}'
)
RETURNS TABLE (
    success BOOLEAN,
    league_id UUID,
    message TEXT
) AS $$
DECLARE
    new_league_id UUID;
BEGIN
    -- Créer la ligue
    INSERT INTO app.leagues (
        name, description, game_type, league_type, division, season_number,
        season_start, season_end, max_players, min_elo, max_elo,
        promotion_division, relegation_division, promotion_count, relegation_count,
        settings, created_by
    ) VALUES (
        p_name, p_description, p_game_type, p_league_type, p_division, p_season_number,
        p_season_start, p_season_end, p_max_players, p_min_elo, p_max_elo,
        p_promotion_division, p_relegation_division, p_promotion_count, p_relegation_count,
        p_settings, auth.uid()
    ) RETURNING id INTO new_league_id;
    
    RETURN QUERY SELECT true, new_league_id, 'League created successfully';
END;
$$ LANGUAGE plpgsql;

-- 5. RPC: Rejoindre une ligue
CREATE OR REPLACE FUNCTION app.league_join(
    p_league_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    league_info RECORD;
    user_elo INTEGER;
    existing_participation RECORD;
BEGIN
    -- Vérifier la ligue
    SELECT * INTO league_info
    FROM app.leagues 
    WHERE id = p_league_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'League not found or not active';
    END IF;
    
    -- Vérifier si la ligue est pleine
    IF league_info.current_players >= league_info.max_players THEN
        RETURN QUERY SELECT false, 'League is full';
    END IF;
    
    -- Vérifier les contraintes ELO
    SELECT COALESCE(elo_rating, 1000) INTO user_elo
    FROM app.game_multiplayer_leaderboards 
    WHERE user_id = auth.uid() AND game_type = league_info.game_type;
    
    IF user_elo < league_info.min_elo OR user_elo > league_info.max_elo THEN
        RETURN QUERY SELECT false, 'ELO rating not in allowed range';
    END IF;
    
    -- Vérifier si déjà participant
    SELECT * INTO existing_participation
    FROM app.league_participations 
    WHERE league_id = p_league_id AND user_id = auth.uid();
    
    IF FOUND THEN
        RETURN QUERY SELECT false, 'Already participating in this league';
    END IF;
    
    -- Rejoindre la ligue
    INSERT INTO app.league_participations (
        league_id, user_id, division, elo_rating, elo_rating_start
    ) VALUES (
        p_league_id, auth.uid(), league_info.division, user_elo, user_elo
    );
    
    -- Mettre à jour le classement
    UPDATE app.league_participations 
    SET rank_position = (
        SELECT COUNT(*) + 1 
        FROM app.league_participations lp2 
        WHERE lp2.league_id = p_league_id 
          AND lp2.division = league_info.division
          AND lp2.points > (SELECT points FROM app.league_participations WHERE user_id = auth.uid() AND league_id = p_league_id)
    )
    WHERE league_id = p_league_id AND user_id = auth.uid();
    
    RETURN QUERY SELECT true, 'Successfully joined league';
END;
$$ LANGUAGE plpgsql;

-- 6. RPC: Lister les tournois disponibles
CREATE OR REPLACE FUNCTION app.tournament_list_available(
    p_game_type VARCHAR(50) DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    tournament_id UUID,
    name VARCHAR(100),
    description TEXT,
    game_type VARCHAR(50),
    tournament_type VARCHAR(20),
    format VARCHAR(20),
    max_participants INTEGER,
    current_participants INTEGER,
    status VARCHAR(20),
    registration_end TIMESTAMPTZ,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    prize_pool INTEGER,
    entry_fee INTEGER,
    is_featured BOOLEAN,
    is_private BOOLEAN,
    elo_min INTEGER,
    elo_max INTEGER,
    created_by VARCHAR(255),
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.description,
        t.game_type,
        t.tournament_type,
        t.format,
        t.max_participants,
        t.current_participants,
        t.status,
        t.registration_end,
        t.start_date,
        t.end_date,
        t.prize_pool,
        t.entry_fee,
        t.is_featured,
        t.is_private,
        t.elo_min,
        t.elo_max,
        COALESCE(students.full_name, 'Anonymous') as created_by,
        t.created_at
    FROM app.tournaments t
    LEFT JOIN auth.users u ON t.created_by = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE t.status IN ('registration', 'active')
      AND (p_game_type IS NULL OR t.game_type = p_game_type)
      AND (t.is_private = false OR t.created_by = auth.uid())
      AND t.current_participants < t.max_participants
      AND t.registration_end > NOW()
    ORDER BY t.is_featured DESC, t.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 7. RPC: Lister les ligues disponibles
CREATE OR REPLACE FUNCTION app.league_list_available(
    p_game_type VARCHAR(50) DEFAULT NULL,
    p_division VARCHAR(20) DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    league_id UUID,
    name VARCHAR(100),
    description TEXT,
    game_type VARCHAR(50),
    league_type VARCHAR(20),
    division VARCHAR(20),
    season_number INTEGER,
    current_players INTEGER,
    max_players INTEGER,
    min_elo INTEGER,
    max_elo INTEGER,
    is_active BOOLEAN,
    season_start TIMESTAMPTZ,
    season_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.name,
        l.description,
        l.game_type,
        l.league_type,
        l.division,
        l.season_number,
        l.current_players,
        l.max_players,
        l.min_elo,
        l.max_elo,
        l.is_active,
        l.season_start,
        l.season_end,
        l.created_at
    FROM app.leagues l
    WHERE l.is_active = true
      AND (p_game_type IS NULL OR l.game_type = p_game_type)
      AND (p_division IS NULL OR l.division = p_division)
      AND l.current_players < l.max_players
    ORDER BY l.division, l.season_number DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 8. RPC: Obtenir les détails d'un tournoi
CREATE OR REPLACE FUNCTION app.tournament_get_details(
    p_tournament_id UUID
)
RETURNS TABLE (
    tournament_id UUID,
    name VARCHAR(100),
    description TEXT,
    game_type VARCHAR(50),
    tournament_type VARCHAR(20),
    format VARCHAR(20),
    max_participants INTEGER,
    min_participants INTEGER,
    current_participants INTEGER,
    status VARCHAR(20),
    registration_start TIMESTAMPTZ,
    registration_end TIMESTAMPTZ,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    prize_pool INTEGER,
    entry_fee INTEGER,
    created_by VARCHAR(255),
    created_at TIMESTAMPTZ,
    settings JSONB,
    participant_count INTEGER,
    current_round INTEGER,
    total_matches INTEGER,
    completed_matches INTEGER
) AS $$
DECLARE
    tournament_info RECORD;
BEGIN
    -- Obtenir les informations du tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = p_tournament_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::UUID, NULL::VARCHAR, NULL::TEXT, NULL::VARCHAR, NULL::VARCHAR, 
                         NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR,
                         NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ,
                         NULL::INTEGER, NULL::INTEGER, NULL::BOOLEAN, NULL::INTEGER, NULL::INTEGER,
                         NULL::VARCHAR, NULL::TIMESTAMPTZ, NULL::JSONB, NULL::INTEGER, NULL::INTEGER,
                         NULL::INTEGER, NULL::INTEGER;
    END IF;
    
    -- Calculer les statistiques
    RETURN QUERY
    SELECT 
        tournament_info.id,
        tournament_info.name,
        tournament_info.description,
        tournament_info.game_type,
        tournament_info.tournament_type,
        tournament_info.format,
        tournament_info.max_participants,
        tournament_info.min_participants,
        tournament_info.current_participants,
        tournament_info.status,
        tournament_info.registration_start,
        tournament_info.registration_end,
        tournament_info.start_date,
        tournament_info.end_date,
        tournament_info.prize_pool,
        tournament_info.entry_fee,
        COALESCE(students.full_name, 'Anonymous') as created_by,
        tournament_info.created_at,
        tournament_info.settings,
        (SELECT COUNT(*) FROM app.tournament_participants WHERE tournament_id = p_tournament_id) as participant_count,
        (SELECT COALESCE(MAX(round_number), 0) FROM app.tournament_matches WHERE tournament_id = p_tournament_id) as current_round,
        (SELECT COUNT(*) FROM app.tournament_matches WHERE tournament_id = p_tournament_id) as total_matches,
        (SELECT COUNT(*) FROM app.tournament_matches WHERE tournament_id = p_tournament_id AND status = 'completed') as completed_matches
    FROM app.tournaments tournament_info
    LEFT JOIN auth.users u ON tournament_info.created_by = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE tournament_info.id = p_tournament_id;
END;
$$ LANGUAGE plpgsql;

-- 9. RPC: Obtenir les classements d'un tournoi
CREATE OR REPLACE FUNCTION app.tournament_get_standings(
    p_tournament_id UUID
)
RETURNS TABLE (
    rank_position INTEGER,
    participant_id UUID,
    participant_name VARCHAR(255),
    status VARCHAR(20),
    current_round INTEGER,
    matches_played INTEGER,
    matches_won INTEGER,
    matches_lost INTEGER,
    matches_drawn INTEGER,
    points INTEGER,
    elo_rating_before INTEGER,
    elo_rating_after INTEGER,
    prize_won INTEGER,
    eliminated_by VARCHAR(255),
    eliminated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY points DESC, matches_won DESC, matches_lost ASC, elo_rating_after DESC NULLS LAST) as rank_position,
        tp.user_id as participant_id,
        COALESCECE(students.full_name, 'Player ' || SUBSTRING(tp.user_id::text, 1, 8)) as participant_name,
        tp.status,
        tp.current_round,
        tp.matches_played,
        tp.matches_won,
        tp.matches_lost,
        tp.matches_drawn,
        tp.points,
        tp.elo_rating_before,
        tp.elo_rating_after,
        tp.prize_won,
        COALESCECE(eliminated_by.full_name, 'Unknown') as eliminated_by,
        tp.eliminated_at
    FROM app.tournament_participants tp
    LEFT JOIN auth.users u ON tp.user_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    LEFT JOIN auth.users eliminated_by_user ON tp.eliminated_by = eliminated_by_user.id
    LEFT JOIN app.students eliminated_by ON eliminated_by_user.id = eliminated_by.id
    WHERE tp.tournament_id = p_tournament_id
      AND tp.status IN ('active', 'eliminated', 'winner', 'withdrawn')
    ORDER BY points DESC, matches_won DESC, matches_lost ASC, elo_rating_after DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- 10. RPC: Obtenir les classements d'une ligue
CREATE OR REPLACE FUNCTION app.league_get_standings(
    p_league_id UUID,
    p_division VARCHAR(20) DEFAULT NULL
)
RETURNS TABLE (
    rank_position INTEGER,
    participant_id UUID,
    participant_name VARCHAR(255),
    division VARCHAR(20),
    points INTEGER,
    matches_played INTEGER,
    matches_won INTEGER,
    matches_lost INTEGER,
    matches_drawn INTEGER,
    win_rate DECIMAL(5,2),
    elo_rating INTEGER,
    elo_change INTEGER,
    current_streak INTEGER,
    best_streak INTEGER,
    season_points INTEGER,
    status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY season_points DESC, points DESC, win_rate DESC, elo_rating DESC) as rank_position,
        lp.user_id as participant_id,
        COALESCECE(students.full_name, 'Player ' || SUBSTRING(lp.user_id::text, 1, 8)) as participant_name,
        lp.division,
        lp.points,
        lp.matches_played,
        lp.matches_won,
        lp.matches_lost,
        lp.matches_drawn,
        lp.win_rate,
        lp.elo_rating,
        lp.elo_change,
        lp.current_streak,
        lp.best_streak,
        lp.season_points,
        lp.status
    FROM app.league_participations lp
    LEFT JOIN auth.users u ON lp.user_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE lp.league_id = p_league_id
      AND (p_division IS NULL OR lp.division = p_division)
      AND lp.status IN ('active', 'promoted', 'relegated')
    ORDER BY season_points DESC, points DESC, win_rate DESC, elo_rating DESC;
END;
$$ LANGUAGE plpgsql;

-- 11. RPC: Enregistrer le résultat d'un match de tournoi
CREATE OR REPLACE FUNCTION app.tournament_report_match_result(
    p_match_id UUID,
    p_winner_id UUID,
    p_participant1_score INTEGER DEFAULT 0,
    p_participant2_score INTEGER DEFAULT 0,
    p_participant3_score INTEGER DEFAULT 0,
    p_participant4_score INTEGER DEFAULT 0,
    p_participant1_points INTEGER DEFAULT 0,
    p_participant2_points INTEGER DEFAULT 0,
    p_participant3_points INTEGER DEFAULT 0,
    p_participant4_points INTEGER DEFAULT 0,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    match_info RECORD;
    tournament_info RECORD;
    elo_change_p1 INTEGER;
    elo_change_p2 INTEGER;
    elo_change_p3 INTEGER;
    elo_change_p4 INTEGER;
BEGIN
    -- Vérifier le match
    SELECT * INTO match_info
    FROM app.tournament_matches 
    WHERE id = p_match_id AND status = 'in_progress';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Match not found or not in progress';
    END IF;
    
    -- Obtenir les informations du tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = match_info.tournament_id;
    
    -- Calculer les changements ELO (simplifié)
    elo_change_p1 := CASE 
        WHEN p_participant1_id = p_winner_id THEN 25
        WHEN p_participant2_id = p_winner_id THEN -25
        ELSE -10
    END;
    
    elo_change_p2 := CASE 
        WHEN p_participant2_id = p_winner_id THEN 25
        WHEN p_participant1_id = p_winner_id THEN -25
        ELSE -10
    END;
    
    elo_change_p3 := CASE 
        WHEN p_participant3_id = p_winner_id THEN 25
        ELSE -10
    END;
    
    elo_change_p4 := CASE 
        WHEN p_participant4_id = p_winner_id THEN 25
        ELSE -10
    END;
    
    -- Mettre à jour le match
    UPDATE app.tournament_matches 
    SET 
        winner_id = p_winner_id,
        status = 'completed',
        completed_at = NOW(),
        participant1_score = p_participant1_score,
        participant2_score = p_participant2_score,
        participant3_score = p_participant3_score,
        participant4_score = p_participant4_score,
        participant1_points = p_participant1_points,
        participant2_points = p_participant2_points,
        participant3_points = p_participant3_points,
        participant4_points = p_participant4_points,
        notes = p_notes
    WHERE id = p_match_id;
    
    -- Mettre à jour les participants
    UPDATE app.tournament_participants 
    SET 
        matches_played = matches_played + 1,
        matches_won = CASE 
            WHEN user_id = p_participant1_id AND p_participant1_id = p_winner_id THEN matches_won + 1
            WHEN user_id = p_participant2_id AND p_participant2_id = p_winner_id THEN matches_won + 1
            WHEN user_id = p_participant3_id AND p_participant3_id = p_winner_id THEN matches_won + 1
            WHEN user_id = p_participant4_id AND p_participant4_id = p_winner_id THEN matches_won + 1
            ELSE matches_won
        END,
        matches_lost = CASE 
            WHEN user_id = p_participant1_id AND p_participant1_id != p_winner_id THEN matches_lost + 1
            WHEN user_id = p_participant2_id AND p_participant2_id != p_winner_id THEN matches_lost + 1
            WHEN user_id = p_participant3_id AND p_participant3_id != p_winner_id THEN matches_lost + 1
            WHEN user_id = p_participant4_id AND p_participant4_id != p_winner_id THEN matches_lost + 1
            ELSE matches_lost
        END,
        points = points + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_points
            WHEN user_id = p_participant2_id THEN p_participant2_points
            WHEN user_id = p_participant3_id THEN p_participant3_points
            WHEN user_id = p_participant4_id THEN p_participant4_points
            ELSE 0
        END,
        elo_rating_after = elo_rating_before + CASE
            WHEN user_id = p_participant1_id THEN elo_change_p1
            WHEN user_id = p_participant2_id THEN elo_change_p2
            WHEN user_id = p_participant3_id THEN elo_change_p3
            WHEN user_id = p_participant4_id THEN elo_change_p4
            ELSE 0
        END
    WHERE tournament_id = match_info.tournament_id
      AND user_id IN (p_participant1_id, p_participant2_id, p_participant3_id, p_participant4_id);
    
    -- Vérifier si le tournoi est terminé
    IF (SELECT COUNT(*) FROM app.tournament_matches 
        WHERE tournament_id = match_info.tournament_id AND status = 'completed') = 
        (SELECT COUNT(*) FROM app.tournament_matches WHERE tournament_id = match_info.tournament_id)) THEN
        UPDATE app.tournaments 
        SET status = 'completed', completed_at = NOW()
        WHERE id = match_info.tournament_id;
    END IF;
    
    RETURN QUERY SELECT true, 'Match result recorded successfully';
END;
$$ LANGUAGE plpgsql;

-- 12. RPC: Enregistrer le résultat d'un match de ligue
CREATE OR REPLACE FUNCTION app.league_report_match_result(
    p_match_id UUID,
    p_winner_id UUID,
    p_participant1_score INTEGER DEFAULT 0,
    p_participant2_score INTEGER DEFAULT 0,
    p_participant1_points INTEGER DEFAULT 0,
    p_participant2_points INTEGER DEFAULT 0,
    p_participant1_elo_change INTEGER DEFAULT 0,
    p_participant2_elo_change INTEGER DEFAULT 0,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    match_info RECORD;
    league_info RECORD;
BEGIN
    -- Vérifier le match
    SELECT * INTO match_info
    FROM app.league_matches 
    WHERE id = p_match_id AND status = 'in_progress';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Match not found or not in progress';
    END IF;
    
    -- Obtenir les informations de la ligue
    SELECT * INTO league_info
    FROM app.leagues 
    WHERE id = match_info.league_id;
    
    -- Mettre à jour le match
    UPDATE app.league_matches 
    SET 
        winner_id = p_winner_id,
        status = 'completed',
        completed_at = NOW(),
        participant1_score = p_participant1_score,
        participant2_score = p_participant2_score,
        participant1_points = p_participant1_points,
        participant2_points = p_participant2_points,
        participant1_elo_change = p_participant1_elo_change,
        participant2_elo_change = p_participant2_elo_change,
        notes = p_notes
    WHERE id = p_match_id;
    
    -- Mettre à jour les participants
    UPDATE app.league_participations 
    SET 
        matches_played = matches_played + 1,
        matches_won = CASE 
            WHEN user_id = p_participant1_id AND p_participant1_id = p_winner_id THEN matches_won + 1
            WHEN user_id = p_participant2_id AND p_participant2_id = p_winner_id THEN matches_won + 1
            ELSE matches_won
        END,
        matches_lost = CASE 
            WHEN user_id = p_participant1_id AND p_participant1_id != p_winner_id THEN matches_lost + 1
            WHEN user_id = p_participant2_id AND p_participant2_id != p_winner_id THEN matches_lost + 1
            ELSE matches_lost
        END,
        points = points + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_points
            WHEN user_id = p_participant2_id THEN p_participant2_points
            ELSE 0
        END,
        elo_rating = elo_rating + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_elo_change
            WHEN user_id = p_participant2_id THEN p_participant2_elo_change
            ELSE 0
        END,
        elo_change = elo_change + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_elo_change
            WHEN user_id = p_participant2_id THEN p_participant2_elo_change
            ELSE 0
        END,
        last_match_at = NOW()
    WHERE league_id = match_info.league_id
      AND user_id IN (p_participant1_id, p_participant2_id);
    
    -- Mettre à jour les classements
    UPDATE app.league_participations 
    SET rank_position = (
        SELECT COUNT(*) + 1 
        FROM app.league_participations lp2 
        WHERE lp2.league_id = match_info.league_id 
          AND lp2.division = (
              SELECT division FROM app.leagues WHERE id = match_info.league_id
          )
          AND lp2.points > (SELECT points FROM app.league_participations WHERE user_id = auth.uid() AND league_id = match_info.league_id)
    )
    WHERE league_id = match_info.league_id
      AND user_id IN (p_participant1_id, p_participant2_id);
    
    RETURN QUERY SELECT true, 'League match result recorded successfully';
END;
$$ LANGUAGE plpgsql;
