"""
Script pour Phase B.5 – Création des tables whiteboard
"""

import requests

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

print("=== CRÉATION TABLES WHITEBOARD ===\n")

# Créer table whiteboard_projects
sql = """
CREATE TABLE IF NOT EXISTS app.whiteboard_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'completed')),
  renderer_id TEXT NOT NULL CHECK (renderer_id IN ('scientific', 'notebook')),
  theme_id TEXT NOT NULL CHECK (theme_id IN ('scientific', 'notebook')),
  narration_mode TEXT NOT NULL DEFAULT 'none' CHECK (narration_mode IN ('none', 'tts', 'user_recording')),
  storyboard_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
"""
result = execute_sql(sql)
print(f"Création whiteboard_projects: {result}")

# Créer indexes
sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_id ON app.whiteboard_projects(id)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_projects_id: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_projects_student_id: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_status ON app.whiteboard_projects(status)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_projects_status: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at DESC)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_projects_created_at: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_storyboard_json ON app.whiteboard_projects USING GIN (storyboard_json)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_projects_storyboard_json: {result}")

# Créer table whiteboard_renders
sql = """
CREATE TABLE IF NOT EXISTS app.whiteboard_renders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES app.whiteboard_projects(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  video_url TEXT,
  video_storage_path TEXT,
  video_storage_bucket TEXT,
  error_message TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
"""
result = execute_sql(sql)
print(f"\nCréation whiteboard_renders: {result}")

# Créer indexes
sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_id ON app.whiteboard_renders(id)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_renders_id: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_renders_project_id: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_status ON app.whiteboard_renders(status)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_renders_status: {result}")

sql = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at DESC)"
result = execute_sql(sql)
print(f"Index idx_whiteboard_renders_created_at: {result}")

# Activer RLS
sql = "ALTER TABLE app.whiteboard_projects ENABLE ROW LEVEL SECURITY"
result = execute_sql(sql)
print(f"\nRLS whiteboard_projects: {result}")

sql = "ALTER TABLE app.whiteboard_renders ENABLE ROW LEVEL SECURITY"
result = execute_sql(sql)
print(f"RLS whiteboard_renders: {result}")

print("\n=== CRÉATION TABLES TERMINÉE ===\n")
