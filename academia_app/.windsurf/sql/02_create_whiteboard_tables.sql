-- Création de la table whiteboard_projects
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
);

-- Indexes pour whiteboard_projects
CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id);
CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_status ON app.whiteboard_projects(status);
CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at DESC);

-- Création de la table whiteboard_renders
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
);

-- Indexes pour whiteboard_renders
CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id);
CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_status ON app.whiteboard_renders(status);
CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at DESC);

-- Création de la table whiteboard_ai_generations
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

-- Indexes pour whiteboard_ai_generations
CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_created_by ON app.whiteboard_ai_generations(created_by);
CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_status ON app.whiteboard_ai_generations(status);
CREATE INDEX IF NOT EXISTS idx_whiteboard_ai_generations_created_at ON app.whiteboard_ai_generations(created_at DESC);
