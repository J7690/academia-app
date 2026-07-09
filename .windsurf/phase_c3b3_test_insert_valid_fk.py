"""
Phase C.3B.3 – Test Insert Valid FK
Teste l'insertion avec un FK valide pour isoler la CHECK constraint
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== TEST INSERT VALID FK ===\n")

# 1. Créer un project valide
print("ÉTAPE 1: Créer un project valide")
project_id = str(uuid.uuid4())
student_id = "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"  # Student ID existant

sql_project = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Test', 'completed', 'scientific', 'scientific', 'none', '{{"test": true}}');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_project}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 2. Tester INSERT avec FK valide et status='queued'
print("TEST 1: INSERT avec FK valide et status='queued'")
render_id1 = str(uuid.uuid4())

sql1 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id1}', '{project_id}', 'queued');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql1}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 3. Tester INSERT avec FK valide et status='processing'
print("TEST 2: INSERT avec FK valide et status='processing'")
render_id2 = str(uuid.uuid4())

sql2 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id2}', '{project_id}', 'processing');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 4. Tester INSERT avec FK valide et status='done'
print("TEST 3: INSERT avec FK valide et status='done'")
render_id3 = str(uuid.uuid4())

sql3 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id3}', '{project_id}', 'done');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 5. Tester INSERT avec FK valide et status='failed'
print("TEST 4: INSERT avec FK valide et status='failed'")
render_id4 = str(uuid.uuid4())

sql4 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id4}', '{project_id}', 'failed');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql4}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
