"""
Script pour Phase C.3 – Renderer Core Implementation
Récupération de la structure de la table whiteboard_renders via RPC
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
print("=== STRUCTURE TABLE whiteboard_renders ===\n")

# Récupérer la structure de la table
sql_structure = """
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""

result = execute_sql(sql_structure)
print(f"Résultat : {result}")
print()

# Si la RPC ne retourne pas les données, on utilise une autre approche
if not result or isinstance(result, dict) and result.get('affected_rows', 0) == 0:
    print("La RPC ne retourne pas les données. Utilisation d'une autre approche...")
    
    # On va créer une table temporaire pour stocker le résultat
    sql_temp = """
    DROP TABLE IF EXISTS _temp_whiteboard_columns;
    CREATE TEMP TABLE _temp_whiteboard_columns AS
    SELECT 
        column_name,
        data_type,
        is_nullable,
        column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'whiteboard_renders'
    ORDER BY ordinal_position;
    
    SELECT * FROM _temp_whiteboard_columns;
    """
    
    result = execute_sql(sql_temp)
    print(f"Résultat avec table temporaire : {result}")
    print()

print("=== FIN ===\n")
