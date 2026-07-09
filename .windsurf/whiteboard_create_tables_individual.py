"""
Script RPC administrateur pour créer les tables whiteboard via commandes individuelles
Phase B.2 – Tables Execution
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

print("=== CRÉATION TABLE whiteboard_projects ===\n")

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
        print("❌ Erreur lors de la création")
else:
    print("❌ Erreur HTTP")

print("\n=== CRÉATION TABLE whiteboard_renders ===\n")

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
        print("❌ Erreur lors de la création")
else:
    print("❌ Erreur HTTP")

print("\n=== CRÉATION INDEXES whiteboard_projects ===\n")

indexes = [
    "CREATE INDEX idx_whiteboard_projects_id ON app.whiteboard_projects(id)",
    "CREATE INDEX idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id)",
    "CREATE INDEX idx_whiteboard_projects_status ON app.whiteboard_projects(status)",
    "CREATE INDEX idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at)",
    "CREATE INDEX idx_whiteboard_projects_storyboard_json ON app.whiteboard_projects USING GIN (storyboard_json)"
]

for idx_sql in indexes:
    resp = requests.post(url, headers=headers, json={"p_sql": idx_sql}, timeout=30)
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok"):
            print(f"✅ Index créé: {idx_sql.split('idx_')[1].split(' ')[0]}")
        else:
            print(f"❌ Erreur index: {idx_sql}")
    else:
        print(f"❌ Erreur HTTP: {idx_sql}")

print("\n=== CRÉATION INDEXES whiteboard_renders ===\n")

indexes = [
    "CREATE INDEX idx_whiteboard_renders_id ON app.whiteboard_renders(id)",
    "CREATE INDEX idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id)",
    "CREATE INDEX idx_whiteboard_renders_status ON app.whiteboard_renders(status)",
    "CREATE INDEX idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at)"
]

for idx_sql in indexes:
    resp = requests.post(url, headers=headers, json={"p_sql": idx_sql}, timeout=30)
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok"):
            print(f"✅ Index créé: {idx_sql.split('idx_')[1].split(' ')[0]}")
        else:
            print(f"❌ Erreur index: {idx_sql}")
    else:
        print(f"❌ Erreur HTTP: {idx_sql}")

print("\n=== CRÉATION TRIGGER updated_at ===\n")

sql = """
CREATE OR REPLACE FUNCTION app.update_whiteboard_projects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok"):
        print("✅ Fonction trigger créée")
    else:
        print("❌ Erreur lors de la création")
else:
    print("❌ Erreur HTTP")

sql = """
CREATE TRIGGER trigger_update_whiteboard_projects_updated_at
BEFORE UPDATE ON app.whiteboard_projects
FOR EACH ROW
EXECUTE FUNCTION app.update_whiteboard_projects_updated_at()
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok"):
        print("✅ Trigger créé")
    else:
        print("❌ Erreur lors de la création")
else:
    print("❌ Erreur HTTP")

print("\n=== VÉRIFICATION FINALE ===\n")

sql = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name IN ('whiteboard_projects', 'whiteboard_renders')
ORDER BY table_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Tables créées:")
    for row in data["rows"]:
        print(f"  ✅ {row['table_name']}")
else:
    print("❌ Tables non trouvées")
