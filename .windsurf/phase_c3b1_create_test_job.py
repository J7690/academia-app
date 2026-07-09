"""
Phase C.3B.1 – Create Test Job
Crée un job de test dans whiteboard_renders
"""

import requests
import json
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== CREATE TEST JOB ===\n")

# 1. Récupérer un student_id existant
print("1. Récupération student_id...")
rpc_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_get_any_student_id"
resp = requests.post(rpc_url, headers=headers, timeout=30)
result = resp.json()
student_id = result if isinstance(result, str) else result.get('data') if isinstance(result, dict) else None
print(f"   Student ID : {student_id}")

if not student_id:
    print("   ERREUR: Aucun étudiant trouvé")
    exit(1)
print()

# Storyboard de test (Photosynthèse simple)
storyboard = {
    "title": "Photosynthèse",
    "blocks": [
        {"type": "title", "content": "La Photosynthèse"},
        {"type": "paragraph", "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie."}
    ]
}

# 2. Créer un project_id
project_id = str(uuid.uuid4())

sql_project = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Biologie', 'completed', 'scientific', 'scientific', 'none', '{json.dumps(storyboard).replace("'", "''")}');
"""

print("2. Création whiteboard_project...")
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_project}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 3. Créer un render job
render_id = str(uuid.uuid4())

sql_render = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status, progress)
VALUES ('{render_id}', '{project_id}', 'queued', 0);
"""

print("3. Création whiteboard_render...")
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_render}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

print(f"=== JOB CRÉÉ ===")
print(f"Project ID : {project_id}")
print(f"Render ID : {render_id}")
