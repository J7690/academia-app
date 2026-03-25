-- =====================================================
-- KELLENGE MULTIPLAYER RPCs - PHASE 4
-- Procédures stockées pour le multiplayer
-- =====================================================

-- 1. RPC: Créer une session multiplayer
CREATE OR REPLACE FUNCTION app.game_create_multiplayer_session(
    p_game_type VARCHAR(50),
    p_game_mode VARCHAR(20) DEFAULT 'battle',
    p_max_players INTEGER DEFAULT 2,
    p_is_private BOOLEAN DEFAULT FALSE,
    p_elo_min INTEGER DEFAULT 0,
    p_elo_max INTEGER DEFAULT 3000,
    p_game_config JSONB DEFAULT '{}'
)
RETURNS TABLE (
    success BOOLEAN,
    session_id UUID,
    room_code VARCHAR(8),
    message TEXT
) AS $$
DECLARE
    new_session_id UUID;
    new_room_code VARCHAR(8);
BEGIN
    -- Vérifier si l'utilisateur a déjà une session active
    IF EXISTS (
        SELECT 1 FROM app.game_multiplayer_sessions 
        WHERE host_id = auth.uid() AND status IN ('waiting', 'active')
    ) THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::VARCHAR, 
            'You already have an active session';
        RETURN;
    END IF;
    
    -- Créer la nouvelle session
    INSERT INTO app.game_multiplayer_sessions (
        game_type, game_mode, max_players, is_private, 
        elo_min, elo_max, game_config, host_id
    ) VALUES (
        p_game_type, p_game_mode, p_max_players, p_is_private,
        p_elo_min, p_elo_max, p_game_config, auth.uid()
    ) RETURNING id, room_code INTO new_session_id, new_room_code;
    
    -- Ajouter l'hôte comme participant
    INSERT INTO app.game_multiplayer_participants (
        session_id, user_id, status, elo_rating_before
    ) VALUES (
        new_session_id, auth.uid(), 'joined', 
        COALESCE((
            SELECT elo_rating FROM app.game_multiplayer_leaderboards 
            WHERE user_id = auth.uid() AND game_type = p_game_type
        ), 1000)
    );
    
    RETURN QUERY SELECT true, new_session_id, new_room_code, 
        'Session created successfully';
END;
$$ LANGUAGE plpgsql;

-- 2. RPC: Rejoindre une session par code
CREATE OR REPLACE FUNCTION app.game_join_session_by_code(
    p_room_code VARCHAR(8)
)
RETURNS TABLE (
    success BOOLEAN,
    session_id UUID,
    message TEXT
) AS $$
DECLARE
    session_record RECORD;
    user_elo INTEGER;
BEGIN
    -- Trouver la session
    SELECT * INTO session_record
    FROM app.game_multiplayer_sessions 
    WHERE room_code = p_room_code AND status = 'waiting';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, 'Session not found or not available';
        RETURN;
    END IF;
    
    -- Vérifier si la session est pleine
    IF session_record.current_players >= session_record.max_players THEN
        RETURN QUERY SELECT false, NULL::UUID, 'Session is full';
        RETURN;
    END IF;
    
    -- Vérifier les contraintes ELO
    SELECT COALESCE(elo_rating, 1000) INTO user_elo
    FROM app.game_multiplayer_leaderboards 
    WHERE user_id = auth.uid() AND game_type = session_record.game_type;
    
    IF user_elo < session_record.elo_min OR user_elo > session_record.elo_max THEN
        RETURN QUERY SELECT false, NULL::UUID, 'ELO rating not in allowed range';
        RETURN;
    END IF;
    
    -- Vérifier si l'utilisateur est déjà dans la session
    IF EXISTS (
        SELECT 1 FROM app.game_multiplayer_participants 
        WHERE session_id = session_record.id AND user_id = auth.uid()
    ) THEN
        RETURN QUERY SELECT false, session_record.id, 'Already in session';
        RETURN;
    END IF;
    
    -- Ajouter le participant
    INSERT INTO app.game_multiplayer_participants (
        session_id, user_id, status, elo_rating_before
    ) VALUES (
        session_record.id, auth.uid(), 'joined', user_elo
    );
    
    RETURN QUERY SELECT true, session_record.id, 'Joined session successfully';
END;
$$ LANGUAGE plpgsql;

-- 3. RPC: Lancer le matchmaking
CREATE OR REPLACE FUNCTION app.game_start_matchmaking(
    p_game_type VARCHAR(50),
    p_elo_range INTEGER DEFAULT 200 -- ELO range pour le matching
)
RETURNS TABLE (
    success BOOLEAN,
    session_id UUID,
    message TEXT
) AS $$
DECLARE
    user_elo INTEGER;
    opponent_record RECORD;
    new_session_id UUID;
BEGIN
    -- Obtenir l'ELO de l'utilisateur
    SELECT COALESCE(elo_rating, 1000) INTO user_elo
    FROM app.game_multiplayer_leaderboards 
    WHERE user_id = auth.uid() AND game_type = p_game_type;
    
    -- Vérifier si l'utilisateur n'est pas déjà en attente
    IF EXISTS (
        SELECT 1 FROM app.game_multiplayer_participants p
        JOIN app.game_multiplayer_sessions s ON p.session_id = s.id
        WHERE p.user_id = auth.uid() AND s.status = 'waiting'
    ) THEN
        RETURN QUERY SELECT false, NULL::UUID, 'Already in matchmaking';
        RETURN;
    END IF;
    
    -- Chercher un adversaire disponible
    SELECT p.*, s.* INTO opponent_record
    FROM app.game_multiplayer_participants p
    JOIN app.game_multiplayer_sessions s ON p.session_id = s.id
    JOIN app.game_multiplayer_leaderboards l ON p.user_id = l.user_id AND l.game_type = p_game_type
    WHERE s.status = 'waiting' 
      AND s.game_type = p_game_type
      AND p.user_id != auth.uid()
      AND ABS(l.elo_rating - user_elo) <= p_elo_range
      AND s.current_players < s.max_players
    ORDER BY ABS(l.elo_rating - user_elo), s.created_at
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Créer une nouvelle session d'attente
        INSERT INTO app.game_multiplayer_sessions (
            game_type, game_mode, max_players, host_id
        ) VALUES (
            p_game_type, 'battle', 2, auth.uid()
        ) RETURNING id INTO new_session_id;
        
        -- Ajouter l'utilisateur comme participant
        INSERT INTO app.game_multiplayer_participants (
            session_id, user_id, status, elo_rating_before
        ) VALUES (
            new_session_id, auth.uid(), 'joined', user_elo
        );
        
        RETURN QUERY SELECT true, new_session_id, 'Added to matchmaking queue';
    ELSE
        -- Rejoindre la session existante
        INSERT INTO app.game_multiplayer_participants (
            session_id, user_id, status, elo_rating_before
        ) VALUES (
            opponent_record.session_id, auth.uid(), 'joined', user_elo
        );
        
        RETURN QUERY SELECT true, opponent_record.session_id, 'Match found!';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 4. RPC: Démarrer une session
CREATE OR REPLACE FUNCTION app.game_start_session(
    p_session_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    session_record RECORD;
    participant_count INTEGER;
BEGIN
    -- Vérifier la session
    SELECT * INTO session_record
    FROM app.game_multiplayer_sessions 
    WHERE id = p_session_id AND host_id = auth.uid();
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Session not found or not host';
        RETURN;
    END IF;
    
    IF session_record.status != 'waiting' THEN
        RETURN QUERY SELECT false, 'Session already started or completed';
        RETURN;
    END IF;
    
    -- Vérifier le nombre de participants
    SELECT COUNT(*) INTO participant_count
    FROM app.game_multiplayer_participants 
    WHERE session_id = p_session_id AND status = 'joined';
    
    IF participant_count < 2 THEN
        RETURN QUERY SELECT false, 'Not enough participants to start';
        RETURN;
    END IF;
    
    -- Démarrer la session
    UPDATE app.game_multiplayer_sessions 
    SET status = 'active', started_at = NOW()
    WHERE id = p_session_id;
    
    -- Mettre à jour le statut des participants
    UPDATE app.game_multiplayer_participants 
    SET status = 'playing'
    WHERE session_id = p_session_id AND status = 'joined';
    
    -- Créer les matchs pour le battle
    IF session_record.game_mode = 'battle' THEN
        INSERT INTO app.game_multiplayer_matches (
            session_id, player1_id, player2_id, player1_elo, player2_elo
        )
        SELECT 
            p_session_id,
            p1.user_id,
            p2.user_id,
            p1.elo_rating_before,
            p2.elo_rating_before
        FROM app.game_multiplayer_participants p1
        CROSS JOIN app.game_multiplayer_participants p2
        WHERE p1.session_id = p_session_id 
          AND p2.session_id = p_session_id
          AND p1.user_id < p2.user_id;
    END IF;
    
    RETURN QUERY SELECT true, 'Session started successfully';
END;
$$ LANGUAGE plpgsql;

-- 5. RPC: Terminer une session et mettre à jour les ELO
CREATE OR REPLACE FUNCTION app.game_end_session(
    p_session_id UUID,
    p_final_scores JSONB -- Format: {"user_id": score, ...}
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    session_record RECORD;
    participant RECORD;
    winner_id UUID;
    loser_id UUID;
    elo_change_winner INTEGER;
    elo_change_loser INTEGER;
    winner_elo_before INTEGER;
    loser_elo_before INTEGER;
BEGIN
    -- Vérifier la session
    SELECT * INTO session_record
    FROM app.game_multiplayer_sessions 
    WHERE id = p_session_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Session not found or not active';
        RETURN;
    END IF;
    
    -- Pour un mode battle simple (2 joueurs)
    IF session_record.game_mode = 'battle' THEN
        -- Déterminer le gagnant
        SELECT 
            user_id, 
            (p_final_scores->>user_id::text)::INTEGER as score
        INTO winner_id, participant.score
        FROM app.game_multiplayer_participants 
        WHERE session_id = p_session_id 
          AND user_id = (SELECT user_id FROM jsonb_object_keys(p_final_scores) 
                        ORDER BY (p_final_scores->>user_id::text)::INTEGER DESC LIMIT 1);
        
        -- Trouver le perdant
        SELECT user_id INTO loser_id
        FROM app.game_multiplayer_participants 
        WHERE session_id = p_session_id AND user_id != winner_id;
        
        -- Obtenir les ELO avant
        SELECT elo_rating_before INTO winner_elo_before
        FROM app.game_multiplayer_participants 
        WHERE session_id = p_session_id AND user_id = winner_id;
        
        SELECT elo_rating_before INTO loser_elo_before
        FROM app.game_multiplayer_participants 
        WHERE session_id = p_session_id AND user_id = loser_id;
        
        -- Calculer les changements ELO
        elo_change_winner := app.calculate_elo_change(winner_elo_before, loser_elo_before, 'win');
        elo_change_loser := app.calculate_elo_change(loser_elo_before, winner_elo_before, 'loss');
        
        -- Mettre à jour le match
        UPDATE app.game_multiplayer_matches 
        SET winner_id = winner_id,
            match_result = 'player1_win',
            rating_change_player1 = CASE WHEN player1_id = winner_id THEN elo_change_winner ELSE elo_change_loser END,
            rating_change_player2 = CASE WHEN player2_id = winner_id THEN elo_change_winner ELSE elo_change_loser END,
            completed_at = NOW()
        WHERE session_id = p_session_id;
        
        -- Mettre à jour les classements
        UPDATE app.game_multiplayer_leaderboards 
        SET 
            elo_rating = elo_rating + elo_change_winner,
            matches_played = matches_played + 1,
            matches_won = matches_won + 1,
            current_streak = CASE WHEN current_streak > 0 THEN current_streak + 1 ELSE 1 END,
            best_streak = GREATEST(best_streak, CASE WHEN current_streak > 0 THEN current_streak + 1 ELSE 1 END),
            total_score = total_score + participant.score,
            last_updated = NOW()
        WHERE user_id = winner_id AND game_type = session_record.game_type;
        
        UPDATE app.game_multiplayer_leaderboards 
        SET 
            elo_rating = elo_rating + elo_change_loser,
            matches_played = matches_played + 1,
            matches_lost = matches_lost + 1,
            current_streak = CASE WHEN current_streak < 0 THEN current_streak - 1 ELSE -1 END,
            total_score = total_score + (p_final_scores->>loser_id::text)::INTEGER,
            last_updated = NOW()
        WHERE user_id = loser_id AND game_type = session_record.game_type;
        
        -- Mettre à jour les participants
        UPDATE app.game_multiplayer_participants 
        SET 
            score = (p_final_scores->>user_id::text)::INTEGER,
            final_rank = CASE WHEN user_id = winner_id THEN 1 ELSE 2 END,
            elo_rating_after = CASE 
                WHEN user_id = winner_id THEN winner_elo_before + elo_change_winner 
                ELSE loser_elo_before + elo_change_loser 
            END
        WHERE session_id = p_session_id;
    END IF;
    
    -- Terminer la session
    UPDATE app.game_multiplayer_sessions 
    SET status = 'completed', completed_at = NOW()
    WHERE id = p_session_id;
    
    RETURN QUERY SELECT true, 'Session completed and ELO ratings updated';
END;
$$ LANGUAGE plpgsql;

-- 6. RPC: Lister les sessions publiques disponibles
CREATE OR REPLACE FUNCTION app.game_list_public_sessions(
    p_game_type VARCHAR(50) DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    session_id UUID,
    game_type VARCHAR(50),
    game_mode VARCHAR(20),
    max_players INTEGER,
    current_players INTEGER,
    status VARCHAR(20),
    room_code VARCHAR(8),
    host_name TEXT,
    elo_min INTEGER,
    elo_max INTEGER,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.game_type,
        s.game_mode,
        s.max_players,
        s.current_players,
        s.status,
        s.room_code,
        COALESCE(students.full_name, 'Anonymous') as host_name,
        s.elo_min,
        s.elo_max,
        s.created_at
    FROM app.game_multiplayer_sessions s
    LEFT JOIN auth.users u ON s.host_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE s.is_private = false 
      AND s.status = 'waiting'
      AND (p_game_type IS NULL OR s.game_type = p_game_type)
      AND s.current_players < s.max_players
      AND s.created_at > NOW() - INTERVAL '1 hour' -- Sessions créées depuis moins d'une heure
    ORDER BY s.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 7. RPC: Obtenir le classement (leaderboard)
CREATE OR REPLACE FUNCTION app.game_get_leaderboard(
    p_game_type VARCHAR(50),
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    rank_global INTEGER,
    user_name TEXT,
    elo_rating INTEGER,
    matches_played INTEGER,
    matches_won INTEGER,
    matches_lost INTEGER,
    win_rate DECIMAL(5,2),
    current_streak INTEGER,
    best_streak INTEGER,
    avg_score DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY elo_rating DESC, matches_won DESC) as rank_global,
        COALESCE(students.full_name, 'Player ' || SUBSTRING(user_id::text, 1, 8)) as user_name,
        elo_rating,
        matches_played,
        matches_won,
        matches_lost,
        win_rate,
        current_streak,
        best_streak,
        avg_score
    FROM app.game_multiplayer_leaderboards l
    LEFT JOIN auth.users u ON l.user_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE l.game_type = p_game_type
      AND l.matches_played > 0
    ORDER BY elo_rating DESC, matches_won DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 8. RPC: Envoyer une invitation
CREATE OR REPLACE FUNCTION app.game_send_invitation(
    p_recipient_id UUID,
    p_session_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    session_record RECORD;
BEGIN
    -- Vérifier que la session existe et est accessible
    SELECT * INTO session_record
    FROM app.game_multiplayer_sessions 
    WHERE id = p_session_id 
      AND (host_id = auth.uid() OR id IN (
          SELECT session_id FROM app.game_multiplayer_participants 
          WHERE user_id = auth.uid()
      ));
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Session not found or no permission';
        RETURN;
    END IF;
    
    IF session_record.status != 'waiting' THEN
        RETURN QUERY SELECT false, 'Session is not available for invitations';
        RETURN;
    END IF;
    
    IF session_record.current_players >= session_record.max_players THEN
        RETURN QUERY SELECT false, 'Session is full';
        RETURN;
    END IF;
    
    -- Vérifier si une invitation existe déjà
    IF EXISTS (
        SELECT 1 FROM app.game_multiplayer_invitations 
        WHERE sender_id = auth.uid() 
          AND recipient_id = p_recipient_id 
          AND session_id = p_session_id 
          AND status = 'pending'
    ) THEN
        RETURN QUERY SELECT false, 'Invitation already sent';
        RETURN;
    END IF;
    
    -- Créer l'invitation
    INSERT INTO app.game_multiplayer_invitations (
        sender_id, recipient_id, session_id
    ) VALUES (
        auth.uid(), p_recipient_id, p_session_id
    );
    
    RETURN QUERY SELECT true, 'Invitation sent successfully';
END;
$$ LANGUAGE plpgsql;

-- 9. RPC: Accepter une invitation
CREATE OR REPLACE FUNCTION app.game_accept_invitation(
    p_invitation_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    session_id UUID,
    message TEXT
) AS $$
DECLARE
    invitation_record RECORD;
BEGIN
    -- Trouver l'invitation
    SELECT * INTO invitation_record
    FROM app.game_multiplayer_invitations 
    WHERE id = p_invitation_id 
      AND recipient_id = auth.uid() 
      AND status = 'pending'
      AND expires_at > NOW();
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, 'Invitation not found, expired, or not for you';
        RETURN;
    END IF;
    
    -- Vérifier si la session est encore disponible
    IF EXISTS (
        SELECT 1 FROM app.game_multiplayer_sessions 
        WHERE id = invitation_record.session_id 
          AND status != 'waiting'
    ) THEN
        -- Marquer l'invitation comme expirée
        UPDATE app.game_multiplayer_invitations 
        SET status = 'expired' 
        WHERE id = p_invitation_id;
        
        RETURN QUERY SELECT false, NULL::UUID, 'Session is no longer available';
        RETURN;
    END IF;
    
    -- Rejoindre la session
    PERFORM app.game_join_session_by_code((
        SELECT room_code FROM app.game_multiplayer_sessions 
        WHERE id = invitation_record.session_id
    ));
    
    -- Marquer l'invitation comme acceptée
    UPDATE app.game_multiplayer_invitations 
    SET status = 'accepted', responded_at = NOW()
    WHERE id = p_invitation_id;
    
    RETURN QUERY SELECT true, invitation_record.session_id, 'Invitation accepted';
END;
$$ LANGUAGE plpgsql;

-- 10. RPC: Envoyer un message de chat
CREATE OR REPLACE FUNCTION app.game_send_chat_message(
    p_session_id UUID,
    p_message TEXT,
    p_message_type VARCHAR(20) DEFAULT 'text'
)
RETURNS TABLE (
    success BOOLEAN,
    message_id UUID,
    message TEXT
) AS $$
DECLARE
    message_id UUID;
BEGIN
    -- Vérifier que l'utilisateur est participant de la session
    IF NOT EXISTS (
        SELECT 1 FROM app.game_multiplayer_participants 
        WHERE session_id = p_session_id AND user_id = auth.uid()
    ) THEN
        RETURN QUERY SELECT false, NULL::UUID, 'Not a participant in this session';
        RETURN;
    END IF;
    
    -- Insérer le message
    INSERT INTO app.game_multiplayer_chat (
        session_id, sender_id, message, message_type
    ) VALUES (
        p_session_id, auth.uid(), p_message, p_message_type
    ) RETURNING id INTO message_id;
    
    RETURN QUERY SELECT true, message_id, 'Message sent successfully';
END;
$$ LANGUAGE plpgsql;

-- 11. RPC: Obtenir les messages de chat d'une session
CREATE OR REPLACE FUNCTION app.game_get_chat_messages(
    p_session_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    message_id UUID,
    sender_id UUID,
    sender_name TEXT,
    message TEXT,
    message_type VARCHAR(20),
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.sender_id,
        COALESCE(students.full_name, 'Player ' || SUBSTRING(c.sender_id::text, 1, 8)) as sender_name,
        c.message,
        c.message_type,
        c.created_at
    FROM app.game_multiplayer_chat c
    LEFT JOIN auth.users u ON c.sender_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE c.session_id = p_session_id 
      AND c.is_deleted = false
      AND EXISTS (
          SELECT 1 FROM app.game_multiplayer_participants 
          WHERE session_id = p_session_id AND user_id = auth.uid()
      )
    ORDER BY c.created_at ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 12. RPC: Mettre à jour les statistiques de matchmaking
CREATE OR REPLACE FUNCTION app.game_update_matchmaking_stats(
    p_game_type VARCHAR(50),
    p_search_initiated BOOLEAN DEFAULT false,
    p_match_found BOOLEAN DEFAULT false,
    p_wait_time_seconds INTEGER DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO app.game_matchmaking_stats (
        user_id, game_type, searches_initiated, matches_found, avg_wait_time_seconds
    ) VALUES (
        auth.uid(), p_game_type, 
        CASE WHEN p_search_initiated THEN 1 ELSE 0 END,
        CASE WHEN p_match_found THEN 1 ELSE 0 END,
        p_wait_time_seconds
    )
    ON CONFLICT (user_id, game_type, date) 
    DO UPDATE SET
        searches_initiated = game_matchmaking_stats.searches_initiated + 
            CASE WHEN p_search_initiated THEN 1 ELSE 0 END,
        matches_found = game_matchmaking_stats.matches_found + 
            CASE WHEN p_match_found THEN 1 ELSE 0 END,
        avg_wait_time_seconds = CASE 
            WHEN p_wait_time_seconds IS NOT NULL THEN 
                (game_matchmaking_stats.avg_wait_time_seconds + p_wait_time_seconds) / 2
            ELSE game_matchmaking_stats.avg_wait_time_seconds
        END;
END;
$$ LANGUAGE plpgsql;
