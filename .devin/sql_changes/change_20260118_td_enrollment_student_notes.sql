-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Personnalisation étudiant sur une inscription TD existante
-- Date: 2026-01-18
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Flux étudiant : inscription TD + paiement avec notes étudiant
-- ========================================

DROP FUNCTION IF EXISTS app_td_student_create_enrollment_and_payment(
  UUID,
  UUID,
  TEXT,
  NUMERIC
);

CREATE OR REPLACE FUNCTION app_td_student_create_enrollment_and_payment(
  p_program_id UUID,
  p_collection_id UUID DEFAULT NULL,
  p_access_scope TEXT DEFAULT 'program',
  p_amount_due NUMERIC(12,2) DEFAULT NULL,
  p_student_notes TEXT DEFAULT NULL
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

  v_role := app.app_td_get_current_role();
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
    p_student_notes,
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

GRANT EXECUTE ON FUNCTION app_td_student_create_enrollment_and_payment(UUID, UUID, TEXT, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_create_enrollment_and_payment(UUID, UUID, TEXT, NUMERIC, TEXT) TO service_role;

-- ========================================
-- 2) Projection des inscriptions: ajouter student_notes (étudiant)
-- ========================================

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
    'payment_amount_paid', pay.amount_paid,
    'student_notes', e.student_notes
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
-- 3) Projection des inscriptions: ajouter student_notes (admin)
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
    'student_notes', e.student_notes,
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
