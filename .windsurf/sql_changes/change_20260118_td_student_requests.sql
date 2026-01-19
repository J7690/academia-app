-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Demandes étudiants de TD non proposés
-- Date: 2026-01-18
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Table app.td_student_requests
-- ========================================

CREATE TABLE IF NOT EXISTS app.td_student_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  field_id UUID REFERENCES app.td_fields (id) ON DELETE SET NULL,
  level TEXT,
  subject TEXT NOT NULL,
  description TEXT,
  preferred_modality td_modality,
  preferred_schedule TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending / in_review / planned / converted / rejected
  created_program_id UUID REFERENCES app.td_programs (id) ON DELETE SET NULL,
  handled_by_admin_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_td_student_requests_student
  ON app.td_student_requests (student_id);

CREATE INDEX IF NOT EXISTS idx_td_student_requests_status
  ON app.td_student_requests (status);

-- ========================================
-- 2) RLS pour app.td_student_requests
-- ========================================

ALTER TABLE app.td_student_requests ENABLE ROW LEVEL SECURITY;

-- Admin : accès complet via rôle logique TD
DROP POLICY IF EXISTS td_student_requests_admin_all ON app.td_student_requests;
CREATE POLICY td_student_requests_admin_all
  ON app.td_student_requests
  FOR ALL
  USING (app.app_td_get_current_role() = 'admin')
  WITH CHECK (app.app_td_get_current_role() = 'admin');

-- Étudiants : voir et créer uniquement leurs propres demandes
DROP POLICY IF EXISTS td_student_requests_student_select ON app.td_student_requests;
CREATE POLICY td_student_requests_student_select
  ON app.td_student_requests
  FOR SELECT
  USING (student_id = auth.uid());

DROP POLICY IF EXISTS td_student_requests_student_insert ON app.td_student_requests;
CREATE POLICY td_student_requests_student_insert
  ON app.td_student_requests
  FOR INSERT
  WITH CHECK (student_id = auth.uid());

-- ========================================
-- 3) Grants de base
-- ========================================

GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_student_requests TO authenticated;
GRANT ALL ON app.td_student_requests TO service_role;

-- ========================================
-- 4) RPC étudiant : créer une demande TD
-- ========================================

CREATE OR REPLACE FUNCTION app_td_student_create_request(
  p_subject TEXT,
  p_field_id UUID DEFAULT NULL,
  p_level TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_preferred_modality td_modality DEFAULT NULL,
  p_preferred_schedule TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_request_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'student' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
  END IF;

  IF p_subject IS NULL OR TRIM(p_subject) = '' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_subject');
  END IF;

  INSERT INTO app.td_student_requests (
    student_id,
    field_id,
    level,
    subject,
    description,
    preferred_modality,
    preferred_schedule,
    status,
    created_program_id,
    handled_by_admin_id,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_field_id,
    p_level,
    TRIM(p_subject),
    p_description,
    p_preferred_modality,
    p_preferred_schedule,
    'pending',
    NULL,
    NULL,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_request_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'request_id', v_request_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_create_request(TEXT, UUID, TEXT, TEXT, td_modality, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_create_request(TEXT, UUID, TEXT, TEXT, td_modality, TEXT) TO service_role;

-- ========================================
-- 5) RPC étudiant : lister ses demandes
-- ========================================

CREATE OR REPLACE FUNCTION app_td_student_list_my_requests()
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
  IF v_role <> 'student' THEN
    RAISE EXCEPTION 'not_student';
  END IF;

  RETURN QUERY
  SELECT JSONB_BUILD_OBJECT(
    'id', r.id,
    'student_id', r.student_id,
    'field_id', r.field_id,
    'level', r.level,
    'subject', r.subject,
    'description', r.description,
    'preferred_modality', r.preferred_modality,
    'preferred_schedule', r.preferred_schedule,
    'status', r.status,
    'created_program_id', r.created_program_id,
    'handled_by_admin_id', r.handled_by_admin_id,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  )
  FROM app.td_student_requests r
  WHERE r.student_id = v_user_id
  ORDER BY r.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_student_list_my_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_student_list_my_requests() TO service_role;

-- ========================================
-- 6) RPC admin : lister les demandes étudiants
-- ========================================

CREATE OR REPLACE FUNCTION app_td_admin_list_student_requests(
  p_status TEXT DEFAULT NULL,
  p_field_id UUID DEFAULT NULL,
  p_level TEXT DEFAULT NULL
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
  SELECT JSONB_BUILD_OBJECT(
    'id', r.id,
    'student_id', r.student_id,
    'student_email', su.email,
    'field_id', r.field_id,
    'field_name', f.name,
    'level', r.level,
    'subject', r.subject,
    'description', r.description,
    'preferred_modality', r.preferred_modality,
    'preferred_schedule', r.preferred_schedule,
    'status', r.status,
    'created_program_id', r.created_program_id,
    'created_program_title', p.title,
    'handled_by_admin_id', r.handled_by_admin_id,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  )
  FROM app.td_student_requests r
  LEFT JOIN app.td_fields f ON f.id = r.field_id
  LEFT JOIN app.td_programs p ON p.id = r.created_program_id
  LEFT JOIN auth.users su ON su.id = r.student_id
  WHERE (p_status IS NULL OR r.status = p_status)
    AND (p_field_id IS NULL OR r.field_id = p_field_id)
    AND (p_level IS NULL OR r.level = p_level)
  ORDER BY r.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_list_student_requests(TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_list_student_requests(TEXT, UUID, TEXT) TO service_role;

-- ========================================
-- 7) RPC admin : marquer une demande comme convertie
-- ========================================

CREATE OR REPLACE FUNCTION app_td_admin_mark_request_converted(
  p_request_id UUID,
  p_program_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_request app.td_student_requests%ROWTYPE;
  v_program app.td_programs%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_role := app.app_td_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_request_id IS NULL OR p_program_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_arguments');
  END IF;

  SELECT *
  INTO v_request
  FROM app.td_student_requests
  WHERE id = p_request_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'request_not_found');
  END IF;

  SELECT *
  INTO v_program
  FROM app.td_programs
  WHERE id = p_program_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found');
  END IF;

  UPDATE app.td_student_requests
  SET
    status = 'converted',
    created_program_id = p_program_id,
    handled_by_admin_id = v_user_id,
    updated_at = NOW()
  WHERE id = p_request_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'request_id', p_request_id,
    'program_id', p_program_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_admin_mark_request_converted(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_admin_mark_request_converted(UUID, UUID) TO service_role;
