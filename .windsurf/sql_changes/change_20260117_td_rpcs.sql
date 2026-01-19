-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Phase 2 - Socle Supabase : RPC métier
-- Date: 2026-01-17
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Catalogue public TD (programmes + détails)
-- ========================================

CREATE OR REPLACE FUNCTION app_td_list_public_programs(
  p_field_id UUID DEFAULT NULL,
  p_level TEXT DEFAULT NULL
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';

  IF v_role = 'admin' THEN
    RETURN QUERY
    SELECT JSONB_BUILD_OBJECT(
      'id', p.id,
      'field_id', p.field_id,
      'level', p.level,
      'title', p.title,
      'description', p.description,
      'modality', p.modality,
      'price', p.price,
      'currency', p.currency,
      'status', p.status
    )
    FROM app.td_programs p
    WHERE (p_field_id IS NULL OR p.field_id = p_field_id)
      AND (p_level IS NULL OR p.level = p_level)
    ORDER BY p.title;
  ELSE
    RETURN QUERY
    SELECT JSONB_BUILD_OBJECT(
      'id', p.id,
      'field_id', p.field_id,
      'level', p.level,
      'title', p.title,
      'description', p.description,
      'modality', p.modality,
      'price', p.price,
      'currency', p.currency,
      'status', p.status
    )
    FROM app.td_programs p
    WHERE p.status = 'published'
      AND (p_field_id IS NULL OR p.field_id = p_field_id)
      AND (p_level IS NULL OR p.level = p_level)
    ORDER BY p.title;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_list_public_programs(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_list_public_programs(UUID, TEXT) TO service_role;


CREATE OR REPLACE FUNCTION app_td_get_program_detail(
  p_program_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_program app.td_programs%ROWTYPE;
  v_collections JSONB;
BEGIN
  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';

  IF v_role = 'admin' THEN
    SELECT *
    INTO v_program
    FROM app.td_programs
    WHERE id = p_program_id;
  ELSE
    SELECT *
    INTO v_program
    FROM app.td_programs
    WHERE id = p_program_id
      AND status = 'published';
  END IF;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found_or_not_visible');
  END IF;

  SELECT COALESCE(
           JSONB_AGG(
             JSONB_BUILD_OBJECT(
               'id', c.id,
               'title', c.title,
               'description', c.description,
               'position', c.position,
               'sessions', (
                 SELECT COALESCE(
                          JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                              'id', s.id,
                              'title', s.title,
                              'is_preview', s.is_preview,
                              'position', s.position
                            )
                            ORDER BY s.position
                          ),
                          '[]'::JSONB
                        )
                 FROM app.td_sessions s
                 WHERE s.collection_id = c.id
               )
             )
             ORDER BY c.position
           ),
           '[]'::JSONB
         )
  INTO v_collections
  FROM app.td_collections c
  WHERE c.program_id = p_program_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'program', JSONB_BUILD_OBJECT(
      'id', v_program.id,
      'field_id', v_program.field_id,
      'level', v_program.level,
      'title', v_program.title,
      'description', v_program.description,
      'modality', v_program.modality,
      'price', v_program.price,
      'currency', v_program.currency,
      'status', v_program.status
    ),
    'collections', v_collections
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_get_program_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_get_program_detail(UUID) TO service_role;


-- ========================================
-- 2) Flux Étudiant : inscription TD + paiement
-- ========================================

CREATE OR REPLACE FUNCTION app_td_student_create_enrollment_and_payment(
  p_program_id UUID,
  p_collection_id UUID DEFAULT NULL,
  p_access_scope TEXT DEFAULT 'program',
  p_amount_due NUMERIC(12,2) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_program app.td_programs%ROWTYPE;
  v_dummy_collection app.td_collections%ROWTYPE;
  v_enrollment_id UUID;
  v_payment_id UUID;
  v_reference_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  IF v_role <> 'student' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
  END IF;

  IF p_program_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_program_id');
  END IF;

  IF p_amount_due IS NULL OR p_amount_due <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_due');
  END IF;

  IF p_access_scope NOT IN ('program', 'collection', 'document', 'certification') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_access_scope');
  END IF;

  SELECT *
  INTO v_program
  FROM app.td_programs
  WHERE id = p_program_id
    AND status = 'published';

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found_or_not_published');
  END IF;

  IF p_collection_id IS NOT NULL THEN
    SELECT *
    INTO v_dummy_collection
    FROM app.td_collections
    WHERE id = p_collection_id
      AND program_id = p_program_id;

    IF NOT FOUND THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'collection_not_in_program');
    END IF;
  END IF;

  INSERT INTO app.td_enrollments (
    student_id,
    program_id,
    collection_id,
    access_scope,
    payment_id,
    access_status,
    assignment_status,
    assigned_teacher_id,
    student_notes,
    admin_notes,
    created_at,
    updated_at,
    activated_at,
    completed_at
  ) VALUES (
    v_user_id,
    p_program_id,
    p_collection_id,
    p_access_scope,
    NULL,
    'pending_payment',
    'unassigned',
    NULL,
    NULL,
    NULL,
    NOW(),
    NOW(),
    NULL,
    NULL
  )
  RETURNING id INTO v_enrollment_id;

  v_reference_code := 'TD-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id,
    student_id,
    university_id,
    amount_due,
    currency,
    payment_reason,
    status,
    reference_code,
    created_by
  ) VALUES (
    NULL,
    v_user_id,
    NULL,
    p_amount_due,
    v_program.currency,
    'td_access',
    'pending',
    v_reference_code,
    v_user_id
  )
  RETURNING id INTO v_payment_id;

  UPDATE app.td_enrollments
  SET
    payment_id = v_payment_id,
    updated_at = NOW()
  WHERE id = v_enrollment_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'enrollment_id', v_enrollment_id,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount_due', p_amount_due,
    'currency', v_program.currency
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_create_enrollment_and_payment(UUID, UUID, TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_create_enrollment_and_payment(UUID, UUID, TEXT, NUMERIC) TO service_role;


CREATE OR REPLACE FUNCTION app_td_student_list_my_enrollments()
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
  SELECT JSONB_BUILD_OBJECT(
    'id', e.id,
    'student_id', e.student_id,
    'program_id', e.program_id,
    'collection_id', e.collection_id,
    'access_scope', e.access_scope,
    'access_status', e.access_status,
    'assignment_status', e.assignment_status,
    'assigned_teacher_id', e.assigned_teacher_id,
    'created_at', e.created_at,
    'updated_at', e.updated_at,
    'activated_at', e.activated_at,
    'completed_at', e.completed_at,
    'program_title', p.title,
    'program_level', p.level,
    'program_modality', p.modality,
    'price', p.price,
    'currency', p.currency,
    'payment_id', e.payment_id,
    'payment_status', pay.status,
    'payment_reference', pay.reference_code,
    'payment_amount_due', pay.amount_due,
    'payment_amount_paid', pay.amount_paid
  )
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  LEFT JOIN app.application_payments pay ON pay.id = e.payment_id
  WHERE e.student_id = v_user_id
  ORDER BY e.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_list_my_enrollments() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_list_my_enrollments() TO service_role;


-- ========================================
-- 3) Flux Enseignant : missions assignées
-- ========================================

CREATE OR REPLACE FUNCTION app_td_teacher_list_assignments()
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

  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
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
  SELECT JSONB_BUILD_OBJECT(
    'id', e.id,
    'student_id', e.student_id,
    'program_id', e.program_id,
    'collection_id', e.collection_id,
    'access_scope', e.access_scope,
    'access_status', e.access_status,
    'assignment_status', e.assignment_status,
    'created_at', e.created_at,
    'activated_at', e.activated_at,
    'completed_at', e.completed_at,
    'program_title', p.title,
    'program_level', p.level,
    'program_modality', p.modality
  )
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  WHERE e.assigned_teacher_id = v_teacher_id
  ORDER BY e.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_teacher_list_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_teacher_list_assignments() TO service_role;


-- ========================================
-- 4) Flux Admin : liste + affectation enseignant
-- ========================================

CREATE OR REPLACE FUNCTION app_td_admin_list_enrollments_with_context()
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

  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  RETURN QUERY
  SELECT JSONB_BUILD_OBJECT(
    'id', e.id,
    'student_id', e.student_id,
    'student_email', su.email,
    'program_id', e.program_id,
    'program_title', p.title,
    'field_id', p.field_id,
    'level', p.level,
    'access_scope', e.access_scope,
    'access_status', e.access_status,
    'assignment_status', e.assignment_status,
    'assigned_teacher_id', e.assigned_teacher_id,
    'teacher_name', t.full_name,
    'payment_id', e.payment_id,
    'payment_status', pay.status,
    'payment_reference', pay.reference_code,
    'payment_amount_due', pay.amount_due,
    'payment_amount_paid', pay.amount_paid,
    'created_at', e.created_at,
    'updated_at', e.updated_at,
    'activated_at', e.activated_at,
    'completed_at', e.completed_at
  )
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  LEFT JOIN app.td_teachers t ON t.id = e.assigned_teacher_id
  LEFT JOIN auth.users su ON su.id = e.student_id
  LEFT JOIN app.application_payments pay ON pay.id = e.payment_id
  ORDER BY e.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_list_enrollments_with_context() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_list_enrollments_with_context() TO service_role;


CREATE OR REPLACE FUNCTION app_td_admin_assign_teacher(
  p_enrollment_id UUID,
  p_td_teacher_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_enrollment app.td_enrollments%ROWTYPE;
  v_teacher app.td_teachers%ROWTYPE;
  v_payment app.application_payments%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_enrollment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_enrollment_id');
  END IF;

  IF p_td_teacher_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_teacher_id');
  END IF;

  SELECT *
  INTO v_enrollment
  FROM app.td_enrollments
  WHERE id = p_enrollment_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'enrollment_not_found');
  END IF;

  SELECT *
  INTO v_teacher
  FROM app.td_teachers
  WHERE id = p_td_teacher_id
    AND status = 'active';

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'teacher_not_found_or_inactive');
  END IF;

  IF v_enrollment.payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_missing');
  END IF;

  SELECT *
  INTO v_payment
  FROM app.application_payments
  WHERE id = v_enrollment.payment_id;

  IF NOT FOUND OR v_payment.status <> 'confirmed' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_confirmed');
  END IF;

  IF v_enrollment.assignment_status = 'closed' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'enrollment_closed');
  END IF;

  UPDATE app.td_enrollments
  SET
    assigned_teacher_id = v_teacher.id,
    assignment_status = 'assigned',
    access_status = 'active',
    activated_at = COALESCE(activated_at, NOW()),
    updated_at = NOW()
  WHERE id = p_enrollment_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_assign_teacher(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_assign_teacher(UUID, UUID) TO service_role;


-- ========================================
-- 5) Messagerie centrale TD
-- ========================================

CREATE OR REPLACE FUNCTION app_td_list_messages_for_enrollment(
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
  v_teacher app.td_teachers%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';

  SELECT *
  INTO v_enrollment
  FROM app.td_enrollments
  WHERE id = p_enrollment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'enrollment_not_found';
  END IF;

  IF v_role = 'admin' THEN
    NULL; -- accès total
  ELSIF v_role = 'student' THEN
    IF v_enrollment.student_id <> v_user_id THEN
      RAISE EXCEPTION 'not_authorized';
    END IF;
  ELSIF v_role = 'teacher' THEN
    IF v_enrollment.assigned_teacher_id IS NULL THEN
      RAISE EXCEPTION 'not_authorized';
    END IF;

    SELECT *
    INTO v_teacher
    FROM app.td_teachers t
    WHERE t.id = v_enrollment.assigned_teacher_id
      AND t.user_id = v_user_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_authorized';
    END IF;
  ELSE
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
  SELECT JSONB_BUILD_OBJECT(
    'id', m.id,
    'td_enrollment_id', m.td_enrollment_id,
    'thread_type', m.thread_type,
    'sender_role', m.sender_role,
    'sender_user_id', m.sender_user_id,
    'content', m.content,
    'attachment_url', m.attachment_url,
    'created_at', m.created_at,
    'read_at', m.read_at
  )
  FROM app.td_messages m
  WHERE m.td_enrollment_id = p_enrollment_id
  ORDER BY m.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_list_messages_for_enrollment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_list_messages_for_enrollment(UUID) TO service_role;


CREATE OR REPLACE FUNCTION app_td_send_message(
  p_enrollment_id UUID,
  p_thread_type TEXT,
  p_content TEXT,
  p_attachment_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_enrollment app.td_enrollments%ROWTYPE;
  v_teacher_user_id UUID;
  v_message_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';

  IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
  END IF;

  IF p_thread_type NOT IN ('student_admin', 'teacher_admin') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_thread_type');
  END IF;

  SELECT *
  INTO v_enrollment
  FROM app.td_enrollments
  WHERE id = p_enrollment_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'enrollment_not_found');
  END IF;

  IF v_role = 'student' THEN
    IF v_enrollment.student_id <> v_user_id THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student_of_enrollment');
    END IF;

    IF p_thread_type <> 'student_admin' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_thread_for_student');
    END IF;
  ELSIF v_role = 'teacher' THEN
    IF v_enrollment.assigned_teacher_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_teacher_assigned');
    END IF;

    SELECT user_id
    INTO v_teacher_user_id
    FROM app.td_teachers t
    WHERE t.id = v_enrollment.assigned_teacher_id;

    IF v_teacher_user_id IS NULL OR v_teacher_user_id <> v_user_id THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_teacher_of_enrollment');
    END IF;

    IF p_thread_type <> 'teacher_admin' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_thread_for_teacher');
    END IF;
  ELSIF v_role = 'admin' THEN
    -- l'admin peut écrire sur les deux fils, en fonction de p_thread_type
    NULL;
  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'role_not_allowed');
  END IF;

  INSERT INTO app.td_messages (
    td_enrollment_id,
    thread_type,
    student_user_id,
    teacher_user_id,
    admin_user_id,
    sender_role,
    sender_user_id,
    content,
    attachment_url,
    created_at
  ) VALUES (
    v_enrollment.id,
    p_thread_type,
    v_enrollment.student_id,
    CASE
      WHEN v_enrollment.assigned_teacher_id IS NOT NULL THEN
        (SELECT user_id FROM app.td_teachers WHERE id = v_enrollment.assigned_teacher_id)
      ELSE NULL
    END,
    CASE WHEN v_role = 'admin' THEN v_user_id ELSE NULL END,
    v_role,
    v_user_id,
    p_content,
    p_attachment_url,
    NOW()
  )
  RETURNING id INTO v_message_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'message_id', v_message_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_send_message(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_send_message(UUID, TEXT, TEXT, TEXT) TO service_role;
