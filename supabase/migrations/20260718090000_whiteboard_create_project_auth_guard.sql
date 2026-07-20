-- Migration: sécuriser whiteboard_create_project pour empêcher un utilisateur
-- authentifié de créer un projet au nom d'un autre étudiant.
-- Comportement:
--   * Si auth.uid() est NULL (contexte service_role, worker, migration) → autorisé.
--   * Si auth.uid() est défini et diffère de p_student_id → rejet propre.
--   * Sinon (auth.uid() = p_student_id) → comportement inchangé.

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
AS $function$
DECLARE
  v_project_id uuid;
  v_result jsonb;
  v_caller_id uuid;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NOT NULL AND v_caller_id <> p_student_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'forbidden_student_mismatch',
      'message', 'Cannot create a project for another student.'
    );
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
$function$;
