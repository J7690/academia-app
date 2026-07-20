CREATE OR REPLACE FUNCTION public.whiteboard_mark_done(
  p_job_id uuid,
  p_video_url text,
  p_duration_ms integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  UPDATE app.whiteboard_renders
  SET status = 'done',
      video_url = p_video_url,
      duration_ms = p_duration_ms,
      completed_at = now()
  WHERE id = p_job_id
  RETURNING project_id INTO v_project_id;

  IF v_project_id IS NOT NULL THEN
    UPDATE app.whiteboard_projects
    SET status = 'completed'
    WHERE id = v_project_id;
  END IF;
END;
$function$;
