-- RPCs manquantes pour tournaments - Phase 6

-- RPC tournament_report_match_result manquant
CREATE OR REPLACE FUNCTION app.tournament_report_match_result(
    p_match_id UUID,
    p_winner_id UUID,
    p_player1_score INTEGER DEFAULT 0,
    p_player2_score INTEGER DEFAULT 0,
    p_match_data JSONB DEFAULT '{}'
)
RETURNS JSONB AS $$
DECLARE
    v_match_status TEXT;
BEGIN
    -- Mettre à jour le match
    UPDATE app.tournament_matches
    SET 
        winner_id = p_winner_id,
        player1_score = p_player1_score,
        player2_score = p_player2_score,
        status = 'completed',
        completed_at = NOW(),
        match_data = p_match_data
    WHERE id = p_match_id;
    
    -- Vérifier si le match existe
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'message', 'Match result reported');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC league_create manquant
CREATE OR REPLACE FUNCTION app.league_create(
    p_name VARCHAR(100),
    p_description TEXT,
    p_game_type VARCHAR(50),
    p_division VARCHAR(20) DEFAULT 'main',
    p_season_number INTEGER DEFAULT 1,
    p_start_date TIMESTAMPTZ DEFAULT NOW(),
    p_end_date TIMESTAMPTZ DEFAULT NOW() + INTERVAL '3 months'
)
RETURNS JSONB AS $$
DECLARE
    v_league_id UUID;
BEGIN
    -- Créer la ligue
    INSERT INTO app.leagues (
        name, description, game_type, division, season_number,
        start_date, end_date, status, created_by
    ) VALUES (
        p_name, p_description, p_game_type, p_division, p_season_number,
        p_start_date, p_end_date, 'active', auth.uid()
    ) RETURNING id INTO v_league_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'league_id', v_league_id,
        'message', 'League created successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
