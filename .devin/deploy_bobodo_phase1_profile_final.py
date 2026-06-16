#!/usr/bin/env python3
"""Déploiement PHASE 1 - Injection profil étudiant dans prompt Bobodo."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DÉPLOIEMENT PHASE 1 – INJECTION PROFIL ÉTUDIANT")
print("=" * 80)

# Créer la RPC avec un nom sans préfixe app_ (pour éviter les problèmes de cache)
print("\n🚀 Création de la RPC...")
print("-" * 80)

sql_content = """
DROP FUNCTION IF EXISTS app.bobodo_student_profile(UUID);

CREATE OR REPLACE FUNCTION app.bobodo_student_profile(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile JSONB;
    v_first_name TEXT;
    v_full_name TEXT;
BEGIN
    -- Récupérer le nom complet
    SELECT st.full_name INTO v_full_name
    FROM app.bobodo_sessions bs
    JOIN app.students st ON st.id = bs.student_id
    WHERE bs.id = p_session_id;
    
    -- Extraire le prénom (premier mot)
    v_first_name := NULLIF(TRIM(split_part(COALESCE(v_full_name, ''), ' ', 1)), '');
    
    -- Construire le profil JSON
    SELECT JSONB_BUILD_OBJECT(
        'first_name', v_first_name,
        'full_name', v_full_name,
        'bac_series', st.bac_series,
        'bac_year', st.bac_year,
        'bac_mention', st.bac_mention,
        'bac_institution', st.bac_institution,
        'bac_country', st.bac_country,
        'bepc_year', st.bepc_year,
        'bepc_mention', st.bepc_mention,
        'bepc_institution', st.bepc_institution,
        'bepc_country', st.bepc_country,
        'study_project', st.study_project_text,
        'country', st.country,
        'city', st.city,
        'bio', st.bio,
        'applications', (
            SELECT COALESCE(
                JSONB_AGG(
                    JSONB_BUILD_OBJECT(
                        'program_id', a.program_id,
                        'status', a.status,
                        'created_at', a.created_at
                    )
                ),
                '[]'::JSONB
            )
            FROM app.applications a
            WHERE a.student_id = st.id
            ORDER BY a.created_at DESC
            LIMIT 5
        )
    ) INTO v_profile
    FROM app.bobodo_sessions bs
    JOIN app.students st ON st.id = bs.student_id
    WHERE bs.id = p_session_id;
    
    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION app.bobodo_student_profile(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION app.bobodo_student_profile(UUID) TO authenticated;
"""

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ RPC créée avec succès")
else:
    print(f"❌ Erreur lors de la création: {r.status_code}")
    print(r.text)
    exit(1)

# Vérifier dans pg_proc
print("\n🔍 Vérification dans pg_proc...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT p.proname, n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE p.proname = 'bobodo_student_profile' AND n.nspname = 'app'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ RPC trouvée: {results[0]['nspname']}.{results[0]['proname']}")
    else:
        print("❌ RPC non trouvée")
        exit(1)
else:
    print("❌ Erreur lors de la vérification")
    print(r.text)
    exit(1)

# Tester la RPC via SQL direct
print("\n🧪 Test via SQL direct...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT id FROM app.bobodo_sessions LIMIT 1"}, timeout=30)

if r.status_code == 200 and r.json():
    session_id = r.json()[0]['id']
    print(f"Session ID: {session_id}")
    
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT app.bobodo_student_profile('{session_id}') as profile"}, timeout=30)
    
    if r.status_code == 200:
        results = r.json()
        if results:
            print("✅ RPC fonctionne via SQL direct")
            print(f"Profil: {json.dumps(results[0], indent=2, ensure_ascii=False)}")
        else:
            print("❌ RPC retourne vide")
    else:
        print(f"❌ Erreur: {r.status_code}")
        print(r.text)
else:
    print("⚠️  Aucune session pour tester")

print("\n" + "=" * 80)
print("DÉPLOIEMENT PHASE 1 – TERMINÉ")
print("=" * 80)
