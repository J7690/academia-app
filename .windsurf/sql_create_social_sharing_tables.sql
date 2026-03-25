-- =====================================================
-- SOCIAL SHARING TABLES - SEMAINE 4
-- Tables pour le partage TikTok/Instagram et Post-Live Feed
-- =====================================================

-- 1. Table des partages TikTok
CREATE TABLE IF NOT EXISTS app.tiktok_shares (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    battle_id UUID REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title TEXT,
    description TEXT,
    hashtags TEXT DEFAULT '[]',
    duration INTEGER, -- Durée en secondes
    file_size BIGINT, -- Taille en bytes
    share_token TEXT UNIQUE, -- Token pour le partage TikTok
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, published, failed
    tiktok_video_id TEXT, -- ID vidéo retourné par TikTok
    platform VARCHAR(20) DEFAULT 'tiktok', -- tiktok, instagram, facebook
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTZ DEFAULT NOW()
);

-- 2. Table des partages Instagram/Facebook
CREATE TABLE IF NOT EXISTS app.social_shares (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    battle_id UUID REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title TEXT,
    description TEXT,
    hashtags TEXT DEFAULT '[]',
    duration INTEGER,
    file_size BIGINT,
    platform VARCHAR(20) DEFAULT 'instagram', -- instagram, facebook
    share_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTZ DEFAULT NOW()
);

-- 3. Table du Post-Live Feed
CREATE TABLE IF NOT EXISTS app.post_live_feed (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    battle_id UUID NOT NULL REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title TEXT NOT NULL,
    description TEXT,
    tags TEXT DEFAULT '[]',
    highlights JSONB DEFAULT '[]', -- Moments clés du battle
    viewer_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    duration INTEGER,
    file_size BIGINT,
    status VARCHAR(20) DEFAULT 'processing', -- processing, ready, failed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Table des liens des réseaux sociaux
CREATE TABLE IF NOT EXISTS app.social_media_links (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL, -- tiktok, instagram, facebook, twitter, youtube
    platform_user_id TEXT, -- ID utilisateur sur la plateforme
    platform_username TEXT, -- Nom d'utilisateur sur la plateforme
    access_token TEXT, -- Token d'accès (chiffré)
    refresh_token TEXT, -- Token de rafraîchissement (chiffré)
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table des analytics de partage
CREATE TABLE IF NOT EXISTS app.share_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    share_id UUID NOT NULL,
    share_type VARCHAR(50) NOT NULL, -- tiktok, instagram, facebook, post_live
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content_id UUID REFERENCES app.tiktok_shares(id) ON DELETE CASCADE,
    platform VARCHAR(20) DEFAULT 'tiktok',
    views INTEGER DEFAULT 0,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    engagement_rate DECIMAL(5,2) DEFAULT 0.0,
    reach INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Table des clips courts (moments forts)
CREATE TABLE IF NOT EXISTS app.battle_clips (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    battle_id UUID NOT NULL REFERENCES app.live_arena_sessions(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    start_time DECIMAL(5,2), -- Position en secondes
    end_time DECIMAL(5,2), -- Position en secondes
    duration INTEGER,
    description TEXT,
    is_highlight BOOLEAN DEFAULT FALSE,
    category VARCHAR(50) DEFAULT 'general', -- general, victory, reaction, support
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Indexes pour tiktok_shares
CREATE INDEX IF NOT EXISTS idx_tiktok_shares_user_id ON app.tiktok_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_tiktok_shares_battle_id ON app.tiktok_shares(battle_id);
CREATE INDEX IF NOT EXISTS idx_tiktok_shares_status ON app.tiktok_shares(status);
CREATE INDEX IF NOT EXISTS idx_tiktok_shares_created_at ON app.tiktok_shares(created_at DESC);

-- Indexes pour social_shares
CREATE INDEX IF NOT EXISTS idx_social_shares_user_id ON app.social_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_social_shares_battle_id ON app.social_shares(battle_id);
CREATE INDEX IF NOT EXISTS idx_social_shares_platform ON app.social_shares(platform);
CREATE INDEX IF NOT EXISTS idx_social_shares_created_at ON app.social_shares(created_at DESC);

-- Indexes pour post_live_feed
CREATE INDEX IF NOT EXISTS idx_post_live_feed_battle_id ON app.post_live_feed(battle_id);
CREATE INDEX IF NOT EXISTS idx_post_live_feed_status ON app.post_live_feed(status);
CREATE INDEX IF NOT EXISTS idx_post_live_feed_created_at ON app.post_live_feed(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_live_feed_viewer_count ON app.post_live_feed(viewer_count DESC);

-- Indexes pour social_media_links
CREATE INDEX IF NOT EXISTS idx_social_media_links_user_id ON app.social_media_links(user_id);
CREATE INDEX IF NOT EXISTS idx_social_media_links_platform ON app.social_media_links(platform);
CREATE INDEX IF NOT EXISTS idx_social_media_links_is_active ON app.social_media_links(is_active);

-- Indexes pour share_analytics
CREATE INDEX IF NOT EXISTS idx_share_analytics_share_id ON app.share_analytics(share_id);
CREATE INDEX IF NOT EXISTS idx_share_analytics_share_type ON app.share_analytics(share_type);
CREATE INDEX IF NOT EXISTS idx_share_analytics_user_id ON app.share_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_share_analytics_created_at ON app.share_analytics(created_at DESC);

-- Indexes pour battle_clips
CREATE INDEX IF NOT EXISTS idx_battle_clips_battle_id ON app.battle_clips(battle_id);
CREATE IF NOT EXISTS idx_battle_clips_is_highlight ON app.battle_clips(is_highlight);
CREATE INDEX IF NOT EXISTS idx_battle_clips_created_at ON app.battle_clips(created_at DESC);

-- =====================================================
-- RLS (Row Level Security) POLICIES
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.tiktok_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.social_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.post_live_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.social_media_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.share_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.battle_clips ENABLE ROW LEVEL SECURITY;

-- Politiques pour tiktok_shares
CREATE POLICY "Users can view their own TikTok shares" ON app.tiktok_shares
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create TikTok shares" ON app.tiktok_shares
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their TikTok shares" ON app.tiktok_shares
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour social_shares
CREATE POLICY "Users can view their own social shares" ON app.social_shares
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create social shares" ON app.social_shares
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their social shares" ON app.social_shares
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour post_live_feed
CREATE POLICY "Users can view post-live feed" ON app.post_live_feed
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can create post-live feed entries" ON app.post_live_feed
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update their post-live feed entries" ON app.post_live_feed
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Politiques pour social_media_links
CREATE POLICY "Users can view their social media links" ON app.social_media_links
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create social media links" ON app.social_media_links
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their social media links" ON app.social_media_links
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour share_analytics
CREATE POLICY "Users can view share analytics" ON app.share_analytics
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can create share analytics" ON app.share_analytics
    FOR INSERT;

-- Politiques pour battle_clips
CREATE POLICY "Users can view battle clips" ON app.battle_clips
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can create battle clips" ON app.battle_clips
    FOR INSERT;

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
CREATE TRIGGER update_tiktok_shares_updated_at 
    BEFORE UPDATE ON app.tiktok_shares 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_social_shares_updated_at 
    BEFORE UPDATE ON app.social_shares 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_post_live_feed_updated_at 
    BEFORE UPDATE ON app.post_live_feed 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_social_media_links_updated_at 
    BEFORE UPDATE ON app.social_media_links 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_share_analytics_updated_at 
    BEFORE UPDATE ON app.share_analytics 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_battle_clips_updated_at 
    BEFORE UPDATE ON app.battle_clips 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour mettre à jour les compteurs
CREATE OR REPLACE FUNCTION app.update_post_live_feed_counters()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE app.post_live_feed 
        SET 
            like_count = COALESCE(
                (SELECT COUNT(*) FROM app.share_analytics WHERE share_id = NEW.id AND share_type = 'like'),
                0
            ),
            comment_count = COALESCE(
                (SELECT COUNT(*) FROM app.share_analytics WHERE share_id = NEW.id AND share_type = 'comment'),
                0
            ),
            share_count = COALESCE(
                (SELECT COUNT(*) FROM app.share_analytics WHERE share_id = NEW.id),
                0
            )
        WHERE id = NEW.id;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_post_live_feed_counters_trigger
    AFTER INSERT OR UPDATE ON app.post_live_feed
    FOR EACH ROW EXECUTE FUNCTION app.update_post_live_feed_counters();

-- Trigger pour mettre à jour les analytics après partage
CREATE OR REPLACE FUNCTION app.update_share_analytics_after_share()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Mettre à jour le post_live_feed
        IF NEW.content_id IS NOT NULL THEN
            UPDATE app.post_live_feed 
            SET share_count = share_count + 1
            WHERE id = NEW.content_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_share_analytics_after_share_trigger
    AFTER INSERT ON app.share_analytics
    FOR EACH ROW EXECUTE FUNCTION app.update_share_analytics_after_share();

-- =====================================================
-- DONNÉES INITIALES
-- =====================================================

-- Insérer quelques scénarios de partage par défaut
INSERT INTO app.social_media_links (user_id, platform, platform_username, is_verified) VALUES
('demo_user_1', 'tiktok', 'academia_official', false),
('demo_user_1', 'instagram', 'academia_official', false),
('demo_user_1', 'facebook', 'Academia Education', true);

-- Insérer quelques clips de battle par défaut
INSERT INTO app.battle_clips (battle_id, video_url, thumbnail_url, start_time, end_time, duration, description, is_highlight, category) VALUES
('demo_battle_1', 'https://example.com/battle1.mp4', 'https://example.com/thumb1.jpg', 15.5, 45.2, 30, 'Victoire écrasante !', true, 'victory'),
('demo_battle_1', 'https://example.com/battle2.mp4', 'https://example.com/thumb2.jpg', 120.0, 150.0, 30, 'Réaction émouvante', false, 'reaction'),
('demo_battle_1', 'https://example.com/battle3.mp4', 'https://example.com/thumb3.jpg', 200.0, 210.0, 10, 'Support intense', false, 'support');
