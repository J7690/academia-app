import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=" * 80)
print("DÉPLOIEMENT DES TABLES WHITEBOARD VIA execute_ddl")
print("=" * 80)

# Étape 1 : Créer la table whiteboard_projects
print("\n1. Création de la table whiteboard_projects...")
ddl1 = """
CREATE TABLE IF NOT EXISTS app.whiteboard_projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  subject VARCHAR(255) NOT NULL,
  status VARCHAR(50) DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  renderer_id VARCHAR(50) NOT NULL,
  theme_id VARCHAR(50) NOT NULL,
  narration_mode VARCHAR(50) DEFAULT 'none',
  storyboard_json JSONB
)
"""
result1 = execute_ddl(ddl1)
print(f"  Résultat : {result1}")

# Étape 2 : Créer les indexes pour whiteboard_projects
print("\n2. Création des indexes pour whiteboard_projects...")
ddl2a = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id)"
result2a = execute_ddl(ddl2a)
print(f"  idx_whiteboard_projects_student_id : {result2a}")

ddl2b = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_status ON app.whiteboard_projects(status)"
result2b = execute_ddl(ddl2b)
print(f"  idx_whiteboard_projects_status : {result2b}")

ddl2c = "CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at DESC)"
result2c = execute_ddl(ddl2c)
print(f"  idx_whiteboard_projects_created_at : {result2c}")

# Étape 3 : Créer la table whiteboard_renders
print("\n3. Création de la table whiteboard_renders...")
ddl3 = """
CREATE TABLE IF NOT EXISTS app.whiteboard_renders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES app.whiteboard_projects(id) ON DELETE CASCADE,
  status VARCHAR(50) DEFAULT 'queued',
  video_url TEXT,
  duration_ms INTEGER,
  file_size_bytes BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  progress INTEGER DEFAULT 0
)
"""
result3 = execute_ddl(ddl3)
print(f"  Résultat : {result3}")

# Étape 4 : Créer les indexes pour whiteboard_renders
print("\n4. Création des indexes pour whiteboard_renders...")
ddl4a = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id)"
result4a = execute_ddl(ddl4a)
print(f"  idx_whiteboard_renders_project_id : {result4a}")

ddl4b = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_status ON app.whiteboard_renders(status)"
result4b = execute_ddl(ddl4b)
print(f"  idx_whiteboard_renders_status : {result4b}")

ddl4c = "CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at DESC)"
result4c = execute_ddl(ddl4c)
print(f"  idx_whiteboard_renders_created_at : {result4c}")

# Étape 5 : Activer RLS sur whiteboard_projects
print("\n5. Activation de RLS sur whiteboard_projects...")
ddl5 = "ALTER TABLE app.whiteboard_projects ENABLE ROW LEVEL SECURITY"
result5 = execute_ddl(ddl5)
print(f"  Résultat : {result5}")

# Étape 6 : Créer les RLS policies pour whiteboard_projects
print("\n6. Création des RLS policies pour whiteboard_projects...")
ddl6a = """
CREATE POLICY "Students can view own projects" ON app.whiteboard_projects
  FOR SELECT USING (auth.uid() = student_id)
"""
result6a = execute_ddl(ddl6a)
print(f"  Students can view own projects : {result6a}")

ddl6b = """
CREATE POLICY "Students can insert own projects" ON app.whiteboard_projects
  FOR INSERT WITH CHECK (auth.uid() = student_id)
"""
result6b = execute_ddl(ddl6b)
print(f"  Students can insert own projects : {result6b}")

ddl6c = """
CREATE POLICY "Students can update own projects" ON app.whiteboard_projects
  FOR UPDATE USING (auth.uid() = student_id)
"""
result6c = execute_ddl(ddl6c)
print(f"  Students can update own projects : {result6c}")

ddl6d = """
CREATE POLICY "Students can delete own projects" ON app.whiteboard_projects
  FOR DELETE USING (auth.uid() = student_id)
"""
result6d = execute_ddl(ddl6d)
print(f"  Students can delete own projects : {result6d}")

ddl6e = """
CREATE POLICY "Service role can do everything" ON app.whiteboard_projects
  FOR ALL USING (auth.role() = 'service_role')
"""
result6e = execute_ddl(ddl6e)
print(f"  Service role can do everything : {result6e}")

# Étape 7 : Activer RLS sur whiteboard_renders
print("\n7. Activation de RLS sur whiteboard_renders...")
ddl7 = "ALTER TABLE app.whiteboard_renders ENABLE ROW LEVEL SECURITY"
result7 = execute_ddl(ddl7)
print(f"  Résultat : {result7}")

# Étape 8 : Créer les RLS policies pour whiteboard_renders
print("\n8. Création des RLS policies pour whiteboard_renders...")
ddl8a = """
CREATE POLICY "Students can view own renders" ON app.whiteboard_renders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM app.whiteboard_projects
      WHERE whiteboard_projects.id = whiteboard_renders.project_id
      AND whiteboard_projects.student_id = auth.uid()
    )
  )
"""
result8a = execute_ddl(ddl8a)
print(f"  Students can view own renders : {result8a}")

ddl8b = """
CREATE POLICY "Service role can do everything" ON app.whiteboard_renders
  FOR ALL USING (auth.role() = 'service_role')
"""
result8b = execute_ddl(ddl8b)
print(f"  Service role can do everything : {result8b}")

# Étape 9 : Créer la fonction updated_at pour whiteboard_projects
print("\n9. Création de la fonction updated_at pour whiteboard_projects...")
ddl9 = """
CREATE OR REPLACE FUNCTION app.whiteboard_projects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
"""
result9 = execute_ddl(ddl9)
print(f"  Résultat : {result9}")

# Étape 10 : Créer le trigger updated_at pour whiteboard_projects
print("\n10. Création du trigger updated_at pour whiteboard_projects...")
ddl10 = """
CREATE TRIGGER whiteboard_projects_updated_at_trigger
  BEFORE UPDATE ON app.whiteboard_projects
  FOR EACH ROW
  EXECUTE FUNCTION app.whiteboard_projects_updated_at()
"""
result10 = execute_ddl(ddl10)
print(f"  Résultat : {result10}")

# Étape 11 : Créer la table whiteboard_ai_generations
print("\n11. Création de la table whiteboard_ai_generations...")
ddl11 = """
CREATE TABLE IF NOT EXISTS app.whiteboard_ai_generations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  generation_type VARCHAR(50) NOT NULL DEFAULT 'storyboard',
  input_params JSONB NOT NULL,
  output_json JSONB NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'validated',
  model_used VARCHAR(100),
  tokens_input INTEGER DEFAULT 0,
  tokens_output INTEGER DEFAULT 0,
  cost_usd DECIMAL(10, 6) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
)
"""
result11 = execute_ddl(ddl11)
print(f"  Résultat : {result11}")

# Étape 12 : Créer les indexes pour whiteboard_ai_generations
print("\n12. Création des indexes pour whiteboard_ai_generations...")
ddl12a = "CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_created_by ON app.whiteboard_ai_generations(created_by)"
result12a = execute_ddl(ddl12a)
print(f"  idx_whiteboard_ai_generations_created_by : {result12a}")

ddl12b = "CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_status ON app.whiteboard_ai_generations(status)"
result12b = execute_ddl(ddl12b)
print(f"  idx_whiteboard_ai_generations_status : {result12b}")

ddl12c = "CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_created_at ON app.whiteboard_ai_generations(created_at DESC)"
result12c = execute_ddl(ddl12c)
print(f"  idx_whiteboard_ai_generations_created_at : {result12c}")

# Étape 13 : Activer RLS sur whiteboard_ai_generations
print("\n13. Activation de RLS sur whiteboard_ai_generations...")
ddl13 = "ALTER TABLE app.whiteboard_ai_generations ENABLE ROW LEVEL SECURITY"
result13 = execute_ddl(ddl13)
print(f"  Résultat : {result13}")

# Étape 14 : Créer les RLS policies pour whiteboard_ai_generations
print("\n14. Création des RLS policies pour whiteboard_ai_generations...")
ddl14a = """
CREATE POLICY "Students can view own generations"
  ON app.whiteboard_ai_generations
  FOR SELECT
  USING (auth.uid() = created_by)
"""
result14a = execute_ddl(ddl14a)
print(f"  Students can view own generations : {result14a}")

ddl14b = """
CREATE POLICY "Admins can view all generations"
  ON app.whiteboard_ai_generations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM app.admin_users
      WHERE user_id = auth.uid()
    )
  )
"""
result14b = execute_ddl(ddl14b)
print(f"  Admins can view all generations : {result14b}")

ddl14c = """
CREATE POLICY "Service role can insert generations"
  ON app.whiteboard_ai_generations
  FOR INSERT
  WITH CHECK (true)
"""
result14c = execute_ddl(ddl14c)
print(f"  Service role can insert generations : {result14c}")

# Étape 15 : Créer la fonction updated_at pour whiteboard_ai_generations
print("\n15. Création de la fonction updated_at pour whiteboard_ai_generations...")
ddl15 = """
CREATE OR REPLACE FUNCTION app.whiteboard_ai_generations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
"""
result15 = execute_ddl(ddl15)
print(f"  Résultat : {result15}")

# Étape 16 : Créer le trigger updated_at pour whiteboard_ai_generations
print("\n16. Création du trigger updated_at pour whiteboard_ai_generations...")
ddl16 = """
CREATE TRIGGER whiteboard_ai_generations_updated_at_trigger
  BEFORE UPDATE ON app.whiteboard_ai_generations
  FOR EACH ROW
  EXECUTE FUNCTION app.whiteboard_ai_generations_updated_at()
"""
result16 = execute_ddl(ddl16)
print(f"  Résultat : {result16}")

print("\n" + "=" * 80)
print("DÉPLOIEMENT DES TABLES TERMINÉ")
print("=" * 80)
