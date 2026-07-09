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
print("DÉPLOIEMENT DES RPCs WHITEBOARD VIA execute_ddl")
print("=" * 80)

# Étape 1 : Déployer les RPCs worker (public schema)
print("\n1. Déploiement des RPCs worker (public schema)...")

ddl1 = """
CREATE OR REPLACE FUNCTION public.whiteboard_fetch_queued_jobs(p_limit integer DEFAULT 5)
RETURNS TABLE (
    id uuid,
    storyboard jsonb,
    created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT wr.id, wp.storyboard_json as storyboard, wr.created_at
    FROM app.whiteboard_renders wr
    JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
    WHERE wr.status = 'queued'
    ORDER BY wr.created_at ASC
    LIMIT p_limit;
END;
$$;
"""
result1 = execute_ddl(ddl1)
print(f"  whiteboard_fetch_queued_jobs : {result1}")

ddl2 = """
CREATE OR REPLACE FUNCTION public.whiteboard_mark_processing(p_job_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app.whiteboard_renders
    SET status = 'processing',
        started_at = now()
    WHERE id = p_job_id;
END;
$$;
"""
result2 = execute_ddl(ddl2)
print(f"  whiteboard_mark_processing : {result2}")

ddl3 = """
CREATE OR REPLACE FUNCTION public.whiteboard_mark_done(p_job_id uuid, p_video_url text, p_duration_ms integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app.whiteboard_renders
    SET status = 'done',
        video_url = p_video_url,
        duration_ms = p_duration_ms,
        completed_at = now()
    WHERE id = p_job_id;
END;
$$;
"""
result3 = execute_ddl(ddl3)
print(f"  whiteboard_mark_done : {result3}")

ddl4 = """
CREATE OR REPLACE FUNCTION public.whiteboard_mark_failed(p_job_id uuid, p_error_message text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app.whiteboard_renders
    SET status = 'failed',
        error_message = p_error_message,
        completed_at = now()
    WHERE id = p_job_id;
END;
$$;
"""
result4 = execute_ddl(ddl4)
print(f"  whiteboard_mark_failed : {result4}")

ddl5 = """
CREATE OR REPLACE FUNCTION public.whiteboard_get_any_student_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id uuid;
BEGIN
    SELECT id INTO v_student_id FROM app.students LIMIT 1;
    RETURN v_student_id;
END;
$$;
"""
result5 = execute_ddl(ddl5)
print(f"  whiteboard_get_any_student_id : {result5}")

# Étape 2 : Déployer les RPCs editor (app schema)
print("\n2. Déploiement des RPCs editor (app schema)...")

ddl6 = """
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
"""
result6 = execute_ddl(ddl6)
print(f"  whiteboard_get_project : {result6}")

ddl7 = """
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
"""
result7 = execute_ddl(ddl7)
print(f"  whiteboard_update_project : {result7}")

ddl8 = """
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
"""
result8 = execute_ddl(ddl8)
print(f"  whiteboard_list_projects : {result8}")

ddl9 = """
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
"""
result9 = execute_ddl(ddl9)
print(f"  whiteboard_delete_project : {result9}")

# Étape 3 : Déployer la RPC whiteboard_create_project (si elle n'existe pas déjà)
print("\n3. Déploiement de la RPC whiteboard_create_project...")

ddl10 = """
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
    storyboard_json
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
result10 = execute_ddl(ddl10)
print(f"  whiteboard_create_project : {result10}")

print("\n" + "=" * 80)
print("DÉPLOIEMENT DES RPCs TERMINÉ")
print("=" * 80)
