"""
Script RPC administrateur pour découvrir les objets whiteboard
Mission Critique – Whiteboard Object Discovery
"""

import requests
import json

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== LISTE DES SCHÉMAS ===\n")

sql = "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast', 'pg_temp') ORDER BY schema_name"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    schemas = [row['schema_name'] for row in data["rows"]]
    print("Schémas existants:")
    for schema in schemas:
        print(f"  - {schema}")
else:
    print("❌ Schémas non trouvés")
    schemas = []

print("\n=== RECHERCHE OBJETS CONTENANT 'whiteboard' ===\n")

sql = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name ILIKE '%whiteboard%'
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Tables contenant 'whiteboard':")
    whiteboard_tables = data["rows"]
    for row in whiteboard_tables:
        print(f"  {row['table_schema']}.{row['table_name']}")
else:
    print("❌ Aucune table contenant 'whiteboard'")
    whiteboard_tables = []

print("\n=== RECHERCHE OBJETS CONTENANT 'storyboard' ===\n")

sql = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name ILIKE '%storyboard%'
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Tables contenant 'storyboard':")
    storyboard_tables = data["rows"]
    for row in storyboard_tables:
        print(f"  {row['table_schema']}.{row['table_name']}")
else:
    print("❌ Aucune table contenant 'storyboard'")
    storyboard_tables = []

print("\n=== RECHERCHE RPCs CONTENANT 'whiteboard' ===\n")

sql = """
SELECT routine_schema, routine_name 
FROM information_schema.routines 
WHERE routine_name ILIKE '%whiteboard%'
AND routine_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY routine_schema, routine_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("RPCs contenant 'whiteboard':")
    whiteboard_rpcs = data["rows"]
    for row in whiteboard_rpcs:
        print(f"  {row['routine_schema']}.{row['routine_name']}")
else:
    print("❌ Aucun RPC contenant 'whiteboard'")
    whiteboard_rpcs = []

print("\n=== RECHERCHE RPCs CONTENANT 'storyboard' ===\n")

sql = """
SELECT routine_schema, routine_name 
FROM information_schema.routines 
WHERE routine_name ILIKE '%storyboard%'
AND routine_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY routine_schema, routine_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("RPCs contenant 'storyboard':")
    storyboard_rpcs = data["rows"]
    for row in storyboard_rpcs:
        print(f"  {row['routine_schema']}.{row['routine_name']}")
else:
    print("❌ Aucun RPC contenant 'storyboard'")
    storyboard_rpcs = []

print("\n=== VÉRIFICATION whiteboard_projects ET whiteboard_renders ===\n")

sql = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name IN ('whiteboard_projects', 'whiteboard_renders')
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Tables whiteboard_projects et whiteboard_renders:")
    target_tables = data["rows"]
    for row in target_tables:
        print(f"  {row['table_schema']}.{row['table_name']}")
else:
    print("❌ Tables whiteboard_projects et whiteboard_renders non trouvées")
    target_tables = []

print("\n=== DÉTAILS DES TABLES WHITEBOARD ===\n")

for table in whiteboard_tables + target_tables:
    schema = table['table_schema']
    name = table['table_name']
    
    print(f"\n--- {schema}.{name} ---\n")
    
    # Colonnes
    sql = f"""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns 
    WHERE table_schema = '{schema}' 
    AND table_name = '{name}'
    ORDER BY ordinal_position
    """
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("Colonnes:")
        for row in data["rows"]:
            print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']}, default: {row['column_default']})")
    else:
        print("❌ Colonnes non trouvées")
    
    # Contraintes
    sql = f"""
    SELECT constraint_name, constraint_type
    FROM information_schema.table_constraints 
    WHERE table_schema = '{schema}' 
    AND table_name = '{name}'
    ORDER BY constraint_type, constraint_name
    """
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("\nContraintes:")
        for row in data["rows"]:
            print(f"  {row['constraint_name']} ({row['constraint_type']})")
    else:
        print("\n❌ Contraintes non trouvées")

print("\n=== FIN DE LA DÉCOUVERTE ===\n")
