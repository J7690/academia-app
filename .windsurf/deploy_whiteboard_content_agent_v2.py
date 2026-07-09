import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("DÉPLOIEMENT WHITEBOARD CONTENT AGENT V2")
print("=" * 80)

# Étape 1: Ajouter action code generate_storyboard (sans price_usd)
sql1 = """
INSERT INTO app.ai_action_prices (action_code, cost_credits, description, is_active, label)
VALUES ('generate_storyboard', 15, 'Génération Storyboard Smart Whiteboard', true, 'Générer un Storyboard')
ON CONFLICT (action_code) DO UPDATE SET
  cost_credits = EXCLUDED.cost_credits,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  label = EXCLUDED.label;
"""
print("\n1. Ajout action code generate_storyboard...")
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("   STATUS:", resp1.status_code)
print("   BODY:", resp1.text[:500])

# Étape 2: Créer table whiteboard_ai_generations
sql2 = """
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
);
"""
print("\n2. Création table whiteboard_ai_generations...")
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("   STATUS:", resp2.status_code)
print("   BODY:", resp2.text[:500])

# Étape 3: Indexes
sql3 = """
CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_created_by ON app.whiteboard_ai_generations(created_by);
CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_status ON app.whiteboard_ai_generations(status);
CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_created_at ON app.whiteboard_ai_generations(created_at DESC);
"""
print("\n3. Création indexes...")
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("   STATUS:", resp3.status_code)
print("   BODY:", resp3.text[:500])

# Étape 4: RPC whiteboard_create_project
sql4 = """
CREATE OR REPLACE FUNCTION app.whiteboard_create_project(
  p_student_id UUID,
  p_subject VARCHAR,
  p_renderer_id VARCHAR,
  p_theme_id VARCHAR,
  p_narration_mode VARCHAR,
  p_storyboard_json JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_id UUID;
  v_result JSONB;
BEGIN
  INSERT INTO app.whiteboard_projects (
    student_id,
    subject,
    status,
    renderer_id,
    theme_id,
    narration_mode,
    storyboard
  ) VALUES (
    p_student_id,
    p_subject,
    'draft',
    p_renderer_id,
    p_theme_id,
    p_narration_mode,
    p_storyboard_json
  )
  RETURNING id INTO v_project_id;

  v_result := jsonb_build_object(
    'success', true,
    'project_id', v_project_id
  );

  RETURN v_result;
END;
$$;
"""
print("\n4. Création RPC whiteboard_create_project...")
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("   STATUS:", resp4.status_code)
print("   BODY:", resp4.text[:500])

# Étape 5: RLS
sql5 = """
ALTER TABLE app.whiteboard_ai_generations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students can view own generations" ON app.whiteboard_ai_generations;
CREATE POLICY "Students can view own generations"
  ON app.whiteboard_ai_generations
  FOR SELECT
  USING (auth.uid() = created_by);

DROP POLICY IF EXISTS "Admins can view all generations" ON app.whiteboard_ai_generations;
CREATE POLICY "Admins can view all generations"
  ON app.whiteboard_ai_generations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM app.admin_users
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Service role can insert generations" ON app.whiteboard_ai_generations;
CREATE POLICY "Service role can insert generations"
  ON app.whiteboard_ai_generations
  FOR INSERT
  WITH CHECK (true);
"""
print("\n5. Configuration RLS...")
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print("   STATUS:", resp5.status_code)
print("   BODY:", resp5.text[:500])

# Étape 6: Trigger updated_at
sql6 = """
CREATE OR REPLACE FUNCTION app.whiteboard_ai_generations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS whiteboard_ai_generations_updated_at_trigger ON app.whiteboard_ai_generations;
CREATE TRIGGER whiteboard_ai_generations_updated_at_trigger
  BEFORE UPDATE ON app.whiteboard_ai_generations
  FOR EACH ROW
  EXECUTE FUNCTION app.whiteboard_ai_generations_updated_at();
"""
print("\n6. Création trigger updated_at...")
resp6 = requests.post(url, headers=headers, json={"p_sql": sql6}, timeout=30)
print("   STATUS:", resp6.status_code)
print("   BODY:", resp6.text[:500])

print("\n" + "=" * 80)
print("DÉPLOIEMENT TERMINÉ")
print("=" * 80)
