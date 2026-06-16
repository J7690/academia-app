-- =====================================================
-- PRODUCTION DEPLOYMENT TABLES - SEMAINE 8
-- Tables pour monitoring, deployment, A/B testing et production
-- =====================================================

-- 1. Table Deployment Logs
CREATE TABLE IF NOT EXISTS app.deployment_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    deployment_id TEXT NOT NULL,
    environment VARCHAR(20) NOT NULL, -- development, staging, production
    version TEXT NOT NULL,
    build_number TEXT,
    git_commit TEXT,
    deployment_type VARCHAR(20) NOT NULL, -- full, hotfix, rollback, feature_flag
    status VARCHAR(20) NOT NULL, -- pending, running, success, failed, cancelled
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    deployed_by TEXT,
    rollback_version TEXT,
    error_message TEXT,
    affected_modules JSONB DEFAULT '{}',
    deployment_metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table Performance Metrics
CREATE TABLE IF NOT EXISTS app.performance_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_type VARCHAR(20) NOT NULL, -- app_startup, screen_load, api_response, user_interaction, ml_inference
    metric_name TEXT NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    unit VARCHAR(10), -- ms, mb, fps, count, percentage
    platform VARCHAR(20), -- ios, android, web
    app_version TEXT,
    device_model TEXT,
    os_version TEXT,
    network_type VARCHAR(20), -- wifi, cellular, none
    battery_level INTEGER,
    memory_usage_mb DECIMAL(8,2),
    cpu_usage DECIMAL(5,2),
    session_id UUID,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    context_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table Error Logs
CREATE TABLE IF NOT EXISTS app.error_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    error_type VARCHAR(20) NOT NULL, -- crash, exception, network_error, ml_error, user_error
    error_code TEXT,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    platform VARCHAR(20),
    app_version TEXT,
    device_model TEXT,
    os_version TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID,
    screen_name TEXT,
    action_name TEXT,
    user_agent TEXT,
    ip_address INET,
    context_data JSONB DEFAULT '{}',
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolution_action TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Table App Crashes
CREATE TABLE IF NOT EXISTS app.app_crashes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    crash_id TEXT UNIQUE NOT NULL,
    platform VARCHAR(20) NOT NULL,
    app_version TEXT NOT NULL,
    device_model TEXT,
    os_version TEXT,
    crash_type VARCHAR(20) NOT NULL, -- native, dart, framework, system
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID,
    screen_name TEXT,
    action_name TEXT,
    thread_name TEXT,
    is_fatal BOOLEAN DEFAULT TRUE,
    memory_usage_mb DECIMAL(8,2),
    cpu_usage DECIMAL(5,2),
    battery_level INTEGER,
    network_type VARCHAR(20),
    context_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table API Metrics
CREATE TABLE IF NOT EXISTS app.api_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    endpoint_path TEXT NOT NULL,
    method VARCHAR(10) NOT NULL, -- GET, POST, PUT, DELETE, PATCH
    status_code INTEGER NOT NULL,
    response_time_ms INTEGER NOT NULL,
    request_size_bytes INTEGER,
    response_size_bytes INTEGER,
    platform VARCHAR(20),
    app_version TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID,
    ip_address INET,
    user_agent TEXT,
    error_message TEXT,
    cache_hit BOOLEAN DEFAULT FALSE,
    database_query_time_ms INTEGER,
    external_api_calls INTEGER,
    context_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Table Feature Flags
CREATE TABLE IF NOT EXISTS app.feature_flags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    flag_key TEXT NOT NULL UNIQUE,
    flag_name TEXT NOT NULL,
    description TEXT,
    is_enabled BOOLEAN DEFAULT FALSE,
    rollout_percentage DECIMAL(5,2) DEFAULT 0.0,
    target_users JSONB DEFAULT '[]', -- Array of user IDs
    target_platforms JSONB DEFAULT '[]', -- Array of platforms
    target_versions JSONB DEFAULT '[]', -- Array of app versions
    conditions JSONB DEFAULT '{}', -- Complex targeting conditions
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- 7. Table A/B Tests
CREATE TABLE IF NOT EXISTS app.a_b_tests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    test_name TEXT NOT NULL,
    test_description TEXT,
    test_type VARCHAR(20) NOT NULL, -- ui_change, algorithm_change, feature_change, pricing_change
    variant_a JSONB NOT NULL, -- Control variant
    variant_b JSONB NOT NULL, -- Test variant
    traffic_split DECIMAL(5,2) DEFAULT 50.0, -- Percentage for variant B
    is_active BOOLEAN DEFAULT FALSE,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    target_audience JSONB DEFAULT '{}', -- Targeting criteria
    success_metrics JSONB DEFAULT '{}', -- Metrics to track
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table A/B Test Results
CREATE TABLE IF NOT EXISTS app.ab_test_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    test_id UUID NOT NULL REFERENCES app.a_b_tests(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    variant VARCHAR(10) NOT NULL, -- control, variant_b
    session_id UUID,
    platform VARCHAR(20),
    app_version TEXT,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    conversion_event TEXT,
    conversion_value DECIMAL(10,2),
    engagement_metrics JSONB DEFAULT '{}',
    performance_metrics JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Table System Health
CREATE TABLE IF NOT EXISTS app.system_health (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    service_name TEXT NOT NULL,
    health_status VARCHAR(20) NOT NULL, -- healthy, degraded, unhealthy, unknown
    response_time_ms INTEGER,
    error_rate DECIMAL(5,4),
    uptime_percentage DECIMAL(5,4),
    memory_usage_mb DECIMAL(8,2),
    cpu_usage DECIMAL(5,2),
    disk_usage_mb DECIMAL(10,2),
    active_connections INTEGER,
    database_connections INTEGER,
    cache_hit_rate DECIMAL(5,4),
    last_check_at TIMESTAMPTZ DEFAULT NOW(),
    health_details JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Table Backup Logs
CREATE TABLE IF NOT EXISTS app.backup_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    backup_type VARCHAR(20) NOT NULL, -- full, incremental, differential, snapshot
    backup_source TEXT NOT NULL, -- database, files, media, logs
    backup_size_mb DECIMAL(10,2),
    compression_ratio DECIMAL(5,4),
    backup_status VARCHAR(20) NOT NULL, -- started, running, success, failed, cancelled
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    backup_path TEXT,
    checksum TEXT,
    error_message TEXT,
    backup_metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Indexes pour deployment_logs
CREATE INDEX IF NOT EXISTS idx_deployment_logs_environment ON app.deployment_logs(environment);
CREATE INDEX IF NOT EXISTS idx_deployment_logs_status ON app.deployment_logs(status);
CREATE INDEX IF NOT EXISTS idx_deployment_logs_started_at ON app.deployment_logs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_deployment_logs_deployment_id ON app.deployment_logs(deployment_id);

-- Indexes pour performance_metrics
CREATE INDEX IF NOT EXISTS idx_performance_metrics_type ON app.performance_metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name ON app.performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_created_at ON app.performance_metrics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_user_id ON app.performance_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_session_id ON app.performance_metrics(session_id);

-- Indexes pour error_logs
CREATE INDEX IF NOT EXISTS idx_error_logs_type ON app.error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON app.error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_user_id ON app.error_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_error_logs_is_resolved ON app.error_logs(is_resolved);
CREATE INDEX IF NOT EXISTS idx_error_logs_platform ON app.error_logs(platform);

-- Indexes pour app_crashes
CREATE INDEX IF NOT EXISTS idx_app_crashes_platform ON app.app_crashes(platform);
CREATE INDEX IF NOT EXISTS idx_app_crashes_crash_type ON app.app_crashes(crash_type);
CREATE INDEX IF NOT EXISTS idx_app_crashes_created_at ON app.app_crashes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_crashes_user_id ON app.app_crashes(user_id);
CREATE INDEX IF NOT EXISTS idx_app_crashes_is_fatal ON app.app_crashes(is_fatal);

-- Indexes pour api_metrics
CREATE INDEX IF NOT EXISTS idx_api_metrics_endpoint ON app.api_metrics(endpoint_path);
CREATE INDEX IF NOT EXISTS idx_api_metrics_method ON app.api_metrics(method);
CREATE INDEX IF NOT EXISTS idx_api_metrics_status_code ON app.api_metrics(status_code);
CREATE INDEX IF NOT EXISTS idx_api_metrics_response_time ON app.api_metrics(response_time_ms);
CREATE INDEX IF NOT EXISTS idx_api_metrics_created_at ON app.api_metrics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_metrics_user_id ON app.api_metrics(user_id);

-- Indexes pour feature_flags
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON app.feature_flags(flag_key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_is_enabled ON app.feature_flags(is_enabled);
CREATE INDEX IF NOT EXISTS idx_feature_flags_expires_at ON app.feature_flags(expires_at);

-- Indexes pour a_b_tests
CREATE INDEX IF NOT EXISTS idx_a_b_tests_name ON app.a_b_tests(test_name);
CREATE INDEX IF NOT EXISTS idx_a_b_tests_is_active ON app.a_b_tests(is_active);
CREATE INDEX IF NOT EXISTS idx_a_b_tests_start_date ON app.a_b_tests(start_date);
CREATE INDEX IF NOT EXISTS idx_a_b_tests_end_date ON app.a_b_tests(end_date);

-- Indexes pour ab_test_results
CREATE INDEX IF NOT EXISTS idx_ab_test_results_test_id ON app.ab_test_results(test_id);
CREATE INDEX IF NOT EXISTS idx_ab_test_results_user_id ON app.ab_test_results(user_id);
CREATE INDEX IF NOT EXISTS idx_ab_test_results_variant ON app.ab_test_results(variant);
CREATE INDEX IF NOT EXISTS idx_ab_test_results_assigned_at ON app.ab_test_results(assigned_at DESC);

-- Indexes pour system_health
CREATE INDEX IF NOT EXISTS idx_system_health_service ON app.system_health(service_name);
CREATE INDEX IF NOT EXISTS idx_system_health_status ON app.system_health(health_status);
CREATE INDEX IF NOT EXISTS idx_system_health_last_check ON app.system_health(last_check_at DESC);

-- Indexes pour backup_logs
CREATE INDEX IF NOT EXISTS idx_backup_logs_type ON app.backup_logs(backup_type);
CREATE INDEX IF NOT EXISTS idx_backup_logs_status ON app.backup_logs(backup_status);
CREATE INDEX IF NOT EXISTS idx_backup_logs_started_at ON app.backup_logs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_backup_logs_source ON app.backup_logs(backup_source);

-- =====================================================
-- RLS (Row Level Security) POLICIES
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.deployment_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.app_crashes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.api_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.a_b_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ab_test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.system_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.backup_logs ENABLE ROW LEVEL SECURITY;

-- Politiques pour deployment_logs
CREATE POLICY "Users can view deployment logs" ON app.deployment_logs
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage deployment logs" ON app.deployment_logs
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour performance_metrics
CREATE POLICY "Users can view their own performance metrics" ON app.performance_metrics
    FOR SELECT USING (auth.role() = 'authenticated' AND (user_id = auth.uid() OR user_id IS NULL));

CREATE POLICY "System can manage performance metrics" ON app.performance_metrics
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour error_logs
CREATE POLICY "Users can view their own error logs" ON app.error_logs
    FOR SELECT USING (auth.role() = 'authenticated' AND (user_id = auth.uid() OR user_id IS NULL));

CREATE POLICY "System can manage error logs" ON app.error_logs
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour app_crashes
CREATE POLICY "Users can view their own crash logs" ON app.app_crashes
    FOR SELECT USING (auth.role() = 'authenticated' AND (user_id = auth.uid() OR user_id IS NULL));

CREATE POLICY "System can manage crash logs" ON app.app_crashes
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour api_metrics
CREATE POLICY "Users can view their own API metrics" ON app.api_metrics
    FOR SELECT USING (auth.role() = 'authenticated' AND (user_id = auth.uid() OR user_id IS NULL));

CREATE POLICY "System can manage API metrics" ON app.api_metrics
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour feature_flags
CREATE POLICY "Users can view feature flags" ON app.feature_flags
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage feature flags" ON app.feature_flags
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour a_b_tests
CREATE POLICY "Users can view A/B tests" ON app.a_b_tests
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage A/B tests" ON app.a_b_tests
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour ab_test_results
CREATE POLICY "Users can view their own A/B test results" ON app.ab_test_results
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage A/B test results" ON app.ab_test_results
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour system_health
CREATE POLICY "Users can view system health" ON app.system_health
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage system health" ON app.system_health
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour backup_logs
CREATE POLICY "Users can view backup logs" ON app.backup_logs
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage backup logs" ON app.backup_logs
    FOR ALL USING (auth.role() = 'authenticated');

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
CREATE TRIGGER update_feature_flags_updated_at 
    BEFORE UPDATE ON app.feature_flags 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_a_b_tests_updated_at 
    BEFORE UPDATE ON app.a_b_tests 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour calculer les métriques de performance agrégées
CREATE OR REPLACE FUNCTION app.calculate_performance_aggregates()
RETURNS TRIGGER AS $$
BEGIN
    -- Mettre à jour les métriques de performance par type
    INSERT INTO app.system_health (service_name, health_status, response_time_ms, last_check_at)
    SELECT 
        'performance_metrics',
        CASE 
            WHEN AVG(metric_value) > 1000 THEN 'degraded'
            WHEN AVG(metric_value) > 5000 THEN 'unhealthy'
            ELSE 'healthy'
        END,
        AVG(metric_value)::INTEGER,
        NOW()
    FROM app.performance_metrics 
    WHERE created_at > NOW() - INTERVAL '10 minutes'
    GROUP BY metric_type
    ON CONFLICT (service_name) DO UPDATE SET
        health_status = EXCLUDED.health_status,
        response_time_ms = EXCLUDED.response_time_ms,
        last_check_at = EXCLUDED.last_check_at;
    
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_performance_aggregates_trigger
    AFTER INSERT ON app.performance_metrics
    FOR EACH ROW EXECUTE FUNCTION app.calculate_performance_aggregates();

-- Trigger pour calculer les taux d'erreur
CREATE OR REPLACE FUNCTION app.calculate_error_rates()
RETURNS TRIGGER AS $$
BEGIN
    -- Mettre à jour les taux d'erreur par type
    INSERT INTO app.system_health (service_name, health_status, error_rate, last_check_at)
    SELECT 
        'error_rate_' || error_type,
        CASE 
            WHEN COUNT(*) > 100 THEN 'unhealthy'
            WHEN COUNT(*) > 50 THEN 'degraded'
            ELSE 'healthy'
        END,
        (COUNT(*) * 100.0 / (
            SELECT COUNT(*) FROM app.error_logs 
            WHERE created_at > NOW() - INTERVAL '1 hour'
        ))::DECIMAL(5,4),
        NOW()
    FROM app.error_logs 
    WHERE created_at > NOW() - INTERVAL '1 hour'
    GROUP BY error_type
    ON CONFLICT (service_name) DO UPDATE SET
        health_status = EXCLUDED.health_status,
        error_rate = EXCLUDED.error_rate,
        last_check_at = EXCLUDED.last_check_at;
    
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_error_rates_trigger
    AFTER INSERT ON app.error_logs
    FOR EACH ROW EXECUTE FUNCTION app.calculate_error_rates();

-- Trigger pour nettoyer les logs anciens
CREATE OR REPLACE FUNCTION app.cleanup_old_logs()
RETURNS TRIGGER AS $$
BEGIN
    -- Supprimer les logs de plus de 30 jours
    DELETE FROM app.deployment_logs WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM app.error_logs WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM app.app_crashes WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM app.api_metrics WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM app.performance_metrics WHERE created_at < NOW() - INTERVAL '7 days';
    
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER cleanup_old_logs_trigger
    AFTER INSERT ON app.deployment_logs
    FOR EACH ROW EXECUTE FUNCTION app.cleanup_old_logs();

-- =====================================================
-- DONNÉES INITIALES
-- =====================================================

-- Insérer quelques feature flags par défaut
INSERT INTO app.feature_flags (flag_key, flag_name, description, is_enabled, rollout_percentage, target_platforms) VALUES
('ml_predictions', 'ML Predictions', 'Enable ML predictions for revenue and engagement', true, 100.0, '["ios", "android", "web"]'),
('recommendations_v2', 'Recommendations v2', 'New recommendation algorithm', true, 50.0, '["ios", "android"]'),
('enhanced_analytics', 'Enhanced Analytics', 'Enhanced analytics tracking', true, 100.0, '["ios", "android", "web"]'),
('a_b_testing_ui', 'A/B Testing UI', 'Enable A/B testing interface', false, 0.0, '[]'),
('performance_monitoring', 'Performance Monitoring', 'Real-time performance monitoring', true, 100.0, '["ios", "android", "web"]');

-- Insérer un A/B test par défaut
INSERT INTO app.a_b_tests (test_name, test_description, test_type, variant_a, variant_b, traffic_split, is_active, success_metrics) VALUES
('recommendation_algorithm', 'Test new recommendation algorithm vs current', 'algorithm_change', 
    '{"algorithm": "collaborative_filtering", "weights": {"views": 0.4, "likes": 0.3, "shares": 0.3}}',
    '{"algorithm": "hybrid_ml", "weights": {"views": 0.3, "likes": 0.4, "shares": 0.3}, "ml_features": true}',
    50.0, false, '{"primary_metric": "click_through_rate", "secondary_metrics": ["engagement_time", "conversion_rate"]}');

-- Insérer quelques métriques de santé système par défaut
INSERT INTO app.system_health (service_name, health_status, response_time_ms, error_rate, uptime_percentage, last_check_at) VALUES
('api_gateway', 'healthy', 150, 0.0012, 99.95, NOW()),
('database', 'healthy', 25, 0.0008, 99.98, NOW()),
('cache_service', 'healthy', 5, 0.0001, 99.99, NOW()),
('ml_service', 'healthy', 45, 0.0023, 99.92, NOW()),
('notification_service', 'healthy', 30, 0.0005, 99.97, NOW());
