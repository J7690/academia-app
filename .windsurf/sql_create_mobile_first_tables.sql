-- =====================================================
-- MOBILE FIRST TABLES - SEMAINE 6
-- Tables pour wallet, cache, analytics mobile, notifications
-- =====================================================

-- 1. Table User Wallets
CREATE TABLE IF NOT EXISTS app.user_wallets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    balance DECIMAL(15,2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'USD',
    total_earned DECIMAL(15,2) DEFAULT 0.00,
    total_spent DECIMAL(15,2) DEFAULT 0.00,
    last_transaction_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table Payment Methods
CREATE TABLE IF NOT EXISTS app.payment_methods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    method_type VARCHAR(20) NOT NULL, -- credit_card, paypal, apple_pay, google_pay, crypto
    provider VARCHAR(20) NOT NULL, -- stripe, paypal, apple, google, metamask
    method_token TEXT, -- Token chiffré du provider
    last_four TEXT, -- 4 derniers chiffres pour carte de crédit
    expiry_month INTEGER,
    expiry_year INTEGER,
    brand TEXT, -- Visa, Mastercard, etc.
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table Transactions
CREATE TABLE IF NOT EXISTS app.wallet_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL, -- credit, debit, refund, withdrawal
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    description TEXT,
    reference_id TEXT, -- Référence à la source (sponsorship_id, subscription_id, etc.)
    reference_type VARCHAR(50),
    status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed, cancelled
    payment_method_id UUID REFERENCES app.payment_methods(id),
    fee_amount DECIMAL(10,2) DEFAULT 0.00,
    net_amount DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Table App Cache
CREATE TABLE IF NOT EXISTS app.app_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    cache_key TEXT NOT NULL,
    cache_value JSONB NOT NULL,
    cache_type VARCHAR(20) NOT NULL, -- user_data, app_config, api_response, image, video
    expires_at TIMESTAMPTZ,
    size_bytes INTEGER DEFAULT 0,
    access_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table User Sessions
CREATE TABLE IF NOT EXISTS app.user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_token TEXT UNIQUE NOT NULL,
    device_id TEXT,
    device_type VARCHAR(20), -- ios, android, web, desktop
    app_version TEXT,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Table Mobile Analytics
CREATE TABLE IF NOT EXISTS app.mobile_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES app.user_sessions(id),
    event_type VARCHAR(50) NOT NULL, -- app_open, screen_view, button_click, purchase, share, etc.
    event_name TEXT NOT NULL,
    event_data JSONB DEFAULT '{}',
    screen_name TEXT,
    duration_ms INTEGER,
    device_info JSONB DEFAULT '{}',
    app_version TEXT,
    network_type VARCHAR(20), -- wifi, cellular, none
    battery_level INTEGER,
    is_charging BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Table Push Tokens
CREATE TABLE IF NOT EXISTS app.push_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL, -- ios, android, web
    device_id TEXT,
    app_version TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table Device Info
CREATE TABLE IF NOT EXISTS app.device_info (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT UNIQUE NOT NULL,
    platform VARCHAR(20) NOT NULL,
    os_version TEXT,
    app_version TEXT,
    manufacturer TEXT,
    model TEXT,
    screen_resolution TEXT,
    screen_density DECIMAL(5,2),
    total_storage BIGINT,
    available_storage BIGINT,
    memory_total BIGINT,
    memory_available BIGINT,
    cpu_cores INTEGER,
    is_jailbroken BOOLEAN DEFAULT FALSE,
    language TEXT,
    timezone TEXT,
    country_code VARCHAR(2),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Table Mobile Notifications
CREATE TABLE IF NOT EXISTS app.mobile_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    notification_type VARCHAR(20) NOT NULL, -- revenue, sponsorship, system, social, reminder
    priority VARCHAR(10) DEFAULT 'normal', -- low, normal, high, critical
    data JSONB DEFAULT '{}',
    image_url TEXT,
    action_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    is_clicked BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Table Performance Metrics
CREATE TABLE IF NOT EXISTS app.performance_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES app.user_sessions(id),
    metric_type VARCHAR(20) NOT NULL, -- app_start, screen_load, api_response, video_play
    metric_name TEXT NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    unit VARCHAR(10), -- ms, mb, fps, etc.
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Indexes pour user_wallets
CREATE INDEX IF NOT EXISTS idx_user_wallets_user_id ON app.user_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_user_wallets_balance ON app.user_wallets(balance DESC);
CREATE INDEX IF NOT EXISTS idx_user_wallets_updated_at ON app.user_wallets(updated_at DESC);

-- Indexes pour payment_methods
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON app.payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_is_default ON app.payment_methods(is_default);
CREATE INDEX IF NOT EXISTS idx_payment_methods_is_active ON app.payment_methods(is_active);

-- Indexes pour wallet_transactions
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON app.wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON app.wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON app.wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON app.wallet_transactions(created_at DESC);

-- Indexes pour app_cache
CREATE INDEX IF NOT EXISTS idx_app_cache_user_id ON app.app_cache(user_id);
CREATE INDEX IF NOT EXISTS idx_app_cache_key ON app.app_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_app_cache_type ON app.app_cache(cache_type);
CREATE INDEX IF NOT EXISTS idx_app_cache_expires_at ON app.app_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_app_cache_last_accessed ON app.app_cache(last_accessed_at DESC);

-- Indexes pour user_sessions
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON app.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON app.user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_device_id ON app.user_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_active ON app.user_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON app.user_sessions(expires_at);

-- Indexes pour mobile_analytics
CREATE INDEX IF NOT EXISTS idx_mobile_analytics_user_id ON app.mobile_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_mobile_analytics_session_id ON app.mobile_analytics(session_id);
CREATE INDEX IF NOT EXISTS idx_mobile_analytics_event_type ON app.mobile_analytics(event_type);
CREATE INDEX IF NOT EXISTS idx_mobile_analytics_created_at ON app.mobile_analytics(created_at DESC);

-- Indexes pour push_tokens
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON app.push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_token ON app.push_tokens(token);
CREATE INDEX IF NOT EXISTS idx_push_tokens_platform ON app.push_tokens(platform);
CREATE INDEX IF NOT EXISTS idx_push_tokens_is_active ON app.push_tokens(is_active);

-- Indexes pour device_info
CREATE INDEX IF NOT EXISTS idx_device_info_user_id ON app.device_info(user_id);
CREATE INDEX IF NOT EXISTS idx_device_info_device_id ON app.device_info(device_id);
CREATE INDEX IF NOT EXISTS idx_device_info_platform ON app.device_info(platform);
CREATE INDEX IF NOT EXISTS idx_device_info_last_seen ON app.device_info(last_seen_at DESC);

-- Indexes pour mobile_notifications
CREATE INDEX IF NOT EXISTS idx_mobile_notifications_user_id ON app.mobile_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_mobile_notifications_type ON app.mobile_notifications(notification_type);
CREATE INDEX IF NOT EXISTS idx_mobile_notifications_priority ON app.mobile_notifications(priority);
CREATE INDEX IF NOT EXISTS idx_mobile_notifications_is_read ON app.mobile_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_mobile_notifications_created_at ON app.mobile_notifications(created_at DESC);

-- Indexes pour performance_metrics
CREATE INDEX IF NOT EXISTS idx_performance_metrics_user_id ON app.performance_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_session_id ON app.performance_metrics(session_id);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_type ON app.performance_metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_created_at ON app.performance_metrics(created_at DESC);

-- =====================================================
-- RLS (Row Level Security) POLICIES
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.user_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.app_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.mobile_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.device_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.mobile_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.performance_metrics ENABLE ROW LEVEL SECURITY;

-- Politiques pour user_wallets
CREATE POLICY "Users can view their own wallet" ON app.user_wallets
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create their own wallet" ON app.user_wallets
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their own wallet" ON app.user_wallets
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour payment_methods
CREATE POLICY "Users can view their own payment methods" ON app.payment_methods
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can create their own payment methods" ON app.payment_methods
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "Users can update their own payment methods" ON app.payment_methods
    FOR UPDATE USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour wallet_transactions
CREATE POLICY "Users can view their own transactions" ON app.wallet_transactions
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create transactions" ON app.wallet_transactions
    FOR INSERT;

CREATE POLICY "System can update transactions" ON app.wallet_transactions
    FOR UPDATE;

-- Politiques pour app_cache
CREATE POLICY "Users can view their own cache" ON app.app_cache
    FOR SELECT USING (auth.role() = 'authenticated' AND (user_id = auth.uid() OR user_id IS NULL));

CREATE POLICY "System can manage cache" ON app.app_cache
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour user_sessions
CREATE POLICY "Users can view their own sessions" ON app.user_sessions
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage sessions" ON app.user_sessions
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour mobile_analytics
CREATE POLICY "Users can view their own analytics" ON app.mobile_analytics
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create analytics" ON app.mobile_analytics
    FOR INSERT;

-- Politiques pour push_tokens
CREATE POLICY "Users can manage their own push tokens" ON app.push_tokens
    FOR ALL USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Politiques pour device_info
CREATE POLICY "Users can view their own device info" ON app.device_info
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage device info" ON app.device_info
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour mobile_notifications
CREATE POLICY "Users can view their own notifications" ON app.mobile_notifications
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage notifications" ON app.mobile_notifications
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour performance_metrics
CREATE POLICY "Users can view their own performance metrics" ON app.performance_metrics
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create performance metrics" ON app.performance_metrics
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
CREATE TRIGGER update_user_wallets_updated_at 
    BEFORE UPDATE ON app.user_wallets 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_payment_methods_updated_at 
    BEFORE UPDATE ON app.payment_methods 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_wallet_transactions_updated_at 
    BEFORE UPDATE ON app.wallet_transactions 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_app_cache_updated_at 
    BEFORE UPDATE ON app.app_cache 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_user_sessions_updated_at 
    BEFORE UPDATE ON app.user_sessions 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_device_info_updated_at 
    BEFORE UPDATE ON app.device_info 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_mobile_notifications_updated_at 
    BEFORE UPDATE ON app.mobile_notifications 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour mettre à jour le solde du wallet
CREATE OR REPLACE FUNCTION app.update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE app.user_wallets 
        SET 
            balance = balance + CASE 
                WHEN NEW.transaction_type = 'credit' THEN NEW.net_amount
                WHEN NEW.transaction_type = 'debit' THEN -NEW.net_amount
                WHEN NEW.transaction_type = 'refund' THEN NEW.net_amount
                ELSE 0
            END,
            total_earned = total_earned + CASE 
                WHEN NEW.transaction_type = 'credit' OR NEW.transaction_type = 'refund' THEN NEW.net_amount
                ELSE 0
            END,
            total_spent = total_spent + CASE 
                WHEN NEW.transaction_type = 'debit' THEN NEW.net_amount
                ELSE 0
            END,
            last_transaction_at = NEW.created_at
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_wallet_balance_trigger
    AFTER INSERT OR UPDATE ON app.wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION app.update_wallet_balance();

-- Trigger pour nettoyer le cache expiré
CREATE OR REPLACE FUNCTION app.cleanup_expired_cache()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM app.app_cache WHERE expires_at < NOW();
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER cleanup_expired_cache_trigger
    AFTER INSERT ON app.app_cache
    FOR EACH ROW EXECUTE FUNCTION app.cleanup_expired_cache();

-- Trigger pour mettre à jour les statistiques de session
CREATE OR REPLACE FUNCTION app.update_session_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE app.user_sessions 
    SET last_activity_at = NOW()
    WHERE id = NEW.session_id;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_session_activity_trigger
    AFTER INSERT ON app.mobile_analytics
    FOR EACH ROW EXECUTE FUNCTION app.update_session_activity();

-- =====================================================
-- DONNÉES INITIALES
-- =====================================================

-- Insérer quelques wallets par défaut
INSERT INTO app.user_wallets (user_id, balance, currency) VALUES
('demo_user_1', 100.00, 'USD'),
('demo_user_2', 250.00, 'USD'),
('demo_user_3', 500.00, 'USD');

-- Insérer quelques méthodes de paiement par défaut
INSERT INTO app.payment_methods (user_id, method_type, provider, method_token, last_four, is_default) VALUES
('demo_user_1', 'credit_card', 'stripe', 'tok_123456', '1234', true),
('demo_user_2', 'paypal', 'paypal', 'tok_789012', '5678', true),
('demo_user_3', 'apple_pay', 'apple', 'tok_345678', '9012', true);
