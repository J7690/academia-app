-- ========================================
-- BOBODO – Mémoire Émotionnelle
-- ========================================

-- Table pour stocker les états émotionnels détectés
CREATE TABLE app.bobodo_emotional_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    emotional_state TEXT NOT NULL, -- satisfied, frustrated, emotional, neutral
    detected_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes pour optimiser les requêtes
CREATE INDEX idx_bobodo_emotional_states_student ON app.bobodo_emotional_states(student_id);
CREATE INDEX idx_bobodo_emotional_states_session ON app.bobodo_emotional_states(session_id);
CREATE INDEX idx_bobodo_emotional_states_detected_at ON app.bobodo_emotional_states(detected_at DESC);

-- RLS Policies
ALTER TABLE app.bobodo_emotional_states ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can read own emotional states"
    ON app.bobodo_emotional_states
    FOR SELECT
    USING (auth.uid() = student_id);

CREATE POLICY "Service role can manage emotional states"
    ON app.bobodo_emotional_states
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- RPC pour enregistrer un état émotionnel
CREATE OR REPLACE FUNCTION app_log_bobodo_emotional_state(
    p_session_id UUID,
    p_emotional_state TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_state_id UUID;
    v_student_id UUID;
BEGIN
    -- Récupérer le student_id depuis la session
    SELECT student_id INTO v_student_id
    FROM app.bobodo_sessions
    WHERE id = p_session_id;
    
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    -- Insérer l'état émotionnel
    INSERT INTO app.bobodo_emotional_states (
        student_id,
        session_id,
        emotional_state
    ) VALUES (
        v_student_id,
        p_session_id,
        p_emotional_state
    )
    RETURNING id INTO v_state_id;
    
    RETURN v_state_id;
END;
$$;

-- RPC pour récupérer les tendances émotionnelles d'un étudiant
CREATE OR REPLACE FUNCTION app_get_bobodo_emotional_trends(
    p_student_id UUID,
    p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trends JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
        'total_states', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_states
            WHERE student_id = p_student_id
              AND detected_at >= NOW() - (p_days || ' days')::INTERVAL
        ),
        'satisfaction_count', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_states
            WHERE student_id = p_student_id
              AND emotional_state = 'satisfied'
              AND detected_at >= NOW() - (p_days || ' days')::INTERVAL
        ),
        'frustration_count', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_states
            WHERE student_id = p_student_id
              AND emotional_state = 'frustrated'
              AND detected_at >= NOW() - (p_days || ' days')::INTERVAL
        ),
        'emotional_count', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_states
            WHERE student_id = p_student_id
              AND emotional_state = 'emotional'
              AND detected_at >= NOW() - (p_days || ' days')::INTERVAL
        ),
        'neutral_count', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_states
            WHERE student_id = p_student_id
              AND emotional_state = 'neutral'
              AND detected_at >= NOW() - (p_days || ' days')::INTERVAL
        ),
        'recent_states', (
            SELECT JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'emotional_state', es.emotional_state,
                    'detected_at', es.detected_at
                )
            )
            FROM app.bobodo_emotional_states es
            WHERE es.student_id = p_student_id
            ORDER BY es.detected_at DESC
            LIMIT 10
        )
    ) INTO v_trends;
    
    RETURN v_trends;
END;
$$;

GRANT EXECUTE ON FUNCTION app_log_bobodo_emotional_state(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION app_get_bobodo_emotional_trends(UUID, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION app_get_bobodo_emotional_trends(UUID, INTEGER) TO authenticated;
