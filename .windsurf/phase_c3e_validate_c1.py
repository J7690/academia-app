"""
Phase C.3E – Lot 1 – Validation C1
Valider CHECK status après correction
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== VALIDATION C1 : CHECK STATUS ===\n")

# Créer un project valide
project_id = str(uuid.uuid4())
student_id = "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"
sql = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Test', 'completed', 'scientific', 'scientific', 'none', '{{"test": true}}');
"""
result = execute_sql(sql)
print(f"Création project : {result}")

# Test 1 : INSERT queued
render_id_queued = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_queued}', '{project_id}', 'queued');
"""
result = execute_sql(sql)
print(f"Test 1 INSERT queued : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Test 2 : INSERT processing
render_id_processing = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_processing}', '{project_id}', 'processing');
"""
result = execute_sql(sql)
print(f"Test 2 INSERT processing : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Test 3 : INSERT done
render_id_done = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_done}', '{project_id}', 'done');
"""
result = execute_sql(sql)
print(f"Test 3 INSERT done : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Test 4 : INSERT failed
render_id_failed = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id_failed}', '{project_id}', 'failed');
"""
result = execute_sql(sql)
print(f"Test 4 INSERT failed : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Nettoyage
sql = f"DELETE FROM app.whiteboard_renders WHERE id IN ('{render_id_queued}', '{render_id_processing}', '{render_id_done}', '{render_id_failed}')"
result = execute_sql(sql)
print(f"Nettoyage renders : {result}")

sql = f"DELETE FROM app.whiteboard_projects WHERE id = '{project_id}'"
result = execute_sql(sql)
print(f"Nettoyage project : {result}")

print("\n=== VALIDATION C1 TERMINÉE - SUCCÈS ===\n")
