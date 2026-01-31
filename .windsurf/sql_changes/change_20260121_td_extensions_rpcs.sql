-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Extensions RPC TD : dashboards, ressources, séances, présence
-- Date: 2026-01-21
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- 1) Dashboard étudiant

CREATE OR REPLACE FUNCTION app_td_student_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_enrollments JSONB;
  v_next_sessions JSONB;
  v_unread_messages_count INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'student' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_student');
  END IF;

  -- Inscriptions de l'étudiant
  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'id', e.id,
               'program_id', e.program_id,
               'program_title', p.title,
               'access_status', e.access_status,
               'assignment_status', e.assignment_status,
               'student_notes', e.student_notes,
               'activated_at', e.activated_at,
               'completed_at', e.completed_at
             )
             ORDER BY e.created_at DESC
           ),
           '[]'::jsonb
         )
  INTO v_enrollments
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  WHERE e.student_id = v_user_id;

  -- Prochaines séances
  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'occurrence_id', o.id,
               'enrollment_id', o.enrollment_id,
               'session_id', o.session_id,
               'scheduled_at', o.scheduled_at,
               'duration_minutes', o.duration_minutes,
               'status', o.status
             )
             ORDER BY o.scheduled_at
           ),
           '[]'::jsonb
         )
  INTO v_next_sessions
  FROM app.td_session_occurrences o
  JOIN app.td_enrollments e ON e.id = o.enrollment_id
  WHERE e.student_id = v_user_id
    AND o.status IN ('planned','confirmed')
    AND o.scheduled_at >= now();

  -- Messages non lus (thread étudiant-admin)
  SELECT COALESCE(COUNT(*), 0)
  INTO v_unread_messages_count
  FROM app.td_messages m
  WHERE m.student_user_id = v_user_id
    AND m.sender_user_id <> v_user_id
    AND m.read_at IS NULL;

  RETURN jsonb_build_object(
    'success', TRUE,
    'enrollments', v_enrollments,
    'next_sessions', v_next_sessions,
    'unread_messages_count', v_unread_messages_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_get_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_get_dashboard() TO service_role;


-- 2) Dashboard enseignant

CREATE OR REPLACE FUNCTION app_td_teacher_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_teacher_id UUID;
  v_assignments JSONB;
  v_next_sessions JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'teacher' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_teacher');
  END IF;

  SELECT id
  INTO v_teacher_id
  FROM app.td_teachers
  WHERE user_id = v_user_id
    AND status = 'active';

  IF v_teacher_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'teacher_not_found_or_inactive');
  END IF;

  -- Inscriptions assignées
  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'id', e.id,
               'student_id', e.student_id,
               'program_id', e.program_id,
               'program_title', p.title,
               'access_status', e.access_status,
               'assignment_status', e.assignment_status,
               'activated_at', e.activated_at,
               'completed_at', e.completed_at
             )
             ORDER BY e.created_at DESC
           ),
           '[]'::jsonb
         )
  INTO v_assignments
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  WHERE e.assigned_teacher_id = v_teacher_id;

  -- Prochaines séances
  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'occurrence_id', o.id,
               'enrollment_id', o.enrollment_id,
               'session_id', o.session_id,
               'scheduled_at', o.scheduled_at,
               'duration_minutes', o.duration_minutes,
               'status', o.status
             )
             ORDER BY o.scheduled_at
           ),
           '[]'::jsonb
         )
  INTO v_next_sessions
  FROM app.td_session_occurrences o
  WHERE o.teacher_id = v_teacher_id
    AND o.status IN ('planned','confirmed')
    AND o.scheduled_at >= now();

  RETURN jsonb_build_object(
    'success', TRUE,
    'assignments', v_assignments,
    'next_sessions', v_next_sessions
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_teacher_get_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_teacher_get_dashboard() TO service_role;


-- 3) Dashboard admin

CREATE OR REPLACE FUNCTION app_td_admin_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_counts JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT jsonb_build_object(
           'programs_published', (
             SELECT COUNT(*) FROM app.td_programs p WHERE p.status = 'published'
           ),
           'enrollments_pending_payment', (
             SELECT COUNT(*) FROM app.td_enrollments e WHERE e.access_status = 'pending_payment'
           ),
           'enrollments_waiting_admin', (
             SELECT COUNT(*) FROM app.td_enrollments e WHERE e.access_status = 'waiting_admin'
           ),
           'enrollments_active', (
             SELECT COUNT(*) FROM app.td_enrollments e WHERE e.access_status = 'active'
           ),
           'student_requests_pending', (
             SELECT COUNT(*) FROM app.td_student_requests r WHERE r.status = 'pending'
           ),
           'upcoming_sessions', (
             SELECT COUNT(*) FROM app.td_session_occurrences o
             WHERE o.status IN ('planned','confirmed')
               AND o.scheduled_at >= now()
           )
         )
  INTO v_counts;

  RETURN jsonb_build_object('success', TRUE, 'counts', v_counts);
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_get_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_get_dashboard() TO service_role;


-- 4) Ressources TD pour une inscription (étudiant)

CREATE OR REPLACE FUNCTION app_td_student_list_resources_for_enrollment(
  p_enrollment_id UUID
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_enrollment app.td_enrollments%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'student' THEN
    RAISE EXCEPTION 'not_student';
  END IF;

  SELECT *
  INTO v_enrollment
  FROM app.td_enrollments e
  WHERE e.id = p_enrollment_id
    AND e.student_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'enrollment_not_found_or_not_owned';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
           'id', r.id,
           'program_id', r.program_id,
           'collection_id', r.collection_id,
           'session_id', r.session_id,
           'title', r.title,
           'description', r.description,
           'kind', r.kind,
           'url', r.url,
           'is_required', r.is_required,
           'position', r.position
         )
  FROM app.td_resources r
  WHERE (r.program_id = v_enrollment.program_id
         OR (v_enrollment.collection_id IS NOT NULL AND r.collection_id = v_enrollment.collection_id));
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_list_resources_for_enrollment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_list_resources_for_enrollment(UUID) TO service_role;


-- 5) Ressources TD pour une inscription (enseignant)

CREATE OR REPLACE FUNCTION app_td_teacher_list_resources_for_enrollment(
  p_enrollment_id UUID
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_teacher_id UUID;
  v_enrollment app.td_enrollments%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'teacher' THEN
    RAISE EXCEPTION 'not_teacher';
  END IF;

  SELECT id
  INTO v_teacher_id
  FROM app.td_teachers
  WHERE user_id = v_user_id
    AND status = 'active';

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'teacher_not_found_or_inactive';
  END IF;

  SELECT *
  INTO v_enrollment
  FROM app.td_enrollments e
  WHERE e.id = p_enrollment_id
    AND e.assigned_teacher_id = v_teacher_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'enrollment_not_found_or_not_assigned_to_teacher';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
           'id', r.id,
           'program_id', r.program_id,
           'collection_id', r.collection_id,
           'session_id', r.session_id,
           'title', r.title,
           'description', r.description,
           'kind', r.kind,
           'url', r.url,
           'is_required', r.is_required,
           'position', r.position
         )
  FROM app.td_resources r
  WHERE (r.program_id = v_enrollment.program_id
         OR (v_enrollment.collection_id IS NOT NULL AND r.collection_id = v_enrollment.collection_id));
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_teacher_list_resources_for_enrollment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_teacher_list_resources_for_enrollment(UUID) TO service_role;


-- 6) Séances : occurrences côté étudiant

CREATE OR REPLACE FUNCTION app_td_student_list_my_session_occurrences()
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
           'occurrence_id', o.id,
           'enrollment_id', o.enrollment_id,
           'session_id', o.session_id,
           'scheduled_at', o.scheduled_at,
           'duration_minutes', o.duration_minutes,
           'status', o.status
         )
  FROM app.td_session_occurrences o
  JOIN app.td_enrollments e ON e.id = o.enrollment_id
  WHERE e.student_id = v_user_id
  ORDER BY o.scheduled_at;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_list_my_session_occurrences() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_list_my_session_occurrences() TO service_role;


-- 7) Séances : prochaines séances côté enseignant

CREATE OR REPLACE FUNCTION app_td_teacher_list_upcoming_sessions(
  p_from TIMESTAMPTZ DEFAULT now(),
  p_to   TIMESTAMPTZ DEFAULT (now() + INTERVAL '7 days')
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_teacher_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'teacher' THEN
    RAISE EXCEPTION 'not_teacher';
  END IF;

  SELECT id
  INTO v_teacher_id
  FROM app.td_teachers
  WHERE user_id = v_user_id
    AND status = 'active';

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'teacher_not_found_or_inactive';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
           'occurrence_id', o.id,
           'enrollment_id', o.enrollment_id,
           'session_id', o.session_id,
           'scheduled_at', o.scheduled_at,
           'duration_minutes', o.duration_minutes,
           'status', o.status
         )
  FROM app.td_session_occurrences o
  WHERE o.teacher_id = v_teacher_id
    AND o.scheduled_at >= p_from
    AND o.scheduled_at <= p_to
  ORDER BY o.scheduled_at;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_teacher_list_upcoming_sessions(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_teacher_list_upcoming_sessions(TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;


-- 8) Présence : mise à jour par l'enseignant

CREATE OR REPLACE FUNCTION app_td_teacher_update_attendance(
  p_occurrence_id UUID,
  p_student_id    UUID,
  p_status        td_attendance_status,
  p_comment       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_teacher_id UUID;
  v_occurrence app.td_session_occurrences%ROWTYPE;
  v_attendance_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'teacher' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_teacher');
  END IF;

  SELECT id
  INTO v_teacher_id
  FROM app.td_teachers
  WHERE user_id = v_user_id
    AND status = 'active';

  IF v_teacher_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'teacher_not_found_or_inactive');
  END IF;

  SELECT *
  INTO v_occurrence
  FROM app.td_session_occurrences o
  WHERE o.id = p_occurrence_id
    AND o.teacher_id = v_teacher_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'occurrence_not_found_or_not_owned');
  END IF;

  -- Vérifier que l'étudiant appartient à l'inscription
  IF NOT EXISTS (
    SELECT 1
    FROM app.td_enrollments e
    WHERE e.id = v_occurrence.enrollment_id
      AND e.student_id = p_student_id
  ) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'student_not_in_enrollment');
  END IF;

  -- Upsert présence
  INSERT INTO app.td_attendance (
    occurrence_id, student_id, status, joined_at, left_at, comment, created_by
  ) VALUES (
    p_occurrence_id,
    p_student_id,
    p_status,
    NULL,
    NULL,
    p_comment,
    v_user_id
  )
  ON CONFLICT (occurrence_id, student_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    comment = EXCLUDED.comment,
    updated_at = NOW(),
    created_by = v_user_id
  RETURNING id INTO v_attendance_id;

  RETURN jsonb_build_object('success', TRUE, 'attendance_id', v_attendance_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_teacher_update_attendance(UUID, UUID, td_attendance_status, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_teacher_update_attendance(UUID, UUID, td_attendance_status, TEXT) TO service_role;


-- 9) Admin : création / mise à jour d'une occurrence de séance

CREATE OR REPLACE FUNCTION app_td_admin_upsert_session_occurrence(
  p_occurrence_id   UUID,
  p_session_id      UUID,
  p_enrollment_id   UUID,
  p_teacher_id      UUID,
  p_scheduled_at    TIMESTAMPTZ,
  p_duration_minutes INTEGER,
  p_status          td_session_occurrence_status DEFAULT 'planned',
  p_location        TEXT DEFAULT NULL,
  p_meeting_url     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_occurrence_id IS NULL THEN
    INSERT INTO app.td_session_occurrences (
      session_id,
      enrollment_id,
      teacher_id,
      scheduled_at,
      duration_minutes,
      status,
      location,
      meeting_url,
      created_by
    ) VALUES (
      p_session_id,
      p_enrollment_id,
      p_teacher_id,
      p_scheduled_at,
      p_duration_minutes,
      p_status,
      p_location,
      p_meeting_url,
      v_user_id
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE app.td_session_occurrences
    SET
      session_id = p_session_id,
      enrollment_id = p_enrollment_id,
      teacher_id = p_teacher_id,
      scheduled_at = p_scheduled_at,
      duration_minutes = p_duration_minutes,
      status = p_status,
      location = p_location,
      meeting_url = p_meeting_url,
      updated_at = NOW()
    WHERE id = p_occurrence_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'occurrence_not_found');
    END IF;
  END IF;

  RETURN jsonb_build_object('success', TRUE, 'occurrence_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_upsert_session_occurrence(UUID, UUID, UUID, UUID, TIMESTAMPTZ, INTEGER, td_session_occurrence_status, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_upsert_session_occurrence(UUID, UUID, UUID, UUID, TIMESTAMPTZ, INTEGER, td_session_occurrence_status, TEXT, TEXT) TO service_role;


-- 10) Admin : annuler une occurrence de séance

CREATE OR REPLACE FUNCTION app_td_admin_cancel_session_occurrence(
  p_occurrence_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  UPDATE app.td_session_occurrences
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_occurrence_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'occurrence_not_found');
  END IF;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_cancel_session_occurrence(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_cancel_session_occurrence(UUID) TO service_role;


-- 11) Admin : liste des occurrences de séances

CREATE OR REPLACE FUNCTION app_td_admin_list_session_occurrences(
  p_teacher_id  UUID DEFAULT NULL,
  p_student_id  UUID DEFAULT NULL,
  p_from        TIMESTAMPTZ DEFAULT NULL,
  p_to          TIMESTAMPTZ DEFAULT NULL
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
           'occurrence_id', o.id,
           'enrollment_id', o.enrollment_id,
           'session_id', o.session_id,
           'teacher_id', o.teacher_id,
           'scheduled_at', o.scheduled_at,
           'duration_minutes', o.duration_minutes,
           'status', o.status,
           'location', o.location,
           'meeting_url', o.meeting_url
         )
  FROM app.td_session_occurrences o
  JOIN app.td_enrollments e ON e.id = o.enrollment_id
  JOIN app.td_teachers t ON t.id = o.teacher_id
  WHERE (p_teacher_id IS NULL OR o.teacher_id = p_teacher_id)
    AND (p_student_id IS NULL OR e.student_id = p_student_id)
    AND (p_from IS NULL OR o.scheduled_at >= p_from)
    AND (p_to IS NULL OR o.scheduled_at <= p_to)
  ORDER BY o.scheduled_at;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_list_session_occurrences(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_list_session_occurrences(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;
