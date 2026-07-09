-- Migration: Create whiteboard tables
-- Date: 2026-06-23
-- Phase: B.2
-- Description: Create whiteboard_projects and whiteboard_renders tables

-- ============================================================================
-- TABLE: whiteboard_projects
-- ============================================================================

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
);

-- ============================================================================
-- TABLE: whiteboard_renders
-- ============================================================================

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
);

-- ============================================================================
-- INDEXES: whiteboard_projects
-- ============================================================================

CREATE INDEX idx_whiteboard_projects_id ON app.whiteboard_projects(id);
CREATE INDEX idx_whiteboard_projects_student_id ON app.whiteboard_projects(student_id);
CREATE INDEX idx_whiteboard_projects_status ON app.whiteboard_projects(status);
CREATE INDEX idx_whiteboard_projects_created_at ON app.whiteboard_projects(created_at);
CREATE INDEX idx_whiteboard_projects_storyboard_json ON app.whiteboard_projects USING GIN (storyboard_json);

-- ============================================================================
-- INDEXES: whiteboard_renders
-- ============================================================================

CREATE INDEX idx_whiteboard_renders_id ON app.whiteboard_renders(id);
CREATE INDEX idx_whiteboard_renders_project_id ON app.whiteboard_renders(project_id);
CREATE INDEX idx_whiteboard_renders_status ON app.whiteboard_renders(status);
CREATE INDEX idx_whiteboard_renders_created_at ON app.whiteboard_renders(created_at);

-- ============================================================================
-- TRIGGER: updated_at for whiteboard_projects
-- ============================================================================

CREATE OR REPLACE FUNCTION app.update_whiteboard_projects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_whiteboard_projects_updated_at
BEFORE UPDATE ON app.whiteboard_projects
FOR EACH ROW
EXECUTE FUNCTION app.update_whiteboard_projects_updated_at();
