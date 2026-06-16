-- =====================================================
-- MACHINE LEARNING TABLES - SEMAINE 7
-- Tables pour ML, IA, prédictions, analytics et optimisation
-- =====================================================

-- 1. Table ML Models
CREATE TABLE IF NOT EXISTS app.ml_models (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    model_name TEXT NOT NULL UNIQUE,
    model_type VARCHAR(20) NOT NULL, -- classification, regression, clustering, recommendation, anomaly_detection
    model_version VARCHAR(10) NOT NULL,
    model_file_path TEXT, -- Chemin vers le fichier modèle TensorFlow Lite
    input_shape JSONB NOT NULL, -- Shape des entrées [height, width, channels]
    output_shape JSONB NOT NULL, -- Shape des sorties
    input_preprocessing JSONB DEFAULT '{}', -- Prétraitement requis
    output_postprocessing JSONB DEFAULT '{}', -- Post-traitement requis
    accuracy DECIMAL(5,4) DEFAULT 0.0,
    precision DECIMAL(5,4) DEFAULT 0.0,
    recall DECIMAL(5,4) DEFAULT 0.0,
    f1_score DECIMAL(5,4) DEFAULT 0.0,
    training_data_count INTEGER DEFAULT 0,
    validation_data_count INTEGER DEFAULT 0,
    training_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    is_deployed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table ML Predictions
CREATE TABLE IF NOT EXISTS app.ml_predictions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    model_id UUID NOT NULL REFERENCES app.ml_models(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    prediction_type VARCHAR(20) NOT NULL, -- revenue_prediction, engagement_prediction, recommendation, anomaly_detection
    input_data JSONB NOT NULL, -- Données d'entrée pour la prédiction
    prediction_result JSONB NOT NULL, -- Résultat de la prédiction
    confidence_score DECIMAL(5,4) DEFAULT 0.0,
    prediction_value DECIMAL(10,2), -- Valeur prédite
    actual_value DECIMAL(10,2), -- Valeur réelle (pour évaluation)
    error_margin DECIMAL(10,2), -- Marge d'erreur
    processing_time_ms INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table Training Data
CREATE TABLE IF NOT EXISTS app.ml_training_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    model_id UUID REFERENCES app.ml_models(id) ON DELETE CASCADE,
    data_type VARCHAR(20) NOT NULL, -- training, validation, test
    input_features JSONB NOT NULL, -- Caractéristiques d'entrée
    target_value DECIMAL(10,2), -- Valeur cible
    feature_importance JSONB DEFAULT '{}', -- Importance des caractéristiques
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Table ML Analytics
CREATE TABLE IF NOT EXISTS app.ml_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    model_id UUID REFERENCES app.ml_models(id) ON DELETE CASCADE,
    metric_type VARCHAR(20) NOT NULL, -- accuracy, precision, recall, f1_score, loss, training_time
    metric_value DECIMAL(10,4) NOT NULL,
    epoch_number INTEGER,
    training_data_count INTEGER,
    validation_data_count INTEGER,
    learning_rate DECIMAL(8,6),
    batch_size INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table Recommendations
CREATE TABLE IF NOT EXISTS app.recommendations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recommendation_type VARCHAR(20) NOT NULL, -- content, course, challenge, sponsorship, optimization
    item_id TEXT NOT NULL, -- ID de l'élément recommandé
    item_type VARCHAR(20) NOT NULL, -- course, video, article, product, service
    item_title TEXT NOT NULL,
    recommendation_score DECIMAL(5,4) NOT NULL,
    confidence DECIMAL(5,4) DEFAULT 0.0,
    reason TEXT, -- Raison de la recommandation
    context_data JSONB DEFAULT '{}', -- Contexte de la recommandation
    is_clicked BOOLEAN DEFAULT FALSE,
    is_dismissed BOOLEAN DEFAULT FALSE,
    is_converted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

-- 6. Table User Behavior Tracking
CREATE TABLE IF NOT EXISTS app.user_behavior_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES app.user_sessions(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL, -- page_view, click, scroll, hover, search, purchase, share, like, comment
    event_name TEXT NOT NULL,
    target_id TEXT, -- ID de l'élément cible
    target_type VARCHAR(20), -- page, button, link, content, product
    properties JSONB DEFAULT '{}', -- Propriétés additionnelles
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    duration_ms INTEGER, -- Durée de l'événement
    scroll_depth INTEGER, -- Profondeur de scroll
    mouse_position JSONB, -- Position de la souris
    device_info JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Table Performance Metrics ML
CREATE TABLE IF NOT EXISTS app.performance_metrics_ml (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES app.user_sessions(id) ON DELETE CASCADE,
    metric_type VARCHAR(20) NOT NULL, -- app_performance, user_engagement, content_performance, conversion_rate
    metric_name TEXT NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    baseline_value DECIMAL(10,4), -- Valeur de référence
    improvement_percentage DECIMAL(5,2), -- Pourcentage d'amélioration
    prediction_accuracy DECIMAL(5,4), -- Précision de la prédiction
    optimization_applied BOOLEAN DEFAULT FALSE,
    optimization_type VARCHAR(20), -- cache, prefetch, compression, layout, content
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table Anomaly Detection
CREATE TABLE IF NOT EXISTS app.anomaly_detection (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    anomaly_type VARCHAR(20) NOT NULL, -- performance, security, behavior, revenue, engagement
    severity VARCHAR(10) NOT NULL, -- low, medium, high, critical
    anomaly_score DECIMAL(5,4) NOT NULL,
    threshold DECIMAL(5,4) NOT NULL,
    description TEXT,
    affected_metrics JSONB DEFAULT '{}', -- Métriques affectées
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution_action TEXT,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Table AI Insights
CREATE TABLE IF NOT EXISTS app.ai_insights (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    insight_type VARCHAR(20) NOT NULL, -- pattern, trend, prediction, recommendation, anomaly
    insight_category VARCHAR(20) NOT NULL, -- user_behavior, performance, revenue, engagement, content
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    confidence DECIMAL(5,4) NOT NULL,
    impact_score DECIMAL(5,4) NOT NULL,
    data_evidence JSONB DEFAULT '{}', -- Données supportant l'insight
    actionable BOOLEAN DEFAULT TRUE,
    action_taken BOOLEAN DEFAULT FALSE,
    action_result TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);

-- 10. Table Model Training Jobs
CREATE TABLE IF NOT EXISTS app.model_training_jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    model_id UUID REFERENCES app.ml_models(id) ON DELETE CASCADE,
    job_name TEXT NOT NULL,
    job_type VARCHAR(20) NOT NULL, -- training, retraining, fine_tuning, evaluation
    status VARCHAR(20) DEFAULT 'pending', -- pending, running, completed, failed, cancelled
    progress DECIMAL(5,2) DEFAULT 0.0,
    total_epochs INTEGER DEFAULT 0,
    current_epoch INTEGER DEFAULT 0,
    training_loss DECIMAL(10,4) DEFAULT 0.0,
    validation_loss DECIMAL(10,4) DEFAULT 0.0,
    learning_rate DECIMAL(8,6) DEFAULT 0.001,
    batch_size INTEGER DEFAULT 32,
    training_data_count INTEGER DEFAULT 0,
    validation_data_count INTEGER DEFAULT 0,
    hyperparameters JSONB DEFAULT '{}',
    metrics JSONB DEFAULT '{}',
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Indexes pour ml_models
CREATE INDEX IF NOT EXISTS idx_ml_models_model_type ON app.ml_models(model_type);
CREATE INDEX IF NOT EXISTS idx_ml_models_is_active ON app.ml_models(is_active);
CREATE INDEX IF NOT EXISTS idx_ml_models_is_deployed ON app.ml_models(is_deployed);
CREATE INDEX IF NOT EXISTS idx_ml_models_accuracy ON app.ml_models(accuracy DESC);

-- Indexes pour ml_predictions
CREATE INDEX IF NOT EXISTS idx_ml_predictions_model_id ON app.ml_predictions(model_id);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_user_id ON app.ml_predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_type ON app.ml_predictions(prediction_type);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_created_at ON app.ml_predictions(created_at DESC);

-- Indexes pour ml_training_data
CREATE INDEX IF NOT EXISTS idx_ml_training_data_model_id ON app.ml_training_data(model_id);
CREATE INDEX IF NOT EXISTS idx_ml_training_data_data_type ON app.ml_training_data(data_type);
CREATE INDEX IF NOT EXISTS idx_ml_training_data_target_value ON app.ml_training_data(target_value);

-- Indexes pour ml_analytics
CREATE INDEX IF NOT EXISTS idx_ml_analytics_model_id ON app.ml_analytics(model_id);
CREATE INDEX IF NOT EXISTS idx_ml_analytics_metric_type ON app.ml_analytics(metric_type);
CREATE INDEX IF NOT EXISTS idx_ml_analytics_created_at ON app.ml_analytics(created_at DESC);

-- Indexes pour recommendations
CREATE INDEX IF NOT EXISTS idx_recommendations_user_id ON app.recommendations(user_id);
CREATE INDEX IF NOT EXISTS idx_recommendations_type ON app.recommendations(recommendation_type);
CREATE INDEX IF NOT EXISTS idx_recommendations_score ON app.recommendations(recommendation_score DESC);
CREATE INDEX IF NOT EXISTS idx_recommendations_created_at ON app.recommendations(created_at DESC);

-- Indexes pour user_behavior_tracking
CREATE INDEX IF NOT EXISTS idx_user_behavior_user_id ON app.user_behavior_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_user_behavior_session_id ON app.user_behavior_tracking(session_id);
CREATE INDEX IF NOT EXISTS idx_user_behavior_event_type ON app.user_behavior_tracking(event_type);
CREATE INDEX IF NOT EXISTS idx_user_behavior_timestamp ON app.user_behavior_tracking(timestamp DESC);

-- Indexes pour performance_metrics_ml
CREATE INDEX IF NOT EXISTS idx_performance_metrics_ml_user_id ON app.performance_metrics_ml(user_id);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_ml_type ON app.performance_metrics_ml(metric_type);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_ml_created_at ON app.performance_metrics_ml(created_at DESC);

-- Indexes pour anomaly_detection
CREATE INDEX IF NOT EXISTS idx_anomaly_detection_user_id ON app.anomaly_detection(user_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_detection_type ON app.anomaly_detection(anomaly_type);
CREATE INDEX IF NOT EXISTS idx_anomaly_detection_severity ON app.anomaly_detection(severity);
CREATE INDEX IF NOT EXISTS idx_anomaly_detection_score ON app.anomaly_detection(anomaly_score DESC);

-- Indexes pour ai_insights
CREATE INDEX IF NOT EXISTS idx_ai_insights_type ON app.ai_insights(insight_type);
CREATE INDEX IF NOT EXISTS idx_ai_insights_category ON app.ai_insights(insight_category);
CREATE INDEX IF NOT EXISTS idx_ai_insights_impact ON app.ai_insights(impact_score DESC);
CREATE INDEX IF NOT EXISTS idx_ai_insights_created_at ON app.ai_insights(created_at DESC);

-- Indexes pour model_training_jobs
CREATE INDEX IF NOT EXISTS idx_model_training_jobs_model_id ON app.model_training_jobs(model_id);
CREATE INDEX IF NOT EXISTS idx_model_training_jobs_status ON app.model_training_jobs(status);
CREATE INDEX IF NOT EXISTS idx_model_training_jobs_created_at ON app.model_training_jobs(created_at DESC);

-- =====================================================
-- RLS (Row Level Security) POLICIES
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE app.ml_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ml_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ml_training_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ml_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.user_behavior_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.performance_metrics_ml ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.anomaly_detection ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.model_training_jobs ENABLE ROW LEVEL SECURITY;

-- Politiques pour ml_models
CREATE POLICY "Users can view ML models" ON app.ml_models
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admin can create ML models" ON app.ml_models
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admin can update ML models" ON app.ml_models
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Politiques pour ml_predictions
CREATE POLICY "Users can view their own predictions" ON app.ml_predictions
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can create predictions" ON app.ml_predictions
    FOR INSERT;

-- Politiques pour recommendations
CREATE POLICY "Users can view their own recommendations" ON app.recommendations
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage recommendations" ON app.recommendations
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour user_behavior_tracking
CREATE POLICY "Users can view their own behavior" ON app.user_behavior_tracking
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can track behavior" ON app.user_behavior_tracking
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour performance_metrics_ml
CREATE POLICY "Users can view their own metrics" ON app.performance_metrics_ml
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage metrics" ON app.performance_metrics_ml
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour anomaly_detection
CREATE POLICY "Users can view their own anomalies" ON app.anomaly_detection
    FOR SELECT USING (auth.role() = 'authenticated' AND user_id = auth.uid());

CREATE POLICY "System can manage anomalies" ON app.anomaly_detection
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour ai_insights
CREATE POLICY "Users can view insights" ON app.ai_insights
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage insights" ON app.ai_insights
    FOR ALL USING (auth.role() = 'authenticated');

-- Politiques pour model_training_jobs
CREATE POLICY "Users can view training jobs" ON app.model_training_jobs
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can manage training jobs" ON app.model_training_jobs
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
CREATE TRIGGER update_ml_models_updated_at 
    BEFORE UPDATE ON app.ml_models 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_ml_predictions_updated_at 
    BEFORE UPDATE ON app.ml_predictions 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_ml_training_data_updated_at 
    BEFORE UPDATE ON app.ml_training_data 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_ml_analytics_updated_at 
    BEFORE UPDATE ON app.ml_analytics 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_recommendations_updated_at 
    BEFORE UPDATE ON app.recommendations 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_anomaly_detection_updated_at 
    BEFORE UPDATE ON app.anomaly_detection 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_model_training_jobs_updated_at 
    BEFORE UPDATE ON app.model_training_jobs 
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger pour calculer les métriques de performance
CREATE OR REPLACE FUNCTION app.calculate_performance_metrics()
RETURNS TRIGGER AS $$
BEGIN
    -- Mettre à jour les métriques de performance du modèle
    UPDATE app.ml_models SET 
        accuracy = (
            SELECT AVG(metric_value) 
            FROM app.ml_analytics 
            WHERE model_id = NEW.model_id AND metric_type = 'accuracy'
        ),
        precision = (
            SELECT AVG(metric_value) 
            FROM app.ml_analytics 
            WHERE model_id = NEW.model_id AND metric_type = 'precision'
        ),
        recall = (
            SELECT AVG(metric_value) 
            FROM app.ml_analytics 
            WHERE model_id = NEW.model_id AND metric_type = 'recall'
        ),
        f1_score = (
            SELECT AVG(metric_value) 
            FROM app.ml_analytics 
            WHERE model_id = NEW.model_id AND metric_type = 'f1_score'
        )
    WHERE id = NEW.model_id;
    
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_model_performance_trigger
    AFTER INSERT OR UPDATE ON app.ml_analytics
    FOR EACH ROW EXECUTE FUNCTION app.calculate_performance_metrics();

-- Trigger pour nettoyer les recommandations expirées
CREATE OR REPLACE FUNCTION app.cleanup_expired_recommendations()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM app.recommendations WHERE expires_at < NOW();
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER cleanup_expired_recommendations_trigger
    AFTER INSERT ON app.recommendations
    FOR EACH ROW EXECUTE FUNCTION app.cleanup_expired_recommendations();

-- Trigger pour nettoyer les insights expirés
CREATE OR REPLACE FUNCTION app.cleanup_expired_insights()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM app.ai_insights WHERE expires_at < NOW();
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER cleanup_expired_insights_trigger
    AFTER INSERT ON app.ai_insights
    FOR EACH ROW EXECUTE FUNCTION app.cleanup_expired_insights();

-- =====================================================
-- DONNÉES INITIALES
-- =====================================================

-- Insérer quelques modèles ML par défaut
INSERT INTO app.ml_models (model_name, model_type, model_version, input_shape, output_shape, accuracy, precision, recall, f1_score, is_active, is_deployed) VALUES
('revenue_prediction_v1', 'regression', '1.0', '[10, 1]', '[1]', 0.85, 0.87, 0.82, 0.84, true, true),
('engagement_prediction_v1', 'classification', '1.0', '[15, 1]', '[3, 1]', 0.78, 0.81, 0.76, 0.78, true, true),
('content_recommendation_v1', 'recommendation', '1.0', '[20, 1]', '[10, 1]', 0.72, 0.75, 0.70, 0.73, true, true),
('anomaly_detection_v1', 'anomaly_detection', '1.0', '[25, 1]', '[1]', 0.91, 0.89, 0.93, 0.91, true, true);

-- Insérer quelques insights par défaut
INSERT INTO app.ai_insights (insight_type, insight_category, title, description, confidence, impact_score, actionable, data_evidence) VALUES
('pattern', 'user_behavior', 'Peak Usage Hours', 'Users are most active between 8-10pm and 6-8pm', 0.92, 0.85, true, '{"peak_hours": ["20:00-22:00", "18:00-20:00"], "avg_sessions": 45}'),
('trend', 'revenue', 'Revenue Growth Trend', 'Revenue is growing 15% month-over-month', 0.88, 0.92, true, '{"growth_rate": 0.15, "monthly_revenue": 2500}'),
('prediction', 'engagement', 'High Engagement Predicted', 'Users with >10 sessions likely to convert', 0.79, 0.78, true, '{"conversion_probability": 0.73, "avg_sessions": 12}'),
('recommendation', 'content', 'Optimize Content Strategy', 'Focus on video content for higher engagement', 0.85, 0.81, true, '{"content_types": ["video", "interactive"], "engagement_lift": 0.25}');
