# BOBODO PHASE 2 – Création manuelle de la table

## Problème
L'RPC execute_sql ne peut pas créer de tables (limitation de sécurité).

## Solution
Créer la table manuellement via le dashboard Supabase ou psql.

## SQL à exécuter manuellement

```sql
-- Table pour stocker la mémoire conversationnelle cross-session
CREATE TABLE app.bobodo_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    interests TEXT[],
    study_goals TEXT[],
    preferences TEXT[],
    key_information TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes
CREATE INDEX idx_bobodo_memory_student ON app.bobodo_memory(student_id);
CREATE INDEX idx_bobodo_memory_session ON app.bobodo_memory(session_id);
CREATE INDEX idx_bobodo_memory_created_at ON app.bobodo_memory(created_at DESC);

-- RLS
ALTER TABLE app.bobodo_memory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can read own memory"
    ON app.bobodo_memory
    FOR SELECT
    USING (auth.uid() = student_id);

CREATE POLICY "Service role can manage memory"
    ON app.bobodo_memory
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- RPCs
CREATE OR REPLACE FUNCTION app_save_bobodo_memory(
    p_session_id UUID,
    p_summary TEXT,
    p_interests TEXT[] DEFAULT NULL,
    p_study_goals TEXT[] DEFAULT NULL,
    p_preferences TEXT[] DEFAULT NULL,
    p_key_information TEXT[] DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_memory_id UUID;
    v_student_id UUID;
BEGIN
    SELECT student_id INTO v_student_id
    FROM app.bobodo_sessions
    WHERE id = p_session_id;
    
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    INSERT INTO app.bobodo_memory (
        student_id,
        session_id,
        summary,
        interests,
        study_goals,
        preferences,
        key_information
    ) VALUES (
        v_student_id,
        p_session_id,
        p_summary,
        p_interests,
        p_study_goals,
        p_preferences,
        p_key_information
    )
    ON CONFLICT (session_id)
    DO UPDATE SET
        summary = EXCLUDED.summary,
        interests = EXCLUDED.interests,
        study_goals = EXCLUDED.study_goals,
        preferences = EXCLUDED.preferences,
        key_information = EXCLUDED.key_information,
        updated_at = NOW()
    RETURNING id INTO v_memory_id;
    
    RETURN v_memory_id;
END;
$$;

CREATE OR REPLACE FUNCTION app_get_bobodo_memory(
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_memory JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
        'recent_summaries', (
            SELECT JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'summary', cm.summary,
                    'interests', cm.interests,
                    'study_goals', cm.study_goals,
                    'created_at', cm.created_at
                )
            )
            FROM app.bobodo_memory cm
            WHERE cm.student_id = p_student_id
            ORDER BY cm.created_at DESC
            LIMIT 5
        ),
        'all_interests', (
            SELECT ARRAY_AGG(DISTINCT unnest(interests))
            FROM app.bobodo_memory
            WHERE student_id = p_student_id
              AND interests IS NOT NULL
        ),
        'all_study_goals', (
            SELECT ARRAY_AGG(DISTINCT unnest(study_goals))
            FROM app.bobodo_memory
            WHERE student_id = p_student_id
              AND study_goals IS NOT NULL
        ),
        'all_preferences', (
            SELECT ARRAY_AGG(DISTINCT unnest(preferences))
            FROM app.bobodo_memory
            WHERE student_id = p_student_id
              AND preferences IS NOT NULL
        )
    ) INTO v_memory;
    
    RETURN v_memory;
END;
$$;

GRANT EXECUTE ON FUNCTION app_save_bobodo_memory(UUID, TEXT, TEXT[], TEXT[], TEXT[], TEXT[]) TO service_role;
GRANT EXECUTE ON FUNCTION app_get_bobodo_memory(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION app_get_bobodo_memory(UUID) TO authenticated;
```

## Instructions
1. Aller sur le dashboard Supabase
2. Ouvrir SQL Editor
3. Copier-coller le SQL ci-dessus
4. Exécuter
5. Vérifier que la table app.bobodo_memory existe
