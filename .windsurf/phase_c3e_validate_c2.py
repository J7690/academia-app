"""
Phase C.3E – Lot 1 – Validation C2
Valider export_settings après correction
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

print("=== VALIDATION C2 : EXPORT_SETTINGS ===\n")

# Créer un project valide
project_id = str(uuid.uuid4())
student_id = "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"
sql = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Test', 'completed', 'scientific', 'scientific', 'none', '{{"test": true}}');
"""
result = execute_sql(sql)
print(f"Création project : {result}")

# Créer un render
render_id = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id}', '{project_id}', 'queued');
"""
result = execute_sql(sql)
print(f"Création render : {result}")

# Test 1 : Lecture export_settings (doit être NULL)
sql = f"SELECT export_settings FROM app.whiteboard_renders WHERE id = '{render_id}'"
result = execute_sql(sql)
print(f"Test 1 Lecture export_settings : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS - Colonne présente")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Test 2 : Écriture export_settings
sql = f"""
UPDATE app.whiteboard_renders 
SET export_settings = '{{"format": "mp4", "resolution": {{"width": 1080, "height": 1920}}}}'::jsonb
WHERE id = '{render_id}';
"""
result = execute_sql(sql)
print(f"Test 2 Écriture export_settings : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Test 3 : Mise à jour export_settings
sql = f"""
UPDATE app.whiteboard_renders 
SET export_settings = '{{"format": "mp4", "resolution": {{"width": 1920, "height": 1080}}}}'::jsonb
WHERE id = '{render_id}';
"""
result = execute_sql(sql)
print(f"Test 3 Mise à jour export_settings : {result}")
if result.get("ok"):
    print("  ✅ SUCCÈS")
else:
    print("  ❌ ÉCHEC - STOP - ROLLBACK NÉCESSAIRE")
    exit(1)

# Nettoyage
sql = f"DELETE FROM app.whiteboard_renders WHERE id = '{render_id}'"
result = execute_sql(sql)
print(f"Nettoyage render : {result}")

sql = f"DELETE FROM app.whiteboard_projects WHERE id = '{project_id}'"
result = execute_sql(sql)
print(f"Nettoyage project : {result}")

print("\n=== VALIDATION C2 TERMINÉE - SUCCÈS ===\n")
