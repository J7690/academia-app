CREATE OR REPLACE FUNCTION public.whiteboard_list_projects(p_status text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  projects jsonb;
  result jsonb;
BEGIN
  SELECT jsonb_agg(to_jsonb(t))
  INTO projects
  FROM (
    SELECT
      p.id,
      p.student_id,
      p.subject,
      p.status,
      p.created_at,
      p.updated_at,
      p.renderer_id,
      p.theme_id,
      p.narration_mode,
      completed_render.render_id,
      completed_render.video_url
    FROM app.whiteboard_projects p
    LEFT JOIN LATERAL (
      SELECT
        r.id AS render_id,
        r.video_url
      FROM app.whiteboard_renders r
      WHERE r.project_id = p.id
        AND r.status = 'done'
        AND r.video_url IS NOT NULL
      ORDER BY r.completed_at DESC NULLS LAST, r.created_at DESC
      LIMIT 1
    ) completed_render ON true
    WHERE p.student_id = auth.uid()
      AND (p_status IS NULL OR p.status = p_status)
    ORDER BY p.created_at DESC
  ) t;

  result := jsonb_build_object(
    'success', true,
    'projects', coalesce(projects, '[]'::jsonb)
  );

  RETURN result;
END;
$function$;
