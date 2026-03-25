-- =====================================================
-- LIVE ARENA TABLES - SEMAINE 1
-- Tables pour les sessions de quiz battle en direct avec spectateurs
-- =====================================================

-- 1. Table des sessions Live Arena
CREATE TABLE IF NOT EXISTS app.live_arena_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    fighter1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fighter2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_type VARCHAR(50) NOT NULL, -- 'market_master', 'consumer_choice', etc.
    status VARCHAR(20) NOT NULL DEFAULT 'waiting', -- 'waiting', 'active', 'completed', 'cancelled'
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    final_score JSONB DEFAULT '{}', -- Scores finaux des deux joueurs
    winner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    spectator_count INTEGER DEFAULT 0,
    max_spectators INTEGER DEFAULT 1000,
    is_private BOOLEAN DEFAULT FALSE,
    room_code VARCHAR(8) UNIQUE, -- Code d'accès pour sessions privées
    settings JSONB DEFAULT '{}', -- Configuration spécifique de la session
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table des spectateurs Live Arena
CREATE TABLE IF NOT EXISTS app.live_spectators (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    support_points INTEGER DEFAULT 0, -- Points de support pour les joueurs
    chat_messages INTEGER DEFAULT 0,
    reactions INTEGER DEFAULT 0,
    supported_fighter UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Le joueur que le spectateur supporte
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}', -- Données additionnelles sur le spectateur
    UNIQUE(session_id, user_id)
);

-- 3. Table des messages du chat Live Arena
CREATE TABLE IF NOT EXISTS app.live_chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'reaction', 'support', 'system'
    target_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Pour les messages directs
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}'
);

-- 4. Table des événements Live Arena
CREATE TABLE IF NOT EXISTS app.live_arena_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- 'question_start', 'answer_submitted', 'round_end', 'spectator_joined', etc.
    event_data JSONB DEFAULT '{}', -- Données spécifiques à l'événement
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Utilisateur concerné par l'événement
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE
);

-- 5. Table des vidéos Live Arena (post-live)
CREATE TABLE IF NOT EXISTS app.live_battle_videos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    duration INTEGER, -- Durée en secondes
    file_size BIGINT, -- Taille en bytes
    resolution VARCHAR(20), -- '720p', '1080p', etc.
    frame_rate INTEGER, -- FPS
    spectator_count INTEGER, -- Nombre de spectateurs pendant la session
    final_score JSONB, -- Scores finaux
    highlights JSONB DEFAULT '[]', -- Moments clés de la session
    status VARCHAR(20) DEFAULT 'processing', -- 'processing', 'ready', 'failed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Table des indicateurs économiques (pour données réelles)
CREATE TABLE IF NOT EXISTS app.economic_indicators (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country VARCHAR(100) NOT NULL,
    indicator VARCHAR(100) NOT NULL, -- 'GDP', 'inflation', 'unemployment', etc.
    value DECIMAL(15,4),
    unit VARCHAR(50), -- 'billion USD', 'percent', etc.
    date DATE NOT NULL,
    source VARCHAR(100), -- 'World Bank', 'IMF', 'BCEAO', etc.
    category VARCHAR(50), -- 'macro', 'trade', 'finance', etc.
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(country, indicator, date)
);

-- 7. Table des scénarios de marché africains
CREATE TABLE IF NOT EXISTS app.african_market_scenarios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL, -- 'Coffee', 'Cocoa', 'Oil', etc.
    title VARCHAR(200) NOT NULL,
    description TEXT,
    real_data JSONB DEFAULT '{}', -- Données économiques réelles
    events JSONB DEFAULT '[]', -- Événements possibles
    difficulty_level INTEGER DEFAULT 1, -- 1-5
    game_type VARCHAR(50) NOT NULL, -- 'market_master', etc.
    is_active BOOLEAN DEFAULT TRUE,
    usage_count INTEGER DEFAULT 0,
    success_rate DECIMAL(5,2) DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table des performances d'apprentissage adaptatif
CREATE TABLE IF NOT EXISTS app.adaptive_learning_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_type VARCHAR(50) NOT NULL,
    concept_mastery JSONB DEFAULT '{}', -- Maîtrise par concept économique
    difficulty_preference INTEGER DEFAULT 3, -- 1-5
    average_score DECIMAL(5,2) DEFAULT 0.0,
    average_time_seconds INTEGER DEFAULT 0,
    total_attempts INTEGER DEFAULT 0,
    successful_attempts INTEGER DEFAULT 0,
    last_session_date TIMESTAMPTZ,
    learning_path JSONB DEFAULT '[]', -- Chemin d'apprentissage recommandé
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, game_type)
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Indexes pour live_arena_sessions
CREATE INDEX IF NOT EXISTS idx_live_arena_sessions_status ON app.live_arena_sessions(status);
CREATE INDEX IF NOT EXISTS idx_live_arena_sessions_game_type ON app.live_arena_sessions(game_type);
CREATE INDEX IF NOT EXISTS idx_live_arena_sessions_created_at ON app.live_arena_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_arena_sessions_fighter1 ON app.live_arena_sessions(fighter1_id);
CREATE INDEX IF NOT EXISTS idx_live_arena_sessions_fighter2 ON app.live_arena_sessions(fighter2_id);

-- Indexes pour live_spectators
CREATE INDEX IF NOT EXISTS idx_live_spectators_session ON app.live_spectators(session_id);
CREATE INDEX IF NOT EXISTS idx_live_spectators_user ON app.live_spectators(user_id);
CREATE INDEX IF NOT EXISTS idx_live_spectators_active ON app.live_spectators(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_live_spectators_joined_at ON app.live_spectators(joined_at DESC);

-- Indexes pour live_chat_messages
CREATE INDEX IF NOT EXISTS idx_live_chat_session ON app.live_chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_live_chat_created_at ON app.live_chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_chat_user ON app.live_chat_messages(user_id);

-- Indexes pour live_arena_events
CREATE INDEX IF NOT EXISTS idx_live_events_session ON app.live_arena_events(session_id);
CREATE INDEX IF NOT EXISTS idx_live_events_timestamp ON app.live_arena_events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_live_events_type ON app.live_arena_events(event_type);

-- Indexes pour live_battle_videos
CREATE INDEX IF NOT EXISTS idx_live_videos_session ON app.live_battle_videos(session_id);
CREATE INDEX IF NOT EXISTS idx_live_videos_created_at ON app.live_battle_videos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_videos_status ON app.live_battle_videos(status);

-- Indexes pour economic_indicators
CREATE INDEX IF NOT EXISTS idx_economic_country ON app.economic_indicators(country);
CREATE INDEX IF NOT EXISTS idx_economic_indicator ON app.economic_indicators(indicator);
CREATE INDEX IF NOT EXISTS idx_economic_date ON app.economic_indicators(date DESC);
CREATE INDEX IF NOT EXISTS idx_economic_active ON app.economic_indicators(is_active) WHERE is_active = TRUE;

-- Indexes pour african_market_scenarios
CREATE INDEX IF NOT EXISTS idx_scenarios_country ON app.african_market_scenarios(country);
CREATE INDEX IF NOT EXISTS idx_scenarios_product ON app.african_market_scenarios(product);
CREATE INDEX IF NOT EXISTS idx_scenarios_game_type ON app.african_market_scenarios(game_type);
CREATE INDEX IF NOT EXISTS idx_scenarios_active ON app.african_market_scenarios(is_active) WHERE is_active = TRUE;

-- Indexes pour adaptive_learning_profiles
CREATE INDEX IF NOT EXISTS idx_adaptive_user ON app.adaptive_learning_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_adaptive_game_type ON app.adaptive_learning_profiles(game_type);
CREATE INDEX IF NOT EXISTS idx_adaptive_last_session ON app.adaptive_learning_profiles(last_session_date DESC);

-- =====================================================
-- RLS (Row Level Security) POLICIES
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.live_arena_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.live_spectators ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.live_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.live_arena_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.live_battle_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.economic_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.african_market_scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.adaptive_learning_profiles ENABLE ROW LEVEL SECURITY;

-- Politiques pour live_arena_sessions
CREATE POLICY "Users can view live sessions" ON app.live_arena_sessions
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can create live sessions" ON app.live_arena_sessions
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND 
                           (fighter1_id = auth.uid() OR fighter2_id = auth.uid()));

CREATE POLICY "Fighters can update their sessions" ON app.live_arena_sessions
    FOR UPDATE USING (auth.role() = 'authenticated' AND 
                      (fighter1_id = auth.uid() OR fighter2_id = auth.uid()));

-- Politiques pour live_spectators
CREATE POLICY "Users can view spectators" ON app.live_spectators
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can join as spectators" ON app.live_spectators
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their spectator status" ON app.live_spectators
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour live_chat_messages
CREATE POLICY "Users can view chat messages" ON app.live_chat_messages
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can send chat messages" ON app.live_chat_messages
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can delete their messages" ON app.live_chat_messages
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour live_arena_events
CREATE POLICY "Users can view live events" ON app.live_arena_events
    FOR SELECT USING (auth.role() = 'authenticated');

-- Politiques pour live_battle_videos
CREATE POLICY "Users can view battle videos" ON app.live_battle_videos
    FOR SELECT USING (auth.role() = 'authenticated');

-- Politiques pour economic_indicators
CREATE POLICY "Users can view economic indicators" ON app.economic_indicators
    FOR SELECT USING (auth.role() = 'authenticated');

-- Politiques pour african_market_scenarios
CREATE POLICY "Users can view market scenarios" ON app.african_market_scenarios
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active = TRUE);

-- Politiques pour adaptive_learning_profiles
CREATE POLICY "Users can view their own profile" ON app.adaptive_learning_profiles
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their own profile" ON app.adaptive_learning_profiles
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create profiles" ON app.adaptive_learning_profiles
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION app.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Appliquer le trigger aux tables pertinentes
CREATE TRIGGER update_live_arena_sessions_updated_at 
    BEFORE UPDATE ON app.live_arena_sessions 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_live_battle_videos_updated_at 
    BEFORE UPDATE ON app.live_battle_videos 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_economic_indicators_updated_at 
    BEFORE UPDATE ON app.economic_indicators 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_african_market_scenarios_updated_at 
    BEFORE UPDATE ON app.african_market_scenarios 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_adaptive_learning_profiles_updated_at 
    BEFORE UPDATE ON app.adaptive_learning_profiles 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour mettre à jour le compteur de spectateurs
CREATE OR REPLACE FUNCTION app.update_spectator_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.live_arena_sessions 
        SET spectator_count = spectator_count + 1 
        WHERE id = NEW.session_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.live_arena_sessions 
        SET spectator_count = GREATEST(spectator_count - 1, 0) 
        WHERE id = OLD.session_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_spectators_count_trigger
    AFTER INSERT OR DELETE ON app.live_spectators
    FOR EACH ROW EXECUTE FUNCTION app.update_spectator_count();

-- =====================================================
-- DONNÉES INITIALES
-- =====================================================

-- Insérer quelques scénarios de marché africains
INSERT INTO app.african_market_scenarios (country, product, title, description, real_data, events, game_type) VALUES
('Ethiopia', 'Coffee', 'Marché du Café - Éthiopie', 'Plus grand producteur de café en Afrique', 
 '{"production_2023": 764000, "export_value": 1.2, "price_per_kg": 3.15, "seasonal_factor": 1.2}',
 '[{"type": "weather", "description": "Saison des pluies retardée"}, {"type": "price", "description": "Hausse demande internationale"}]',
 'market_master'),
 
('Ivory Coast', 'Cocoa', 'Fèves de Cacao - Côte d''Ivoire', 'Premier producteur mondial de cacao',
 '{"production_2023": 2234000, "export_value": 5.8, "price_per_kg": 2.60, "global_market_share": 0.45}',
 '[{"type": "weather", "description": "Conditions climatiques favorables"}, {"type": "price", "description": "Stabilité des prix mondiaux"}]',
 'market_master'),
 
('Nigeria', 'Crude Oil', 'Pétrole Brut - Nigeria', 'Plus grand producteur de pétrole d''Afrique',
 '{"production_2023": 1.4, "price_per_barrel": 85.50, "opec_quota": 1.5}',
 '[{"type": "geopolitical", "description": "Décision OPEC sur la production"}, {"type": "price", "description": "Fluctuation des prix énergétiques"}]',
 'market_master');

-- Insérer quelques indicateurs économiques
INSERT INTO app.economic_indicators (country, indicator, value, unit, date, source, category) VALUES
('Ethiopia', 'GDP', 156.9, 'billion USD', '2023-12-31', 'World Bank', 'macro'),
('Ivory Coast', 'GDP', 70.0, 'billion USD', '2023-12-31', 'World Bank', 'macro'),
('Nigeria', 'GDP', 506.6, 'billion USD', '2023-12-31', 'World Bank', 'macro'),
('Ethiopia', 'Inflation', 33.9, 'percent', '2023-12-31', 'IMF', 'macro'),
('Ivory Coast', 'Inflation', 4.9, 'percent', '2023-12-31', 'IMF', 'macro'),
('Nigeria', 'Inflation', 31.7, 'percent', '2023-12-31', 'IMF', 'macro');
