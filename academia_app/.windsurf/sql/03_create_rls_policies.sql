-- Activation de RLS sur whiteboard_projects
ALTER TABLE app.whiteboard_projects ENABLE ROW LEVEL SECURITY;

-- RLS policies pour whiteboard_projects
DROP POLICY IF EXISTS "Students can view own projects" ON app.whiteboard_projects;
CREATE POLICY "Students can view own projects" ON app.whiteboard_projects
  FOR SELECT USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Students can insert own projects" ON app.whiteboard_projects;
CREATE POLICY "Students can insert own projects" ON app.whiteboard_projects
  FOR INSERT WITH CHECK (auth.uid() = student_id);

DROP POLICY IF EXISTS "Students can update own projects" ON app.whiteboard_projects;
CREATE POLICY "Students can update own projects" ON app.whiteboard_projects
  FOR UPDATE USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Students can delete own projects" ON app.whiteboard_projects;
CREATE POLICY "Students can delete own projects" ON app.whiteboard_projects
  FOR DELETE USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Service role can do everything" ON app.whiteboard_projects;
CREATE POLICY "Service role can do everything" ON app.whiteboard_projects
  FOR ALL USING (auth.role() = 'service_role');

-- Activation de RLS sur whiteboard_renders
ALTER TABLE app.whiteboard_renders ENABLE ROW LEVEL SECURITY;

-- RLS policies pour whiteboard_renders
DROP POLICY IF EXISTS "Students can view own renders" ON app.whiteboard_renders;
CREATE POLICY "Students can view own renders" ON app.whiteboard_renders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM app.whiteboard_projects
      WHERE whiteboard_projects.id = whiteboard_renders.project_id
      AND whiteboard_projects.student_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Service role can do everything" ON app.whiteboard_renders;
CREATE POLICY "Service role can do everything" ON app.whiteboard_renders
  FOR ALL USING (auth.role() = 'service_role');

-- Activation de RLS sur whiteboard_ai_generations
ALTER TABLE app.whiteboard_ai_generations ENABLE ROW LEVEL SECURITY;

-- RLS policies pour whiteboard_ai_generations
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
