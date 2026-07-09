-- RPCs worker (public schema)

-- whiteboard_fetch_queued_jobs
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

-- whiteboard_mark_processing
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

-- whiteboard_mark_done
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

-- whiteboard_mark_failed
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

-- whiteboard_get_any_student_id
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
