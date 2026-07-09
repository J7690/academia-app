"""
Phase C.3B.3 – Test Insert Minimal
Teste l'insertion minimale pour isoler la cause
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== TEST INSERT MINIMAL ===\n")

# Test 1: INSERT avec seulement id et project_id (sans status)
print("TEST 1: INSERT avec seulement id et project_id (sans status)")
render_id = str(uuid.uuid4())
project_id = str(uuid.uuid4())

sql1 = f"""
INSERT INTO app.whiteboard_renders (id, project_id)
VALUES ('{render_id}', '{project_id}');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql1}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 2: INSERT avec id, project_id et status='queued'
print("TEST 2: INSERT avec id, project_id et status='queued'")
render_id2 = str(uuid.uuid4())
project_id2 = str(uuid.uuid4())

sql2 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id2}', '{project_id2}', 'queued');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 3: INSERT avec id, project_id et status='processing'
print("TEST 3: INSERT avec id, project_id et status='processing'")
render_id3 = str(uuid.uuid4())
project_id3 = str(uuid.uuid4())

sql3 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id3}', '{project_id3}', 'processing');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 4: INSERT avec id, project_id et status='done'
print("TEST 4: INSERT avec id, project_id et status='done'")
render_id4 = str(uuid.uuid4())
project_id4 = str(uuid.uuid4())

sql4 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id4}', '{project_id4}', 'done');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql4}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 5: INSERT avec id, project_id et status='failed'
print("TEST 5: INSERT avec id, project_id et status='failed'")
render_id5 = str(uuid.uuid4())
project_id5 = str(uuid.uuid4())

sql5 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id5}', '{project_id5}', 'failed');
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql5}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
