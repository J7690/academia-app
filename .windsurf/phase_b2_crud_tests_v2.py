"""
Script RPC administrateur pour Phase B.2 – Tests CRUD
Version 2 : Avec création d'étudiant de test
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

print("=== PRÉPARATION : CRÉATION ÉTUDIANT DE TEST ===\n")

sql = """
INSERT INTO app.students (id, email, first_name, last_name)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'test_whiteboard@academia.test',
  'Test',
  'Whiteboard'
)
ON CONFLICT (id) DO NOTHING
"""
result = execute_sql(sql)
print(f"INSERT student: {result}")
if result.get("ok"):
    print("✅ Étudiant de test créé")
else:
    print(f"❌ Erreur création étudiant: {result.get('error')}")

student_id = '00000000-0000-0000-0000-000000000001'

print("\n=== TESTS CRUD whiteboard_projects ===\n")

# INSERT
print("TEST 1: INSERT whiteboard_projects")
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
  'Test Subject',
  'draft',
  'scientific',
  'scientific',
  'none',
  '{{"version": "1.0", "scenes": []}}'::JSONB
)
"""
result = execute_sql(sql)
print(f"INSERT: {result}")
if result.get("ok"):
    print("✅ INSERT réussi")
else:
    print(f"❌ INSERT échoué: {result.get('error')}")

# SELECT
print("\nTEST 2: SELECT whiteboard_projects")
sql = "SELECT * FROM app.whiteboard_projects LIMIT 1"
result = execute_sql(sql)
print(f"SELECT: {result}")
if result.get("ok") and result.get("rows"):
    print("✅ SELECT réussi")
    project_id = result["rows"][0]["id"]
    print(f"  ID: {project_id}")
else:
    print("❌ SELECT échoué")
    project_id = None

# UPDATE
print("\nTEST 3: UPDATE whiteboard_projects")
if project_id:
    sql = f"UPDATE app.whiteboard_projects SET status = 'completed' WHERE id = '{project_id}'"
    result = execute_sql(sql)
    print(f"UPDATE: {result}")
    if result.get("ok"):
        print("✅ UPDATE réussi")
    else:
        print(f"❌ UPDATE échoué: {result.get('error')}")
else:
    print("❌ UPDATE ignoré (pas d'ID)")

# DELETE
print("\nTEST 4: DELETE whiteboard_projects")
if project_id:
    sql = f"DELETE FROM app.whiteboard_projects WHERE id = '{project_id}'"
    result = execute_sql(sql)
    print(f"DELETE: {result}")
    if result.get("ok"):
        print("✅ DELETE réussi")
    else:
        print(f"❌ DELETE échoué: {result.get('error')}")
else:
    print("❌ DELETE ignoré (pas d'ID)")

print("\n=== TESTS CRUD whiteboard_renders ===\n")

# D'abord créer un projet pour le FK
print("PRÉPARATION: Création projet pour FK")
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
  'Test Subject for Rend',
  'draft',
  'scientific',
  'scientific',
  'none',
  '{{"version": "1.0", "scenes": []}}'::JSONB
) RETURNING id
"""
result = execute_sql(sql)
print(f"INSERT project: {result}")
if result.get("ok") and result.get("rows"):
    project_id = result["rows"][0]["id"]
    print(f"✅ Projet créé avec ID: {project_id}")
else:
    print("❌ Impossible de créer le projet")
    project_id = None

# INSERT whiteboard_renders
print("\nTEST 5: INSERT whiteboard_renders")
if project_id:
    sql = f"""
    INSERT INTO app.whiteboard_renders (
      project_id,
      status
    ) VALUES (
      '{project_id}',
      'queued'
    )
    """
    result = execute_sql(sql)
    print(f"INSERT: {result}")
    if result.get("ok"):
        print("✅ INSERT réussi")
    else:
        print(f"❌ INSERT échoué: {result.get('error')}")
else:
    print("❌ INSERT ignoré (pas d'ID projet)")

# SELECT whiteboard_renders
print("\nTEST 6: SELECT whiteboard_renders")
sql = "SELECT * FROM app.whiteboard_renders LIMIT 1"
result = execute_sql(sql)
print(f"SELECT: {result}")
if result.get("ok") and result.get("rows"):
    print("✅ SELECT réussi")
    render_id = result["rows"][0]["id"]
    print(f"  ID: {render_id}")
else:
    print("❌ SELECT échoué")
    render_id = None

# UPDATE whiteboard_renders
print("\nTEST 7: UPDATE whiteboard_renders")
if render_id:
    sql = f"UPDATE app.whiteboard_renders SET status = 'processing' WHERE id = '{render_id}'"
    result = execute_sql(sql)
    print(f"UPDATE: {result}")
    if result.get("ok"):
        print("✅ UPDATE réussi")
    else:
        print(f"❌ UPDATE échoué: {result.get('error')}")
else:
    print("❌ UPDATE ignoré (pas d'ID)")

# DELETE whiteboard_renders
print("\nTEST 8: DELETE whiteboard_renders")
if render_id:
    sql = f"DELETE FROM app.whiteboard_renders WHERE id = '{render_id}'"
    result = execute_sql(sql)
    print(f"DELETE: {result}")
    if result.get("ok"):
        print("✅ DELETE réussi")
    else:
        print(f"❌ DELETE échoué: {result.get('error')}")
else:
    print("❌ DELETE ignoré (pas d'ID)")

# Nettoyage
print("\n=== NETTOYAGE ===\n")
if project_id:
    sql = f"DELETE FROM app.whiteboard_projects WHERE id = '{project_id}'"
    result = execute_sql(sql)
    print(f"DELETE project: {result}")

print("\n=== TESTS CRUD TERMINÉS ===\n")
