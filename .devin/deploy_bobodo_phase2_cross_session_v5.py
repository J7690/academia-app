#!/usr/bin/env python3
"""Déploiement PHASE 2 - Mémoire cross-session Bobodo."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DÉPLOIEMENT PHASE 2 – MÉMOIRE CROSS-SESSION")
print("=" * 80)

# Créer la table avec un nom plus simple
print("\n🚀 Création de la table...")
print("-" * 80)

sql_content = """
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
"""

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ Table créée avec succès")
else:
    print(f"❌ Erreur lors de la création: {r.status_code}")
    print(r.text)
    exit(1)

# Vérification
print("\n🔍 Vérification...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_memory'"}, timeout=30)

if r.status_code == 200 and r.json():
    print("✅ Table bobodo_memory vérifiée")
else:
    print("❌ Table non trouvée")
    exit(1)

# Créer les indexes
print("\n🚀 Création des indexes...")
print("-" * 80)

sql_content = """
CREATE INDEX idx_bobodo_memory_student ON app.bobodo_memory(student_id);
CREATE INDEX idx_bobodo_memory_session ON app.bobodo_memory(session_id);
CREATE INDEX idx_bobodo_memory_created_at ON app.bobodo_memory(created_at DESC);
"""

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ Indexes créés avec succès")
else:
    print(f"⚠️  Erreur lors de la création des indexes: {r.status_code}")
    print(r.text)

# Activer RLS
print("\n🚀 Activation RLS...")
print("-" * 80)

sql_content = """
ALTER TABLE app.bobodo_memory ENABLE ROW LEVEL SECURITY;
"""

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ RLS activé avec succès")
else:
    print(f"⚠️  Erreur lors de l'activation RLS: {r.status_code}")
    print(r.text)

# Créer les policies
print("\n🚀 Création des policies...")
print("-" * 80)

sql_content = """
CREATE POLICY "Students can read own memory"
    ON app.bobodo_memory
    FOR SELECT
    USING (auth.uid() = student_id);

CREATE POLICY "Service role can manage memory"
    ON app.bobodo_memory
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');
"""

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ Policies créées avec succès")
else:
    print(f"⚠️  Erreur lors de la création des policies: {r.status_code}")
    print(r.text)

# Créer les RPCs
print("\n🚀 Création des RPCs...")
print("-" * 80)

sql_content = """
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
"""

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ RPCs créées avec succès")
else:
    print(f"❌ Erreur lors de la création des RPCs: {r.status_code}")
    print(r.text)
    exit(1)

print("\n" + "=" * 80)
print("DÉPLOIEMENT PHASE 2 – TERMINÉ")
print("=" * 80)
