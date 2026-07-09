-- RPCs pour le Smart Whiteboard Editor
-- Ces RPCs permettent de gérer les projets et storyboards

-- RPC: whiteboard_create_project
-- Déjà créée dans change_20260624_whiteboard_content_agent.sql
-- Renommée ici pour cohérence avec le service Flutter

-- RPC: whiteboard_get_project
CREATE OR REPLACE FUNCTION app.whiteboard_get_project(p_project_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_record RECORD;
  result JSONB;
BEGIN
  SELECT 
    id,
    student_id,
    subject,
    status,
    created_at,
    updated_at,
    renderer_id,
    theme_id,
    narration_mode,
    storyboard_json
  INTO project_record
  FROM app.whiteboard_projects
  WHERE id = p_project_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project not found');
  END IF;
  
  result = jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );
  
  RETURN result;
END;
$$;

-- RPC: whiteboard_update_project
CREATE OR REPLACE FUNCTION app.whiteboard_update_project(
  p_project_id UUID,
  p_subject VARCHAR DEFAULT NULL,
  p_status VARCHAR DEFAULT NULL,
  p_renderer_id VARCHAR DEFAULT NULL,
  p_theme_id VARCHAR DEFAULT NULL,
  p_narration_mode VARCHAR DEFAULT NULL,
  p_storyboard_json JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_record RECORD;
  result JSONB;
BEGIN
  UPDATE app.whiteboard_projects
  SET 
    subject = COALESCE(p_subject, subject),
    status = COALESCE(p_status, status),
    renderer_id = COALESCE(p_renderer_id, renderer_id),
    theme_id = COALESCE(p_theme_id, theme_id),
    narration_mode = COALESCE(p_narration_mode, narration_mode),
    storyboard_json = COALESCE(p_storyboard_json, storyboard_json),
    updated_at = NOW()
  WHERE id = p_project_id
  RETURNING * INTO project_record;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project not found');
  END IF;
  
  result = jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );
  
  RETURN result;
END;
$$;

-- RPC: whiteboard_list_projects
CREATE OR REPLACE FUNCTION app.whiteboard_list_projects(p_status VARCHAR DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  projects JSONB;
  result JSONB;
BEGIN
  SELECT jsonb_agg(to_jsonb(t))
  INTO projects
  FROM (
    SELECT 
      id,
      student_id,
      subject,
      status,
      created_at,
      updated_at,
      renderer_id,
      theme_id,
      narration_mode
    FROM app.whiteboard_projects
    WHERE (p_status IS NULL OR status = p_status)
    ORDER BY created_at DESC
  ) t;
  
  result = jsonb_build_object(
    'success', true,
    'projects', COALESCE(projects, '[]'::jsonb)
  );
  
  RETURN result;
END;
$$;

-- RPC: whiteboard_delete_project
CREATE OR REPLACE FUNCTION app.whiteboard_delete_project(p_project_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  DELETE FROM app.whiteboard_projects
  WHERE id = p_project_id;
  
  result = jsonb_build_object(
    'success', true,
    'message', 'Project deleted'
  );
  
  RETURN result;
END;
$$;
