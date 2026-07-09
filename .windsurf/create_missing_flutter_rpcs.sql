-- ============================================================
-- CREATE MISSING FLUTTER RPCs - WHITEBOARD
-- Mission: D.14
-- Date: 2026-06-26
-- ============================================================
--
-- PRINCIPE: Créer UNIQUEMENT les 7 RPCs Flutter manquantes dans public.
-- Aucune surcharge, aucun doublon, aucune création dans app.
--
-- VALIDATION: Après nettoyage D.13, pg_proc montre exactement 7 fonctions whiteboard:
--   app.whiteboard_ai_generations_updated_at (trigger)
--   app.whiteboard_projects_updated_at (trigger)
--   public.whiteboard_fetch_queued_jobs (worker)
--   public.whiteboard_get_any_student_id (worker)
--   public.whiteboard_mark_done (worker)
--   public.whiteboard_mark_failed (worker)
--   public.whiteboard_mark_processing (worker)
--
-- Les 7 RPCs ci-dessous sont donc MISSING et doivent être créées.

-- ============================================================
-- 1. whiteboard_create_project
-- Appel Flutter: smart_whiteboard_service.dart:24
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_create_project(
    uuid, text, text, text, text, jsonb
);

CREATE OR REPLACE FUNCTION public.whiteboard_create_project(
  p_student_id uuid,
  p_subject text,
  p_renderer_id text,
  p_theme_id text,
  p_narration_mode text,
  p_storyboard_json jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_id uuid;
  v_result jsonb;
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

-- ============================================================
-- 2. whiteboard_get_project
-- Appel Flutter: smart_whiteboard_service.dart:41
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_get_project(uuid);

CREATE OR REPLACE FUNCTION public.whiteboard_get_project(
  p_project_id uuid
)
RETURNS jsonb
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
  WHERE id = p_project_id
  AND student_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );

  RETURN result;
END;
$$;

-- ============================================================
-- 3. whiteboard_update_project
-- Appel Flutter: smart_whiteboard_service.dart:61
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_update_project(
    uuid, text, text, text, text, text, jsonb
);

CREATE OR REPLACE FUNCTION public.whiteboard_update_project(
  p_project_id uuid,
  p_subject text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_renderer_id text DEFAULT NULL,
  p_theme_id text DEFAULT NULL,
  p_narration_mode text DEFAULT NULL,
  p_storyboard_json jsonb DEFAULT NULL
)
RETURNS jsonb
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
  AND student_id = auth.uid()
  RETURNING * INTO project_record;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );

  RETURN result;
END;
$$;

-- ============================================================
-- 4. whiteboard_list_projects
-- Appels Flutter:
--   smart_whiteboard_service.dart:79 (avec p_status)
--   smart_whiteboard_provider.dart:531 (sans paramètre)
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_list_projects(text);

CREATE OR REPLACE FUNCTION public.whiteboard_list_projects(
  p_status text DEFAULT NULL
)
RETURNS jsonb
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
    WHERE student_id = auth.uid()
    AND (p_status IS NULL OR status = p_status)
    ORDER BY created_at DESC
  ) t;

  result := jsonb_build_object(
    'success', true,
    'projects', COALESCE(projects, '[]'::jsonb)
  );

  RETURN result;
END;
$$;

-- ============================================================
-- 5. whiteboard_delete_project
-- Appel Flutter: smart_whiteboard_service.dart:91
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_delete_project(uuid);

CREATE OR REPLACE FUNCTION public.whiteboard_delete_project(
  p_project_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  DELETE FROM app.whiteboard_projects
  WHERE id = p_project_id
  AND student_id = auth.uid();

  result := jsonb_build_object(
    'success', true,
    'message', 'Project deleted'
  );

  RETURN result;
END;
$$;

-- ============================================================
-- 6. whiteboard_create_render_job
-- Appel Flutter: smart_whiteboard_render_service.dart:18
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_create_render_job(uuid);

CREATE OR REPLACE FUNCTION public.whiteboard_create_render_job(
  p_project_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_render_id uuid;
  v_project_exists boolean;
  v_result jsonb;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM app.whiteboard_projects
    WHERE id = p_project_id AND student_id = auth.uid()
  ) INTO v_project_exists;

  IF NOT v_project_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Project not found or unauthorized'
    );
  END IF;

  INSERT INTO app.whiteboard_renders (
    project_id,
    status,
    progress
  ) VALUES (
    p_project_id,
    'queued',
    0
  )
  RETURNING id INTO v_render_id;

  v_result := jsonb_build_object(
    'success', true,
    'render_id', v_render_id
  );

  RETURN v_result;
END;
$$;

-- ============================================================
-- 7. whiteboard_get_render_status
-- Appel Flutter: smart_whiteboard_render_service.dart:30
-- ============================================================
DROP FUNCTION IF EXISTS public.whiteboard_get_render_status(uuid);

CREATE OR REPLACE FUNCTION public.whiteboard_get_render_status(
  p_render_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  render_record RECORD;
  result JSONB;
BEGIN
  SELECT 
    wr.id,
    wr.project_id,
    wr.status,
    wr.video_url,
    wr.duration_ms,
    wr.file_size_bytes,
    wr.created_at,
    wr.completed_at,
    wr.error_message,
    wr.progress
  INTO render_record
  FROM app.whiteboard_renders wr
  JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
  WHERE wr.id = p_render_id
  AND wp.student_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Render not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'render', to_jsonb(render_record)
  );

  RETURN result;
END;
$$;

-- ============================================================
-- VÉRIFICATION POST-CRÉATION
-- ============================================================
-- Exécuter après ce script:
-- SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)
-- FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE p.proname ILIKE '%whiteboard%'
-- ORDER BY n.nspname, p.proname;
--
-- Résultat attendu: 14 fonctions (7 worker/trigger + 7 Flutter)
