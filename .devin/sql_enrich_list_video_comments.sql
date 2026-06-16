CREATE OR REPLACE FUNCTION public.app_student_list_video_comments(
  p_video_type text,
  p_video_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_type NOT IN ('challenge', 'free') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'video_type', c.video_type,
                'video_id', c.video_id,
                'user_id', c.user_id,
                'display_name', COALESCE(s.full_name, ''),
                'avatar_url', COALESCE(s.avatar_url, ''),
                'content', c.content,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
            ORDER BY c.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.video_comments c
    LEFT JOIN app.students s
      ON s.id = c.user_id
    WHERE c.video_type = v_type
      AND c.video_id = p_video_id
      AND c.is_deleted = FALSE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'comments', v_result);
END;
$$;
