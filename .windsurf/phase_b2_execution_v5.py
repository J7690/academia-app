"""
Script RPC administrateur pour Phase B.2 – Table Creation Execution
Ordre obligatoire avec validation immédiate
Version 5 : Correction de la validation des indexes
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

def execute_sql(sql):
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== PRÉPARATION : SUPPRESSION DES TABLES EXISTANTES ===\n")

sql = "DROP TABLE IF EXISTS app.whiteboard_renders CASCADE"
result = execute_sql(sql)
print(f"DROP whiteboard_renders: {result}")

sql = "DROP TABLE IF EXISTS app.whiteboard_projects CASCADE"
result = execute_sql(sql)
print(f"DROP whiteboard_projects: {result}")

print("\n=== ÉTAPE 1 : CRÉATION whiteboard_projects ===\n")

sql = """
CREATE TABLE app.whiteboard_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('draft', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  renderer_id TEXT NOT NULL CHECK (renderer_id IN ('scientific', 'notebook')),
  theme_id TEXT NOT NULL CHECK (theme_id IN ('scientific', 'notebook')),
  narration_mode TEXT NOT NULL CHECK (narration_mode IN ('none', 'tts', 'user_recording')),
  storyboard_json JSONB NOT NULL
)
"""
result = execute_sql(sql)
print("Status:", result)
if result.get("ok"):
    print("✅ whiteboard_projects créée")
else:
    print(f"❌ Erreur: {result.get('error')}")
    exit(1)

print("\n=== ÉTAPE 2 : VALIDATION whiteboard_projects ===\n")

# Vérifier existence table via pg_tables
sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'app' AND tablename = 'whiteboard_projects'"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Table existe (pg_tables)")
else:
    print("❌ Table n'existe pas (pg_tables)")
    exit(1)

# Vérifier colonnes via information_schema.columns
sql = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Colonnes trouvées (information_schema):")
    for row in result["rows"]:
        print(f"  {row['column_name']}: {row['data_type']}")
else:
    print("❌ Colonnes non trouvées (information_schema)")
    exit(1)

# Vérifier contraintes via information_schema.table_constraints
sql = """
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_schema = 'app' AND table_name = 'whiteboard_projects'
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Contraintes trouvées (information_schema):")
    for row in result["rows"]:
        print(f"  {row['constraint_name']} ({row['constraint_type']})")
else:
    print("❌ Contraintes non trouvées (information_schema)")
    exit(1)

print("\n=== ÉTAPE 3 : CRÉATION INDEXES whiteboard_projects ===\n")

indexes = [
    "CREATE INDEX idx_whiteboard_projects_id ON app.whiteboard_projects(id)",
    "CREATE INDEX idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id)",
    "CREATE INDEX idx_whiteboard_projects_status ON app.whiteboard_projects(status)",
    "CREATE INDEX idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at)",
    "CREATE INDEX idx_whiteboard_projects_storyboard_json ON app.whiteboard_projects USING GIN (storyboard_json)"
]

for idx_sql in indexes:
    result = execute_sql(idx_sql)
    if result.get("ok"):
        print(f"✅ Index créé: {idx_sql.split('idx_')[1].split(' ')[0]}")
    else:
        print(f"❌ Erreur index: {result.get('error')}")
        exit(1)

print("\n=== ÉTAPE 4 : VALIDATION INDEXES whiteboard_projects ===\n")

# Vérifier indexes via pg_class et pg_index
sql = """
SELECT c.relname as indexname
FROM pg_index i
JOIN pg_class c ON i.indexrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_class t ON i.indrelid = t.oid
JOIN pg_namespace tn ON t.relnamespace = tn.oid
WHERE tn.nspname = 'app' 
AND t.relname = 'whiteboard_projects'
AND n.nspname = 'app'
ORDER BY c.relname
"""
result = execute_sql(sql)
if result.get("ok") and (result.get("rows") or result.get("affected_rows", 0) > 0):
    print("✅ Indexes trouvés (pg_index):")
    rows = result.get("rows", [])
    if not rows:
        sql = """
        SELECT c.relname as indexname
        FROM pg_index i
        JOIN pg_class c ON i.indexrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        JOIN pg_class t ON i.indrelid = t.oid
        JOIN pg_namespace tn ON t.relnamespace = tn.oid
        WHERE tn.nspname = 'app' 
        AND t.relname = 'whiteboard_projects'
        AND n.nspname = 'app'
        ORDER BY c.relname
        """
        result = execute_sql(sql)
        rows = result.get("rows", [])
    for row in rows:
        print(f"  {row['indexname']}")
else:
    print("❌ Indexes non trouvés (pg_index)")
    exit(1)

print("\n=== ÉTAPE 5 : CRÉATION whiteboard_renders ===\n")

sql = """
CREATE TABLE app.whiteboard_renders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES app.whiteboard_projects(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('queued', 'processing', 'done', 'failed')),
  video_url TEXT,
  duration_ms INTEGER,
  error_message TEXT,
  progress INTEGER CHECK (progress >= 0 AND progress <= 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
)
"""
result = execute_sql(sql)
print("Status:", result)
if result.get("ok"):
    print("✅ whiteboard_renders créée")
else:
    print(f"❌ Erreur: {result.get('error')}")
    exit(1)

print("\n=== ÉTAPE 6 : VALIDATION whiteboard_renders ===\n")

# Vérifier existence table via pg_tables
sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'app' AND tablename = 'whiteboard_renders'"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Table existe (pg_tables)")
else:
    print("❌ Table n'existe pas (pg_tables)")
    exit(1)

# Vérifier colonnes via information_schema.columns
sql = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Colonnes trouvées (information_schema):")
    for row in result["rows"]:
        print(f"  {row['column_name']}: {row['data_type']}")
else:
    print("❌ Colonnes non trouvées (information_schema)")
    exit(1)

# Vérifier contraintes via information_schema.table_constraints
sql = """
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Contraintes trouvées (information_schema):")
    for row in result["rows"]:
        print(f"  {row['constraint_name']} ({row['constraint_type']})")
else:
    print("❌ Contraintes non trouvées (information_schema)")
    exit(1)

print("\n=== ÉTAPE 7 : CRÉATION INDEXES whiteboard_renders ===\n")

indexes = [
    "CREATE INDEX idx_whiteboard_renders_id ON app.whiteboard_renders(id)",
    "CREATE INDEX idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id)",
    "CREATE INDEX idx_whiteboard_renders_status ON app.whiteboard_renders(status)",
    "CREATE INDEX idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at)"
]

for idx_sql in indexes:
    result = execute_sql(idx_sql)
    if result.get("ok"):
        print(f"✅ Index créé: {idx_sql.split('idx_')[1].split(' ')[0]}")
    else:
        print(f"❌ Erreur index: {result.get('error')}")
        exit(1)

print("\n=== ÉTAPE 8 : VALIDATION INDEXES whiteboard_renders ===\n")

# Vérifier indexes via pg_class et pg_index
sql = """
SELECT c.relname as indexname
FROM pg_index i
JOIN pg_class c ON i.indexrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_class t ON i.indrelid = t.oid
JOIN pg_namespace tn ON t.relnamespace = tn.oid
WHERE tn.nspname = 'app' 
AND t.relname = 'whiteboard_renders'
AND n.nspname = 'app'
ORDER BY c.relname
"""
result = execute_sql(sql)
if result.get("ok") and (result.get("rows") or result.get("affected_rows", 0) > 0):
    print("✅ Indexes trouvés (pg_index):")
    rows = result.get("rows", [])
    if not rows:
        sql = """
        SELECT c.relname as indexname
        FROM pg_index i
        JOIN pg_class c ON i.indexrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        JOIN pg_class t ON i.indrelid = t.oid
        JOIN pg_namespace tn ON t.relnamespace = tn.oid
        WHERE tn.nspname = 'app' 
        AND t.relname = 'whiteboard_renders'
        AND n.nspname = 'app'
        ORDER BY c.relname
        """
        result = execute_sql(sql)
        rows = result.get("rows", [])
    for row in rows:
        print(f"  {row['indexname']}")
else:
    print("❌ Indexes non trouvés (pg_index)")
    exit(1)

print("\n=== VALIDATION FINALE ===\n")

sql = """
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'app' 
AND tablename IN ('whiteboard_projects', 'whiteboard_renders')
ORDER BY tablename
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print("✅ Tables créées:")
    for row in result["rows"]:
        print(f"  {row['schemaname']}.{row['tablename']}")
else:
    print("❌ Tables non trouvées")
    exit(1)

print("\n=== CRÉATION TERMINÉE AVEC SUCCÈS ===\n")
