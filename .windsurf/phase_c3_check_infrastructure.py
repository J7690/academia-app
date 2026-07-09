"""
Script pour Phase C.3 – Renderer Core Implementation
Vérification de l'infrastructure existante (table whiteboard_renders, bucket whiteboard-renders)
"""

import requests
import json

# Configuration
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== PHASE C.3 – RENDERER CORE IMPLEMENTATION ===\n")
print("=== VÉRIFICATION INFRASTRUCTURE ===\n")

# Vérifier table whiteboard_renders
print("1. Vérification table whiteboard_renders")
sql_check_table = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_renders';
"""
result = execute_sql(sql_check_table)
table_exists = len(result) > 0
print(f"Table whiteboard_renders existe : {table_exists}")
print()

if table_exists:
    print("Colonnes de whiteboard_renders :")
    sql_columns = """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""
    columns = execute_sql(sql_columns)
    # La RPC admin_execute_sql retourne {ok, mode, affected_rows} pour les requêtes qui ne retournent pas de données
    # Pour obtenir les données, on doit utiliser une requête SELECT directe via REST API
    print("  Note: admin_execute_sql ne retourne pas les données de SELECT. Utilisation REST API directe...")
    
    # Utilisation REST API directe pour obtenir les colonnes
    rest_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/information_schema.columns"
    params = {
        "table_schema": "eq.app",
        "table_name": "eq.whiteboard_renders",
        "order": "ordinal_position",
        "select": "column_name,data_type,is_nullable"
    }
    resp = requests.get(rest_url, headers=headers, params=params, timeout=30)
    if resp.status_code == 200:
        columns_data = resp.json()
        for col in columns_data:
            print(f"  - {col['column_name']}: {col['data_type']} (nullable: {col['is_nullable']})")
    else:
        print(f"  Erreur REST API: {resp.status_code}")
    print()

# Vérifier bucket whiteboard-renders
print("2. Vérification bucket whiteboard-renders")
sql_check_bucket = """
SELECT name 
FROM storage.buckets 
WHERE name = 'whiteboard-renders';
"""
result = execute_sql(sql_check_bucket)
bucket_exists = len(result) > 0
print(f"Bucket whiteboard-renders existe : {bucket_exists}")
print()

print("=== FIN VÉRIFICATION ===\n")
