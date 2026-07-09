"""
Script RPC administrateur pour localiser les tables whiteboard
Mission Critique – Diagnostic RPC
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

print("=== LOCALISATION DES TABLES WHITEBOARD ===\n")

# Chercher dans tous les schémas
sql = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name IN ('whiteboard_projects', 'whiteboard_renders')
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("Tables trouvées:")
    for row in data["rows"]:
        print(f"  {row['table_schema']}.{row['table_name']}")
else:
    print("❌ Tables non trouvées")

print("\n=== SUPPRESSION DES TABLES (SI ELLES EXISTENT) ===\n")

sql = "DROP TABLE IF EXISTS whiteboard_projects, whiteboard_renders CASCADE"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)

print("\n=== CRÉATION DES TABLES DANS SCHÉMA APP ===\n")

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
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok"):
        print("✅ whiteboard_projects créée")
    else:
        print(f"❌ Erreur: {data.get('error')}")
else:
    print("❌ Erreur HTTP")

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
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok"):
        print("✅ whiteboard_renders créée")
    else:
        print(f"❌ Erreur: {data.get('error')}")
else:
    print("❌ Erreur HTTP")

print("\n=== VÉRIFICATION FINALE ===\n")

sql = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name IN ('whiteboard_projects', 'whiteboard_renders')
AND table_schema = 'app'
ORDER BY table_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Tables créées dans schéma app:")
    for row in data["rows"]:
        print(f"  ✅ {row['table_schema']}.{row['table_name']}")
else:
    print("❌ Tables non trouvées dans schéma app")
