"""
Phase C.3B.3 – Test All Columns
Teste l'insertion avec toutes les colonnes
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== TEST ALL COLUMNS ===\n")

# Utiliser le project_id créé précédemment
project_id = "c2ae6bd1-5022-4d85-bac2-4fdbceae91e9"  # Project existant

# Test 1: INSERT avec toutes les colonnes et status='queued'
print("TEST 1: INSERT avec toutes les colonnes et status='queued'")
render_id1 = str(uuid.uuid4())

sql1 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status, video_url, duration_ms, error_message, progress, created_at, completed_at)
VALUES ('{render_id1}', '{project_id}', 'queued', NULL, NULL, NULL, 0, NOW(), NULL);
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql1}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 2: INSERT avec toutes les colonnes et status='processing'
print("TEST 2: INSERT avec toutes les colonnes et status='processing'")
render_id2 = str(uuid.uuid4())

sql2 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status, video_url, duration_ms, error_message, progress, created_at, completed_at)
VALUES ('{render_id2}', '{project_id}', 'processing', NULL, NULL, NULL, 0, NOW(), NULL);
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 3: INSERT avec toutes les colonnes et status='done'
print("TEST 3: INSERT avec toutes les colonnes et status='done'")
render_id3 = str(uuid.uuid4())

sql3 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status, video_url, duration_ms, error_message, progress, created_at, completed_at)
VALUES ('{render_id3}', '{project_id}', 'done', 'https://example.com/video.mp4', 5000, NULL, 100, NOW(), NOW());
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# Test 4: INSERT avec toutes les colonnes et status='failed'
print("TEST 4: INSERT avec toutes les colonnes et status='failed'")
render_id4 = str(uuid.uuid4())

sql4 = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status, video_url, duration_ms, error_message, progress, created_at, completed_at)
VALUES ('{render_id4}', '{project_id}', 'failed', NULL, NULL, 'Test error', 0, NOW(), NOW());
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql4}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
