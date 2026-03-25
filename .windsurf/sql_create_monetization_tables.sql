-- =====================================================
-- MONETIZATION TABLES - SEMAINE 5
-- Tables pour TikTok Creator Fund, Sponsorships, Premium
-- =====================================================

-- 1. Table TikTok Creator Fund
CREATE TABLE IF NOT EXISTS app.tiktok_creator_fund (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tiktok_creator_id TEXT UNIQUE, -- ID créateur TikTok
    fund_level VARCHAR(20) DEFAULT 'bronze', -- bronze, silver, gold, platinum
    monthly_views BIGINT DEFAULT 0,
    monthly_likes BIGINT DEFAULT 0,
    monthly_shares BIGINT DEFAULT 0,
    monthly_engagement_rate DECIMAL(5,2) DEFAULT 0.0,
    monthly_revenue DECIMAL(10,2) DEFAULT 0.0, -- Revenus mensuels
    total_revenue DECIMAL(10,2) DEFAULT 0.0, -- Revenus totaux
    payout_method VARCHAR(20) DEFAULT 'bank_transfer', -- bank_transfer, paypal, crypto
    payout_info JSONB DEFAULT '{}', -- Informations de paiement chiffrées
    is_eligible BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_calculated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table Sponsorships
CREATE TABLE IF NOT EXISTS app.sponsorships (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES app.brand_partnerships(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    sponsorship_type VARCHAR(20) DEFAULT 'battle', -- battle, post_live, clip, general
    requirements JSONB DEFAULT '[]', -- Exigences du sponsor
    compensation_type VARCHAR(20) DEFAULT 'fixed', -- fixed, cpm, cpc, revenue_share
    compensation_amount DECIMAL(10,2) DEFAULT 0.0,
    compensation_currency VARCHAR(3) DEFAULT 'USD',
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'pending', -- pending, active, completed, cancelled
    deliverables JSONB DEFAULT '[]', -- Livrables requis
    metrics_tracked JSONB DEFAULT '{}', -- Métriques suivies
    actual_performance JSONB DEFAULT '{}', -- Performance réelle
    payout_status VARCHAR(20) DEFAULT 'pending', -- pending, paid, failed
    payout_amount DECIMAL(10,2) DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table Brand Partnerships
CREATE TABLE IF NOT EXISTS app.brand_partnerships (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_name TEXT NOT NULL,
    brand_description TEXT,
    brand_logo_url TEXT,
    brand_website TEXT,
    industry VARCHAR(50),
    target_audience JSONB DEFAULT '[]', -- Audience cible
    budget_range_min DECIMAL(10,2) DEFAULT 0.0,
    budget_range_max DECIMAL(10,2) DEFAULT 0.0,
    budget_currency VARCHAR(3) DEFAULT 'USD',
    contact_email TEXT,
    contact_phone TEXT,
    partnership_types JSONB DEFAULT '[]', -- Types de partenariats acceptés
    requirements JSONB DEFAULT '[]', -- Exigences générales
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Table Premium Subscriptions
CREATE TABLE IF NOT EXISTS app.premium_subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_plan VARCHAR(20) DEFAULT 'basic', -- basic, premium, pro, enterprise
    subscription_type VARCHAR(20) DEFAULT 'monthly', -- monthly, yearly, lifetime
    price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(20) DEFAULT 'stripe', -- stripe, paypal, app_store, play_store
    payment_provider_id TEXT, -- ID du paiement chez le provider
    auto_renew BOOLEAN DEFAULT TRUE,
    trial_start TIMESTAMPTZ,
    trial_end TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    status VARCHAR(20) DEFAULT 'active', -- active, cancelled, expired, trialing
    features JSONB DEFAULT '[]', -- Fonctionnalités incluses
    usage_stats JSONB DEFAULT '{}', -- Statistiques d'utilisation
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table Revenue Analytics
CREATE TABLE IF NOT EXISTS app.revenue_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    revenue_source VARCHAR(50) NOT NULL, -- tiktok_fund, sponsorship, premium, ads
    revenue_type VARCHAR(20) NOT NULL, -- fixed, cpm, cpc, subscription, other
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    reference_id TEXT, -- ID de référence (sponsorship_id, subscription_id, etc.)
    reference_type VARCHAR(50), -- Type de référence
    metadata JSONB DEFAULT '{}', -- Métadonnées additionnelles
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, paid, failed
    payout_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Table Ad Revenue
CREATE TABLE IF NOT EXISTS app.ad_revenue (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ad_unit_id TEXT NOT NULL, -- ID de l'unité publicitaire
    ad_format VARCHAR(20) DEFAULT 'banner', -- banner, interstitial, rewarded, native
    platform VARCHAR(20) DEFAULT 'google', -- google, facebook, tiktok, other
    impressions BIGINT DEFAULT 0,
    clicks BIGINT DEFAULT 0,
    ctr DECIMAL(5,4) DEFAULT 0.0, -- Click-through rate
    cpm DECIMAL(10,4) DEFAULT 0.0, -- Cost per mille
    cpc DECIMAL(10,4) DEFAULT 0.0, -- Cost per click
    revenue DECIMAL(10,2) DEFAULT 0.0,
    currency VARCHAR(3) DEFAULT 'USD',
    date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Table Merchandise Sales
CREATE TABLE IF NOT EXISTS app.merchandise_sales (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    product_name TEXT NOT NULL,
    product_type VARCHAR(20) DEFAULT 'clothing', -- clothing, accessories, digital, other
    product_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    commission_rate DECIMAL(5,2) DEFAULT 10.0, -- Taux de commission
    commission_amount DECIMAL(10,2) DEFAULT 0.0,
    customer_info JSONB DEFAULT '{}', -- Informations client (anonymisées)
    shipping_info JSONB DEFAULT '{}', -- Informations livraison
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, shipped, delivered, cancelled
    tracking_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table Campaign Performance
CREATE TABLE IF NOT EXISTS app.campaign_performance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    campaign_id TEXT NOT NULL, -- ID de la campagne
    campaign_name TEXT NOT NULL,
    campaign_type VARCHAR(20) DEFAULT 'awareness', -- awareness, conversion, engagement
    platform VARCHAR(20) DEFAULT 'tiktok', -- tiktok, instagram, facebook, google
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    budget DECIMAL(10,2) NOT NULL,
    spent DECIMAL(10,2) DEFAULT 0.0,
    impressions BIGINT DEFAULT 0,
    clicks BIGINT DEFAULT 0,
    conversions BIGINT DEFAULT 0,
    ctr DECIMAL(5,4) DEFAULT 0.0,
    cpc DECIMAL(10,4) DEFAULT 0.0,
    cpa DECIMAL(10,4) DEFAULT 0.0, -- Cost per acquisition
    roas DECIMAL(5,2) DEFAULT 0.0, -- Return on ad spend
    status VARCHAR(20) DEFAULT 'active', -- active, paused, completed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Indexes pour tiktok_creator_fund
CREATE INDEX IF NOT EXISTS idx_tiktok_creator_fund_user_id ON app.tiktok_creator_fund(user_id);
CREATE INDEX IF NOT EXISTS idx_tiktok_creator_fund_fund_level ON app.tiktok_creator_fund(fund_level);
CREATE INDEX IF NOT EXISTS idx_tiktok_creator_fund_is_eligible ON app.tiktok_creator_fund(is_eligible);
CREATE INDEX IF NOT EXISTS idx_tiktok_creator_fund_monthly_revenue ON app.tiktok_creator_fund(monthly_revenue DESC);

-- Indexes pour sponsorships
CREATE INDEX IF NOT EXISTS idx_sponsorships_user_id ON app.sponsorships(user_id);
CREATE INDEX IF NOT EXISTS idx_sponsorships_brand_id ON app.sponsorships(brand_id);
CREATE INDEX IF NOT EXISTS idx_sponsorships_status ON app.sponsorships(status);
CREATE INDEX IF NOT EXISTS idx_sponsorships_start_date ON app.sponsorships(start_date);
CREATE INDEX IF NOT EXISTS idx_sponsorships_compensation_amount ON app.sponsorships(compensation_amount DESC);

-- Indexes pour brand_partnerships
CREATE INDEX IF NOT EXISTS idx_brand_partnerships_industry ON app.brand_partnerships(industry);
CREATE INDEX IF NOT EXISTS idx_brand_partnerships_is_active ON app.brand_partnerships(is_active);
CREATE INDEX IF NOT EXISTS idx_brand_partnerships_is_verified ON app.brand_partnerships(is_verified);
CREATE INDEX IF NOT EXISTS idx_brand_partnerships_budget_range_max ON app.brand_partnerships(budget_range_max DESC);

-- Indexes pour premium_subscriptions
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_user_id ON app.premium_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_plan ON app.premium_subscriptions(subscription_plan);
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_status ON app.premium_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_current_period_end ON app.premium_subscriptions(current_period_end);

-- Indexes pour revenue_analytics
CREATE INDEX IF NOT EXISTS idx_revenue_analytics_user_id ON app.revenue_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_revenue_analytics_revenue_source ON app.revenue_analytics(revenue_source);
CREATE INDEX IF NOT EXISTS idx_revenue_analytics_period_start ON app.revenue_analytics(period_start DESC);
CREATE INDEX IF NOT EXISTS idx_revenue_analytics_amount ON app.revenue_analytics(amount DESC);

-- Indexes pour ad_revenue
CREATE INDEX IF NOT EXISTS idx_ad_revenue_user_id ON app.ad_revenue(user_id);
CREATE INDEX IF NOT EXISTS idx_ad_revenue_platform ON app.ad_revenue(platform);
CREATE INDEX IF NOT EXISTS idx_ad_revenue_date ON app.ad_revenue(date DESC);
CREATE INDEX IF NOT EXISTS idx_ad_revenue_revenue ON app.ad_revenue(revenue DESC);

-- Indexes pour merchandise_sales
CREATE INDEX IF NOT EXISTS idx_merchandise_sales_user_id ON app.merchandise_sales(user_id);
CREATE INDEX IF NOT EXISTS idx_merchandise_sales_status ON app.merchandise_sales(status);
CREATE INDEX IF NOT EXISTS idx_merchandise_sales_created_at ON app.merchandise_sales(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_merchandise_sales_total_amount ON app.merchandise_sales(total_amount DESC);

-- Indexes pour campaign_performance
CREATE INDEX IF NOT EXISTS idx_campaign_performance_user_id ON app.campaign_performance(user_id);
CREATE INDEX IF NOT EXISTS idx_campaign_performance_platform ON app.campaign_performance(platform);
CREATE INDEX IF NOT EXISTS idx_campaign_performance_status ON app.campaign_performance(status);
CREATE INDEX IF NOT EXISTS idx_campaign_performance_roas ON app.campaign_performance(roas DESC);

-- =====================================================
-- RLS (Row Level Security) POLICIES
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.tiktok_creator_fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.sponsorships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.brand_partnerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.premium_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.revenue_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ad_revenue ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.merchandise_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.campaign_performance ENABLE ROW LEVEL SECURITY;

-- Politiques pour tiktok_creator_fund
CREATE POLICY "Users can view their own creator fund" ON app.tiktok_creator_fund
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create their own creator fund" ON app.tiktok_creator_fund
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their own creator fund" ON app.tiktok_creator_fund
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour sponsorships
CREATE POLICY "Users can view their sponsorships" ON app.sponsorships
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create sponsorships" ON app.sponsorships
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their sponsorships" ON app.sponsorships
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour brand_partnerships
CREATE POLICY "Users can view brand partnerships" ON app.brand_partnerships
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);

CREATE POLICY "Admin can create brand partnerships" ON app.brand_partnerships
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admin can update brand partnerships" ON app.brand_partnerships
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Politiques pour premium_subscriptions
CREATE POLICY "Users can view their subscriptions" ON app.premium_subscriptions
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create subscriptions" ON app.premium_subscriptions
    FOR INSERT;

CREATE POLICY "System can update subscriptions" ON app.premium_subscriptions
    FOR UPDATE;

-- Politiques pour revenue_analytics
CREATE POLICY "Users can view their revenue analytics" ON app.revenue_analytics
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create revenue analytics" ON app.revenue_analytics
    FOR INSERT;

-- Politiques pour ad_revenue
CREATE POLICY "Users can view their ad revenue" ON app.ad_revenue
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create ad revenue" ON app.ad_revenue
    FOR INSERT;

-- Politiques pour merchandise_sales
CREATE POLICY "Users can view their merchandise sales" ON app.merchandise_sales
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create merchandise sales" ON app.merchandise_sales
    FOR INSERT;

-- Politiques pour campaign_performance
CREATE POLICY "Users can view their campaign performance" ON app.campaign_performance
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create campaign performance" ON app.campaign_performance
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
CREATE TRIGGER update_tiktok_creator_fund_updated_at 
    BEFORE UPDATE ON app.tiktok_creator_fund 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_sponsorships_updated_at 
    BEFORE UPDATE ON app.sponsorships 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_brand_partnerships_updated_at 
    BEFORE UPDATE ON app.brand_partnerships 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_premium_subscriptions_updated_at 
    BEFORE UPDATE ON app.premium_subscriptions 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_revenue_analytics_updated_at 
    BEFORE UPDATE ON app.revenue_analytics 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_ad_revenue_updated_at 
    BEFORE UPDATE ON app.ad_revenue 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_merchandise_sales_updated_at 
    BEFORE UPDATE ON app.merchandise_sales 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_campaign_performance_updated_at 
    BEFORE UPDATE ON app.campaign_performance 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour calculer l'engagement rate
CREATE OR REPLACE FUNCTION app.calculate_engagement_rate()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.monthly_views > 0 THEN
        NEW.monthly_engagement_rate = ((NEW.monthly_likes + NEW.monthly_shares)::DECIMAL / NEW.monthly_views) * 100;
    ELSE
        NEW.monthly_engagement_rate = 0.0;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_tiktok_engagement_rate_trigger
    BEFORE INSERT OR UPDATE ON app.tiktok_creator_fund
    FOR EACH ROW EXECUTE FUNCTION app.calculate_engagement_rate();

-- Trigger pour calculer le CTR
CREATE OR REPLACE FUNCTION app calculate_ctr()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.impressions > 0 THEN
        NEW.ctr = (NEW.clicks::DECIMAL / NEW.impressions) * 100;
    ELSE
        NEW.ctr = 0.0;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_ad_ctr_trigger
    BEFORE INSERT OR UPDATE ON app.ad_revenue
    FOR EACH ROW EXECUTE FUNCTION app.calculate_ctr();

-- Trigger pour calculer le ROAS
CREATE OR REPLACE FUNCTION app.calculate_roas()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.spent > 0 THEN
        NEW.roas = (NEW.conversions * 50.0) / NEW.spent; -- Supposant 50$ par conversion
    ELSE
        NEW.roas = 0.0;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_campaign_roas_trigger
    BEFORE INSERT OR UPDATE ON app.campaign_performance
    FOR EACH ROW EXECUTE FUNCTION app.calculate_roas();

-- =====================================================
-- DONNÉES INITIALES
-- =====================================================

-- Inscrire quelques marques partenaires par défaut
INSERT INTO app.brand_partnerships (brand_name, brand_description, industry, budget_range_min, budget_range_max, contact_email, partnership_types, is_verified) VALUES
('Nike', 'Sportswear and athletic footwear', 'sports', 10000.00, 50000.00, 'partnerships@nike.com', '["battle", "post_live", "clip"]', true),
('Adidas', 'Sports clothing and accessories', 'sports', 5000.00, 25000.00, 'marketing@adidas.com', '["battle", "general"]', true),
('Red Bull', 'Energy drinks and extreme sports', 'beverages', 15000.00, 75000.00, 'sponsorship@redbull.com', '["battle", "clip"]', true),
('Samsung', 'Electronics and mobile devices', 'technology', 20000.00, 100000.00, 'partnerships@samsung.com', '["post_live", "general"]', true),
('Coca-Cola', 'Beverages and soft drinks', 'beverages', 10000.00, 60000.00, 'marketing@coca-cola.com', '["battle", "post_live"]', true);

-- Inscrire quelques plans premium par défaut
INSERT INTO app.premium_subscriptions (user_id, subscription_plan, subscription_type, price, current_period_start, current_period_end, status, features) VALUES
('demo_user_1', 'basic', 'monthly', 9.99, NOW(), NOW() + INTERVAL '1 month', 'active', '["basic_analytics", "standard_support"]'),
('demo_user_2', 'premium', 'monthly', 19.99, NOW(), NOW() + INTERVAL '1 month', 'active', '["advanced_analytics", "priority_support", "custom_themes"]'),
('demo_user_3', 'pro', 'yearly', 199.99, NOW(), NOW() + INTERVAL '1 year', 'active', '["enterprise_analytics", "dedicated_support", "white_label", "api_access"]');
