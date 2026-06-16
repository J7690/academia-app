-- Live session replays RPCs (VideoAsset-only for replay videos)
-- À appliquer via admin_execute_sql (script .windsurf/apply_one_sql_via_admin_rpc.py)

-- 1) CI upsert live session (VideoAsset-only pour le replay)

-- On supprime l'ancien shim legacy (p_replay_video_url)
DROP FUNCTION IF EXISTS public.app_ci_upsert_online_course_live_session(
  p_session_id uuid,
  p_course_id uuid,
  p_lesson_id uuid,
  p_title text,
  p_description text,
  p_provider text,
  p_join_url text,
  p_start_at timestamp with time zone,
  p_end_at timestamp with time zone,
  p_replay_video_url text,
  p_is_active boolean
) CASCADE;


CREATE OR REPLACE FUNCTION public.app_ci_upsert_online_course_live_session(
  p_session_id UUID,
  p_course_id UUID,
  p_lesson_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_provider TEXT,
  p_join_url TEXT,
  p_start_at TIMESTAMPTZ,
  p_end_at TIMESTAMPTZ,
  p_replay_video_asset_id UUID,
  p_playback JSONB,
  p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_role       TEXT;
  v_session_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'instructor' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
  END IF;

  IF p_course_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_course_id');
  END IF;

  IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
  END IF;

  IF p_start_at IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_start_at');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM app.online_course_instructors ci
    WHERE ci.course_id = p_course_id
      AND ci.instructor_id = v_user_id
  ) THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
  END IF;

  IF p_session_id IS NULL THEN
    INSERT INTO app.online_course_live_sessions (
      course_id,
      lesson_id,
      title,
      description,
      provider,
      join_url,
      start_at,
      end_at,
      replay_video_asset_id,
      is_active
    ) VALUES (
      p_course_id,
      p_lesson_id,
      p_title,
      p_description,
      p_provider,
      p_join_url,
      p_start_at,
      p_end_at,
      p_replay_video_asset_id,
      COALESCE(p_is_active, TRUE)
    )
    RETURNING id INTO v_session_id;
  ELSE
    UPDATE app.online_course_live_sessions s
    SET
      title                = p_title,
      description          = p_description,
      provider             = p_provider,
      join_url             = p_join_url,
      start_at             = p_start_at,
      end_at               = p_end_at,
      replay_video_asset_id = p_replay_video_asset_id,
      is_active            = COALESCE(p_is_active, is_active),
      updated_at           = NOW()
    WHERE s.id = p_session_id
      AND s.course_id = p_course_id
      AND EXISTS (
        SELECT 1 FROM app.online_course_instructors ci
        WHERE ci.course_id = s.course_id
          AND ci.instructor_id = v_user_id
      )
    RETURNING id INTO v_session_id;
  END IF;

  IF v_session_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_saved_or_not_owned');
  END IF;

  -- Contexte VideoAsset pour le replay (si fourni)
  IF p_replay_video_asset_id IS NOT NULL THEN
    INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
    VALUES (p_replay_video_asset_id, 'online_course_live_session', v_session_id, 'replay')
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  ELSE
    DELETE FROM app.video_asset_contexts
    WHERE context_type = 'online_course_live_session'
      AND context_id = v_session_id
      AND role = 'replay';
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'session_id', v_session_id,
    'replay_video_asset_id', p_replay_video_asset_id,
    'replay_playback', CASE
      WHEN p_replay_video_asset_id IS NOT NULL THEN JSONB_BUILD_OBJECT(
        'best_url',   p_playback->>'best_url',
        'poster_url', p_playback->>'poster_url'
      )
      ELSE NULL
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ci_upsert_online_course_live_session(
  UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, UUID, JSONB, BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ci_upsert_online_course_live_session(
  UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, UUID, JSONB, BOOLEAN
) TO service_role;


-- 2) RPC de lecture des lives : ajout des champs replay_video_asset_id + replay_playback (VideoAsset-only)

CREATE OR REPLACE FUNCTION public.app_admin_list_online_course_live_sessions(
  p_status TEXT DEFAULT NULL,
  p_course_id UUID DEFAULT NULL,
  p_instructor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', s.id,
        'course_id', s.course_id,
        'course_title', c.title,
        'host_id', s.host_id,
        'title', s.title,
        'description', s.description,
        'provider', s.provider,
        'join_url', s.join_url,
        'start_at', s.start_at,
        'end_at', s.end_at,
        'started_at', s.started_at,
        'ended_at', s.ended_at,
        'status', s.status,
        -- legacy (conservé mais non utilisé pour playback)
        'replay_video_url', s.replay_video_url,
        -- nouveau canonique VideoAsset
        'replay_video_asset_id', s.replay_video_asset_id,
        'replay_playback', JSONB_BUILD_OBJECT(
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = s.replay_video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = s.replay_video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        ),
        'is_active', s.is_active,
        'created_at', s.created_at,
        'updated_at', s.updated_at
      )
      ORDER BY s.start_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.online_course_live_sessions s
  JOIN app.online_courses c ON c.id = s.course_id
  WHERE (p_status IS NULL OR s.status = p_status)
    AND (p_course_id IS NULL OR s.course_id = p_course_id)
    AND (
      p_instructor_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM app.online_course_instructors ci
        WHERE ci.course_id = s.course_id
          AND ci.instructor_id = p_instructor_id
      )
    );

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_online_course_live_sessions(TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_online_course_live_sessions(TEXT, UUID, UUID) TO service_role;


CREATE OR REPLACE FUNCTION public.app_student_list_my_online_course_live_sessions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', s.id,
        'course_id', s.course_id,
        'title', s.title,
        'description', s.description,
        'provider', s.provider,
        'join_url', s.join_url,
        'start_at', s.start_at,
        'end_at', s.end_at,
        'status', s.status,
        -- legacy (conservé)
        'replay_video_url', s.replay_video_url,
        -- nouveau canonique
        'replay_video_asset_id', s.replay_video_asset_id,
        'replay_playback', JSONB_BUILD_OBJECT(
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = s.replay_video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = s.replay_video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        ),
        'is_active', s.is_active,
        'course_title', c.title
      )
      ORDER BY s.start_at ASC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.online_course_live_sessions s
  JOIN app.online_course_enrollments e ON e.course_id = s.course_id
  JOIN app.online_courses c ON c.id = s.course_id
  WHERE e.student_id = v_user_id
    AND s.is_active = TRUE
    AND s.status IN ('approved', 'running');

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_my_online_course_live_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_list_my_online_course_live_sessions() TO service_role;


CREATE OR REPLACE FUNCTION public.app_ci_list_my_online_course_live_sessions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'instructor' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', s.id,
        'course_id', s.course_id,
        'lesson_id', s.lesson_id,
        'title', s.title,
        'description', s.description,
        'provider', s.provider,
        'join_url', s.join_url,
        'start_at', s.start_at,
        'end_at', s.end_at,
        -- legacy (conservé)
        'replay_video_url', s.replay_video_url,
        -- nouveau canonique
        'replay_video_asset_id', s.replay_video_asset_id,
        'replay_playback', JSONB_BUILD_OBJECT(
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = s.replay_video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = s.replay_video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        ),
        'is_active', s.is_active,
        'status', s.status,
        'started_at', s.started_at,
        'ended_at', s.ended_at,
        'course_title', c.title
      )
      ORDER BY s.start_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.online_course_live_sessions s
  JOIN app.online_course_instructors ci ON ci.course_id = s.course_id
  JOIN app.online_courses c ON c.id = s.course_id
  WHERE ci.instructor_id = v_user_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ci_list_my_online_course_live_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ci_list_my_online_course_live_sessions() TO service_role;
