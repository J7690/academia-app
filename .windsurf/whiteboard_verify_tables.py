"""
Script RPC administrateur pour vérifier les tables whiteboard
Phase B.2 – Tables Execution
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

print("=== VÉRIFICATION TABLES WHITEBOARD ===\n")

# Vérifier whiteboard_projects
sql = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_projects'
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("✅ whiteboard_projects existe")
else:
    print("❌ whiteboard_projects n'existe pas")

# Vérifier whiteboard_renders
sql = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_renders'
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("✅ whiteboard_renders existe")
else:
    print("❌ whiteboard_renders n'existe pas")

print("\n=== VÉRIFICATION COLONNES WHITEBOARD_PROJECTS ===\n")

sql = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Colonnes whiteboard_projects:")
    for row in data["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
else:
    print("❌ Colonnes non trouvées")

print("\n=== VÉRIFICATION COLONNES WHITEBOARD_RENDERS ===\n")

sql = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Colonnes whiteboard_renders:")
    for row in data["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
else:
    print("❌ Colonnes non trouvées")

print("\n=== VÉRIFICATION INDEXES ===\n")

sql = """
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'app' 
AND tablename IN ('whiteboard_projects', 'whiteboard_renders')
ORDER BY tablename, indexname
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Indexes:")
    for row in data["rows"]:
        print(f"  {row['tablename']}.{row['indexname']}")
else:
    print("❌ Indexes non trouvés")

print("\n=== VÉRIFICATION CONTRAINTES ===\n")

sql = """
SELECT constraint_name, constraint_type, table_name 
FROM information_schema.table_constraints 
WHERE table_schema = 'app' 
AND table_name IN ('whiteboard_projects', 'whiteboard_renders')
ORDER BY table_name, constraint_type, constraint_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Contraintes:")
    for row in data["rows"]:
        print(f"  {row['table_name']}.{row['constraint_name']} ({row['constraint_type']})")
else:
    print("❌ Contraintes non trouvées")

print("\n=== VÉRIFICATION TRIGGERS ===\n")

sql = """
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'app' 
AND event_object_table = 'whiteboard_projects'
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Triggers:")
    for row in data["rows"]:
        print(f"  {row['event_object_table']}.{row['trigger_name']}")
else:
    print("❌ Triggers non trouvés")
