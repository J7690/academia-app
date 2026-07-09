"""
Script pour Phase B.5 – Création des RPCs whiteboard v2 (avec p_student_id optionnel pour tests)
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

print("=== CRÉATION RPCS WHITEBOARD V2 ===\n")

# RPC 1: create_project (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_create_project(
  p_student_id UUID DEFAULT NULL,
  p_subject TEXT,
  p_renderer_id TEXT,
  p_theme_id TEXT,
  p_narration_mode TEXT DEFAULT 'none',
  p_storyboard_json JSONB DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_project_id UUID;
  v_result JSONB;
BEGIN
  -- Utiliser p_student_id si fourni (pour tests admin), sinon auth.uid()
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.whiteboard_projects (
    student_id,
    subject,
    status,
    renderer_id,
    theme_id,
    narration_mode,
    storyboard_json
  ) VALUES (
    v_student_id,
    p_subject,
    'draft',
    p_renderer_id,
    p_theme_id,
    p_narration_mode,
    p_storyboard_json
  ) RETURNING id INTO v_project_id;

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'project_id', v_project_id
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC create_project: {result}")

# RPC 2: update_project (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_update_project(
  p_student_id UUID DEFAULT NULL,
  p_project_id UUID,
  p_subject TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_renderer_id TEXT DEFAULT NULL,
  p_theme_id TEXT DEFAULT NULL,
  p_narration_mode TEXT DEFAULT NULL,
  p_storyboard_json JSONB DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_result JSONB;
BEGIN
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  UPDATE app.whiteboard_projects
  SET 
    subject = COALESCE(p_subject, subject),
    status = COALESCE(p_status, status),
    renderer_id = COALESCE(p_renderer_id, renderer_id),
    theme_id = COALESCE(p_theme_id, theme_id),
    narration_mode = COALESCE(p_narration_mode, narration_mode),
    storyboard_json = COALESCE(p_storyboard_json, storyboard_json),
    updated_at = NOW()
  WHERE id = p_project_id AND student_id = v_student_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'project_not_found');
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'project_id', p_project_id
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC update_project: {result}")

# RPC 3: get_project (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_get_project(
  p_student_id UUID DEFAULT NULL,
  p_project_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_project RECORD;
  v_result JSONB;
BEGIN
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_project
  FROM app.whiteboard_projects
  WHERE id = p_project_id AND student_id = v_student_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'project_not_found');
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'project', JSONB_BUILD_OBJECT(
      'id', v_project.id,
      'student_id', v_project.student_id,
      'subject', v_project.subject,
      'status', v_project.status,
      'renderer_id', v_project.renderer_id,
      'theme_id', v_project.theme_id,
      'narration_mode', v_project.narration_mode,
      'storyboard_json', v_project.storyboard_json,
      'created_at', v_project.created_at,
      'updated_at', v_project.updated_at
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC get_project: {result}")

# RPC 4: list_projects (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_list_projects(
  p_student_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_projects JSONB;
  v_result JSONB;
BEGIN
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', wp.id,
        'student_id', wp.student_id,
        'subject', wp.subject,
        'status', wp.status,
        'renderer_id', wp.renderer_id,
        'theme_id', wp.theme_id,
        'narration_mode', wp.narration_mode,
        'created_at', wp.created_at,
        'updated_at', wp.updated_at
      )
      ORDER BY wp.created_at DESC
    ),
    '[]'::JSONB
  ) INTO v_projects
  FROM app.whiteboard_projects wp
  WHERE wp.student_id = v_student_id
    AND (p_status IS NULL OR wp.status = p_status);

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'projects', v_projects
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC list_projects: {result}")

# RPC 5: delete_project (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_delete_project(
  p_student_id UUID DEFAULT NULL,
  p_project_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_result JSONB;
BEGIN
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  DELETE FROM app.whiteboard_projects
  WHERE id = p_project_id AND student_id = v_student_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'project_not_found');
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'project_id', p_project_id
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC delete_project: {result}")

# RPC 6: create_render_job (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_create_render_job(
  p_student_id UUID DEFAULT NULL,
  p_project_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_render_id UUID;
  v_result JSONB;
BEGIN
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.whiteboard_renders (
    project_id,
    status,
    started_at
  ) VALUES (
    p_project_id,
    'pending',
    NOW()
  ) RETURNING id INTO v_render_id;

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'render_id', v_render_id,
    'project_id', p_project_id
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC create_render_job: {result}")

# RPC 7: get_render_status (avec p_student_id optionnel pour tests)
sql = """
CREATE OR REPLACE FUNCTION app.whiteboard_get_render_status(
  p_student_id UUID DEFAULT NULL,
  p_render_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_render RECORD;
  v_result JSONB;
BEGIN
  v_student_id := COALESCE(p_student_id, auth.uid());
  
  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT wr.* INTO v_render
  FROM app.whiteboard_renders wr
  JOIN app.whiteboard_projects wp ON wp.id = wr.project_id
  WHERE wr.id = p_render_id AND wp.student_id = v_student_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'render_not_found');
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'success', TRUE,
    'render', JSONB_BUILD_OBJECT(
      'id', v_render.id,
      'project_id', v_render.project_id,
      'status', v_render.status,
      'video_url', v_render.video_url,
      'video_storage_path', v_render.video_storage_path,
      'video_storage_bucket', v_render.video_storage_bucket,
      'error_message', v_render.error_message,
      'started_at', v_render.started_at,
      'completed_at', v_render.completed_at,
      'created_at', v_render.created_at,
      'updated_at', v_render.updated_at
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;
"""
result = execute_sql(sql)
print(f"RPC get_render_status: {result}")

print("\n=== CRÉATION RPCS V2 TERMINÉE ===\n")
