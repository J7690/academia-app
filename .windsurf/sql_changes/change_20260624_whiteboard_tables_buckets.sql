-- Tables et Buckets pour Smart Whiteboard
-- PHASE D.4 - End to End Workflow Validation

-- Table whiteboard_projects
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id);
CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_status ON app.whiteboard_projects(status);
CREATE INDEX IF NOT EXISTS idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at DESC);

-- Table whiteboard_renders
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id);
CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_status ON app.whiteboard_renders(status);
CREATE INDEX IF NOT EXISTS idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at DESC);

-- RLS Policies
ALTER TABLE app.whiteboard_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view own projects" ON app.whiteboard_projects
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Students can insert own projects" ON app.whiteboard_projects
  FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Students can update own projects" ON app.whiteboard_projects
  FOR UPDATE USING (auth.uid() = student_id);

CREATE POLICY "Students can delete own projects" ON app.whiteboard_projects
  FOR DELETE USING (auth.uid() = student_id);

CREATE POLICY "Service role can do everything" ON app.whiteboard_projects
  FOR ALL USING (auth.role() = 'service_role');

ALTER TABLE app.whiteboard_renders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view own renders" ON app.whiteboard_renders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM app.whiteboard_projects
      WHERE whiteboard_projects.id = whiteboard_renders.project_id
      AND whiteboard_projects.student_id = auth.uid()
    )
  );

CREATE POLICY "Service role can do everything" ON app.whiteboard_renders
  FOR ALL USING (auth.role() = 'service_role');

-- Updated at trigger
CREATE OR REPLACE FUNCTION app.whiteboard_projects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER whiteboard_projects_updated_at_trigger
  BEFORE UPDATE ON app.whiteboard_projects
  FOR EACH ROW
  EXECUTE FUNCTION app.whiteboard_projects_updated_at();
