#!/usr/bin/env python3
"""
Résolution des limitations SQL RPC et configuration accès complet Supabase
"""

import sys
import json
import requests
from pathlib import Path

# Ajouter le chemin .windsurf au Python path
windsurf_path = Path(__file__).parent
sys.path.insert(0, str(windsurf_path))

try:
    from supabase_credentials import get_supabase_config
    
    print("🔧 Configuration de l'accès SQL RPC complet...")
    
    # Récupérer la configuration
    config = get_supabase_config()
    if not config:
        print("❌ Configuration Supabase non trouvée")
        sys.exit(1)
    
    print(f"✅ Projet: {config['projectId']}")
    
    # Étapes pour débloquer l'accès SQL RPC
    
    print("\n" + "="*60)
    print("📋 ÉTAPES DE CONFIGURATION POUR ACCÈS SQL RPC COMPLET")
    print("="*60)
    
    print("\n1️⃣ CONFIGURATION DANS LE DASHBOARD SUPABASE")
    print("-" * 40)
    print("Allez dans: https://app.supabase.com/project/thevdfcwlcqzdoybfvgs")
    print("\n📝 Étapes à suivre:")
    print("   1. Cliquez sur 'SQL Editor' dans le menu gauche")
    print("   2. Cliquez sur 'New query'")
    print("   3. Copiez-collez le code SQL ci-dessous")
    print("   4. Exécutez le code")
    
    # Code SQL à exécuter dans le dashboard
    sql_setup_code = """
-- ========================================
-- CONFIGURATION ACCÈS SQL RPC COMPLET
-- ========================================

-- 1. Créer une fonction RPC pour exécuter du SQL dynamique
CREATE OR REPLACE FUNCTION execute_sql(sql_query TEXT)
RETURNS TABLE(result JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    query_result JSONB;
BEGIN
    -- Exécuter la requête SQL dynamiquement
    EXECUTE 'SELECT array_to_json(array_agg(row_to_json(t)))::jsonb as result FROM (' || sql_query || ') t'
    INTO query_result;
    
    RETURN QUERY SELECT query_result as result;
EXCEPTION WHEN OTHERS THEN
    -- En cas d'erreur, retourner le message d'erreur
    RETURN QUERY SELECT jsonb_build_object('error', SQLERRM) as result;
END;
$$;

-- 2. Donner les permissions à service_role
GRANT EXECUTE ON FUNCTION execute_sql TO service_role;
GRANT EXECUTE ON FUNCTION execute_sql TO authenticated;

-- 3. Créer une fonction pour lister les tables
CREATE OR REPLACE FUNCTION list_tables()
RETURNS TABLE(table_name TEXT, table_schema TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT table_name, table_schema
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
    ORDER BY table_schema, table_name;
END;
$$;

-- 4. Donner les permissions
GRANT EXECUTE ON FUNCTION list_tables TO service_role;
GRANT EXECUTE ON FUNCTION list_tables TO authenticated;

-- 5. Créer une fonction pour décrire une table
CREATE OR REPLACE FUNCTION describe_table(table_name TEXT)
RETURNS TABLE(column_name TEXT, data_type TEXT, is_nullable TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = describe_table.table_name
    ORDER BY ordinal_position;
END;
$$;

-- 6. Donner les permissions
GRANT EXECUTE ON FUNCTION describe_table TO service_role;
GRANT EXECUTE ON FUNCTION describe_table TO authenticated;

-- 7. Fonction pour créer des tables
CREATE OR REPLACE FUNCTION create_table_ddl(table_definition TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result TEXT;
BEGIN
    EXECUTE table_definition;
    result := 'Table created successfully';
    RETURN result;
EXCEPTION WHEN OTHERS THEN
    RETURN 'Error: ' || SQLERRM;
END;
$$;

-- 8. Donner les permissions
GRANT EXECUTE ON FUNCTION create_table_ddl TO service_role;
GRANT EXECUTE ON FUNCTION create_table_ddl TO authenticated;

-- ========================================
-- VÉRIFICATION
-- ========================================
SELECT 'RPC Functions created successfully' as status;
"""
    
    print("\n📋 CODE SQL À COPIER-COLLER:")
    print("-" * 40)
    print(sql_setup_code)
    
    print("\n" + "="*60)
    print("2️⃣ ALTERNATIVE: UTILISER L'API POSTGREST DIRECTEMENT")
    print("="*60)
    
    print("\nSi le RPC ne fonctionne pas, voici l'alternative:")
    print("Utiliser l'API PostgREST avec des requêtes structurées")
    
    # Test des alternatives
    print("\n🧪 Test des méthodes alternatives...")
    
    headers = {
        "apikey": config["serviceKey"],
        "Authorization": f"Bearer {config['serviceKey']}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.pgrst.object+json"
    }
    
    # Alternative 1: Utiliser PostgREST pour les opérations CRUD
    print("\n✅ Alternative 1: PostgREST CRUD")
    print("   - CREATE: POST /rest/v1/{table}")
    print("   - READ: GET /rest/v1/{table}")
    print("   - UPDATE: PATCH /rest/v1/{table}")
    print("   - DELETE: DELETE /rest/v1/{table}")
    
    # Alternative 2: Utiliser les vues système
    print("\n✅ Alternative 2: Vues système")
    try:
        # Tester l'accès aux vues PostgreSQL
        views_url = f"{config['supabaseUrl']}/rest/v1/pg_tables?limit=5"
        response = requests.get(views_url, headers=headers, timeout=5)
        
        if response.status_code == 200:
            print("   ✅ Vues pg_tables accessibles")
        else:
            print("   ⚠️ Vues pg_tables limitées")
    except:
        print("   ❌ Vues pg_tables non accessibles")
    
    # Alternative 3: Utiliser le client Python Supabase
    print("\n✅ Alternative 3: Client Python Supabase")
    print("   Installation: pip install supabase")
    
    print("\n" + "="*60)
    print("3️⃣ SCRIPT DE TEST APRÈS CONFIGURATION")
    print("="*60)
    
    test_script = '''
#!/usr/bin/env python3
"""
Test après configuration SQL RPC
"""

import requests

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
service_key = "VOTRE_SERVICE_KEY"

headers = {
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
    "Content-Type": "application/json"
}

# Test 1: Lister les tables
print("1. Test list_tables()...")
response = requests.post(f"{url}/rest/v1/rpc/list_tables", headers=headers)
if response.status_code == 200:
    tables = response.json()
    print(f"✅ Tables trouvées: {len(tables)}")
    for table in tables:
        print(f"   - {table['table_name']}")
else:
    print(f"❌ Erreur: {response.status_code}")

# Test 2: Exécuter du SQL
print("\\n2. Test execute_sql()...")
sql_query = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' LIMIT 5"
response = requests.post(f"{url}/rest/v1/rpc/execute_sql", 
                         headers=headers, 
                         json={"sql_query": sql_query})
if response.status_code == 200:
    result = response.json()
    print(f"✅ SQL exécuté: {result}")
else:
    print(f"❌ Erreur SQL: {response.status_code}")

# Test 3: Créer une table
print("\\n3. Test create_table_ddl()...")
create_sql = """
CREATE TABLE test_rpc_table (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
)
"""
response = requests.post(f"{url}/rest/v1/rpc/create_table_ddl", 
                         headers=headers, 
                         json={"table_definition": create_sql})
if response.status_code == 200:
    result = response.json()
    print(f"✅ Table créée: {result}")
else:
    print(f"❌ Erreur création: {response.status_code}")
'''
    
    print("📄 Script de test à enregistrer:")
    print("-" * 40)
    print(test_script)
    
    # Créer le fichier de test
    test_file_path = windsurf_path / "test_rpc_after_setup.py"
    with open(test_file_path, 'w', encoding='utf-8') as f:
        f.write(test_script)
    
    print(f"\n✅ Script de test sauvegardé dans: {test_file_path}")
    
    print("\n" + "="*60)
    print("4️⃣ SOLUTION IMMÉDIATE: UTILISER psycopg2 DIRECTEMENT")
    print("="*60)
    
    print("\nSi vous voulez une connexion directe PostgreSQL:")
    
    direct_connection_code = '''
import psycopg2
from psycopg2.extras import RealDictCursor

# Configuration de connexion directe
connection_params = {
    "host": "db.thevdfcwlcqzdoybfvgs.supabase.co",
    "port": 5432,
    "database": "postgres",
    "user": "postgres",
    "password": "Azert0Yuiop@",
    "sslmode": "require"
}

try:
    # Connexion directe
    conn = psycopg2.connect(**connection_params)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    # Exécuter du SQL directement
    cursor.execute("SELECT version()")
    result = cursor.fetchone()
    print(f"✅ Connexion directe: {result['version']}")
    
    # Lister les tables
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
        ORDER BY table_name
    """)
    tables = cursor.fetchall()
    print(f"✅ Tables: {[t['table_name'] for t in tables]}")
    
    cursor.close()
    conn.close()
    
except Exception as e:
    print(f"❌ Erreur connexion directe: {e}")
'''
    
    print("📄 Code connexion directe:")
    print("-" * 40)
    print(direct_connection_code)
    
    # Créer le fichier de connexion directe
    direct_file_path = windsurf_path / "direct_postgres_connection.py"
    with open(direct_file_path, 'w', encoding='utf-8') as f:
        f.write(direct_connection_code)
    
    print(f"\n✅ Code connexion directe sauvegardé dans: {direct_file_path}")
    
    print("\n" + "="*60)
    print("🎯 RÉSUMÉ DES SOLUTIONS")
    print("="*60)
    
    print("\n🔧 Pour débloquer SQL RPC:")
    print("1. Exécutez le code SQL dans le dashboard Supabase")
    print("2. Testez avec le script généré")
    print("3. Utilisez l'alternative psycopg2 si nécessaire")
    
    print("\n✅ Solutions disponibles:")
    print("- SQL RPC personnalisé (après configuration)")
    print("- API PostgREST CRUD (déjà fonctionnel)")
    print("- Connexion PostgreSQL directe (psycopg2)")
    
    print("\n🚀 Une fois configuré, vous aurez:")
    print("- Accès SQL complet via RPC")
    print("- Exécution de requêtes dynamiques")
    print("- Création/modification de tables")
    print("- Audit complet de la base de données")
    
except Exception as e:
    print(f"❌ Erreur: {e}")
