"""
Script RPC administrateur pour Phase B.2 – Post Execution Audit
Version 2 : Utilisation de pg_tables, pg_attribute, pg_constraint
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

print("=== PARTIE 1 – STRUCTURE RÉELLE ===\n")

print("--- app.whiteboard_projects ---\n")
sql = """
SELECT a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type, a.attnotnull as not_null
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'app' 
AND c.relname = 'whiteboard_projects'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum
"""
result = execute_sql(sql)
if result.get("ok") and (result.get("rows") or result.get("affected_rows", 0) > 0):
    rows = result.get("rows", [])
    if not rows:
        # Refaire avec SELECT explicite
        sql = """
        SELECT a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type, a.attnotnull as not_null
        FROM pg_attribute a
        JOIN pg_class c ON a.attrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'app' 
        AND c.relname = 'whiteboard_projects'
        AND a.attnum > 0
        AND NOT a.attisdropped
        ORDER BY a.attnum
        """
        result = execute_sql(sql)
        rows = result.get("rows", [])
    print("Colonnes:")
    for row in rows:
        print(f"  {row['column_name']}: {row['data_type']} (not_null: {row['not_null']})")
else:
    print("❌ Colonnes non trouvées")

print("\n--- app.whiteboard_renders ---\n")
sql = """
SELECT a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type, a.attnotnull as not_null
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'app' 
AND c.relname = 'whiteboard_renders'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum
"""
result = execute_sql(sql)
if result.get("ok") and (result.get("rows") or result.get("affected_rows", 0) > 0):
    rows = result.get("rows", [])
    if not rows:
        sql = """
        SELECT a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type, a.attnotnull as not_null
        FROM pg_attribute a
        JOIN pg_class c ON a.attrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'app' 
        AND c.relname = 'whiteboard_renders'
        AND a.attnum > 0
        AND NOT a.attisdropped
        ORDER BY a.attnum
        """
        result = execute_sql(sql)
        rows = result.get("rows", [])
    print("Colonnes:")
    for row in rows:
        print(f"  {row['column_name']}: {row['data_type']} (not_null: {row['not_null']})")
else:
    print("❌ Colonnes non trouvées")

print("\n=== PARTIE 2 – CONTRAINTES ===\n")

print("--- app.whiteboard_projects ---\n")
sql = """
SELECT conname as constraint_name, contype as constraint_type
FROM pg_constraint con
JOIN pg_class c ON con.conrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'app' 
AND c.relname = 'whiteboard_projects'
ORDER BY conname
"""
result = execute_sql(sql)
if result.get("ok") and (result.get("rows") or result.get("affected_rows", 0) > 0):
    rows = result.get("rows", [])
    if not rows:
        sql = """
        SELECT conname as constraint_name, contype as constraint_type
        FROM pg_constraint con
        JOIN pg_class c ON con.conrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'app' 
        AND c.relname = 'whiteboard_projects'
        ORDER BY conname
        """
        result = execute_sql(sql)
        rows = result.get("rows", [])
    print("Contraintes:")
    for row in rows:
        print(f"  {row['constraint_name']} ({row['constraint_type']})")
else:
    print("❌ Contraintes non trouvées")

print("\n--- app.whiteboard_renders ---\n")
sql = """
SELECT conname as constraint_name, contype as constraint_type
FROM pg_constraint con
JOIN pg_class c ON con.conrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'app' 
AND c.relname = 'whiteboard_renders'
ORDER BY conname
"""
result = execute_sql(sql)
if result.get("ok") and (result.get("rows") or result.get("affected_rows", 0) > 0):
    rows = result.get("rows", [])
    if not rows:
        sql = """
        SELECT conname as constraint_name, contype as constraint_type
        FROM pg_constraint con
        JOIN pg_class c ON con.conrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'app' 
        AND c.relname = 'whiteboard_renders'
        ORDER BY conname
        """
        result = execute_sql(sql)
        rows = result.get("rows", [])
    print("Contraintes:")
    for row in rows:
        print(f"  {row['constraint_name']} ({row['constraint_type']})")
else:
    print("❌ Contraintes non trouvées")

print("\n=== PARTIE 3 – INDEXES ===\n")

print("--- app.whiteboard_projects ---\n")
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
    print("Indexes:")
    for row in rows:
        print(f"  {row['indexname']}")
else:
    print("❌ Indexes non trouvés")

print("\n--- app.whiteboard_renders ---\n")
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
    print("Indexes:")
    for row in rows:
        print(f"  {row['indexname']}")
else:
    print("❌ Indexes non trouvés")

print("\n=== PARTIE 5 – TEST JSONB ===\n")

student_id = 'c63e9c1e-92d9-43f3-ab41-066ec3dc788b'

print("TEST: Insertion storyboard réel")
sql = f"""
INSERT INTO app.whiteboard_projects (
  student_id,
  subject,
  status,
  renderer_id,
  theme_id,
  narration_mode,
  storyboard_json
) VALUES (
  '{student_id}',
  'Test JSONB',
  'draft',
  'scientific',
  'scientific',
  'none',
  '{{"version": "1.0", "scenes": [{{"id": "scene1", "blocks": []}}]}}'::JSONB
) RETURNING id
"""
result = execute_sql(sql)
print(f"INSERT: {result}")
if result.get("ok"):
    if result.get("rows"):
        project_id = result["rows"][0]["id"]
        print(f"✅ Projet créé avec ID: {project_id}")
    else:
        sql = f"SELECT id FROM app.whiteboard_projects WHERE student_id = '{student_id}' ORDER BY created_at DESC LIMIT 1"
        result = execute_sql(sql)
        if result.get("ok") and result.get("rows"):
            project_id = result["rows"][0]["id"]
            print(f"✅ Projet récupéré avec ID: {project_id}")
else:
    print("❌ Erreur insertion")
    project_id = None

print("\nTEST: Lecture storyboard réel")
if project_id:
    sql = f"SELECT storyboard_json FROM app.whiteboard_projects WHERE id = '{project_id}'"
    result = execute_sql(sql)
    print(f"SELECT: {result}")
    if result.get("ok") and result.get("rows"):
        print(f"✅ Storyboard lu: {result['rows'][0]['storyboard_json']}")
    else:
        print("❌ Erreur lecture")

print("\nTEST: Mise à jour storyboard réel")
if project_id:
    sql = f"""
    UPDATE app.whiteboard_projects 
    SET storyboard_json = '{{"version": "1.0", "scenes": [{{"id": "scene1", "blocks": []}}, {{"id": "scene2", "blocks": []}}]}}'::JSONB 
    WHERE id = '{project_id}'
    """
    result = execute_sql(sql)
    print(f"UPDATE: {result}")
    if result.get("ok"):
        print("✅ Storyboard mis à jour")
    else:
        print("❌ Erreur mise à jour")

print("\n=== PARTIE 6 – TEST FK ===\n")

print("TEST: FK student_id")
sql = f"""
INSERT INTO app.whiteboard_projects (
  student_id,
  subject,
  status,
  renderer_id,
  theme_id,
  narration_mode,
  storyboard_json
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'Test FK',
  'draft',
  'scientific',
  'scientific',
  'none',
  '{{"version": "1.0", "scenes": []}}'::JSONB
)
"""
result = execute_sql(sql)
print(f"INSERT FK invalide: {result}")
if result.get("ok"):
    print("❌ FK student_id non fonctionnelle")
else:
    print("✅ FK student_id fonctionnelle (erreur attendue)")

print("\nTEST: FK project_id")
if project_id:
    sql = f"""
    INSERT INTO app.whiteboard_renders (
      project_id,
      status
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      'queued'
    )
    """
    result = execute_sql(sql)
    print(f"INSERT FK invalide: {result}")
    if result.get("ok"):
        print("❌ FK project_id non fonctionnelle")
    else:
        print("✅ FK project_id fonctionnelle (erreur attendue)")

print("\n=== PARTIE 7 – NON-RÉGRESSION ===\n")

print("Vérification tables Challenge")
sql = """
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'app' 
AND tablename LIKE 'challenge_%'
ORDER BY tablename
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print(f"✅ Tables Challenge existantes: {len(result['rows'])}")
else:
    print("❌ Erreur vérification tables Challenge")

print("\nVérification RPCs Challenge")
sql = """
SELECT routine_name 
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'app' 
AND p.proname LIKE 'challenge_%'
ORDER BY p.proname
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    print(f"✅ RPCs Challenge existants: {len(result['rows'])}")
else:
    print("❌ Erreur vérification RPCs Challenge")

print("\n=== NETTOYAGE ===\n")
if project_id:
    sql = f"DELETE FROM app.whiteboard_projects WHERE id = '{project_id}'"
    result = execute_sql(sql)
    print(f"DELETE project: {result}")

print("\n=== AUDIT TERMINÉ ===\n")
