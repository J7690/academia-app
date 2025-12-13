-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 5)
-- Paywall / entitlements (MVP)
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Entitlements table
-- ========================================

CREATE TABLE IF NOT EXISTS app.user_feature_entitlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_key TEXT NOT NULL,
  granted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB,
  UNIQUE(user_id, feature_key)
);

ALTER TABLE app.user_feature_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_select_own_feature_entitlements ON app.user_feature_entitlements;
CREATE POLICY user_select_own_feature_entitlements
ON app.user_feature_entitlements
FOR SELECT
USING (user_id = auth.uid());

GRANT SELECT ON app.user_feature_entitlements TO authenticated;
GRANT ALL ON app.user_feature_entitlements TO service_role;

-- ========================================
-- 2) Feature access check RPC
-- ========================================

CREATE OR REPLACE FUNCTION app_has_feature_access(
  p_feature_key TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_ok BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  -- Admins always allowed
  IF v_role = 'admin' THEN
    RETURN TRUE;
  END IF;

  SELECT EXISTS(
    SELECT 1
    FROM app.user_feature_entitlements e
    WHERE e.user_id = v_user_id
      AND e.feature_key = p_feature_key
      AND e.is_active = TRUE
      AND (e.expires_at IS NULL OR e.expires_at > NOW())
  ) INTO v_ok;

  RETURN COALESCE(v_ok, FALSE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_has_feature_access(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_has_feature_access(TEXT) TO service_role;

-- ========================================
-- 3) Admin RPC: grant/revoke feature access (for testing / MVP)
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_grant_feature_access(
  p_user_id UUID,
  p_feature_key TEXT,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
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
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  INSERT INTO app.user_feature_entitlements(
    user_id,
    feature_key,
    granted_by,
    expires_at,
    is_active,
    granted_at
  ) VALUES (
    p_user_id,
    p_feature_key,
    v_user_id,
    p_expires_at,
    TRUE,
    NOW()
  )
  ON CONFLICT (user_id, feature_key)
  DO UPDATE SET
    granted_by = EXCLUDED.granted_by,
    expires_at = EXCLUDED.expires_at,
    is_active = TRUE,
    granted_at = NOW();

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_grant_feature_access(UUID, TEXT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_grant_feature_access(UUID, TEXT, TIMESTAMPTZ) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_revoke_feature_access(
  p_user_id UUID,
  p_feature_key TEXT
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
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  UPDATE app.user_feature_entitlements
  SET is_active = FALSE
  WHERE user_id = p_user_id
    AND feature_key = p_feature_key;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_revoke_feature_access(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_revoke_feature_access(UUID, TEXT) TO service_role;

-- ========================================
-- 4) Tighten RLS for prep_* (students need entitlement)
-- ========================================

-- Subjects
DROP POLICY IF EXISTS public_select_active_prep_subjects ON app.prep_subjects;
CREATE POLICY public_select_active_prep_subjects
ON app.prep_subjects FOR SELECT
USING (
  is_active = TRUE
  AND app_has_feature_access('prep_concours')
);

-- Chapters
DROP POLICY IF EXISTS public_select_active_prep_chapters ON app.prep_chapters;
CREATE POLICY public_select_active_prep_chapters
ON app.prep_chapters FOR SELECT
USING (
  is_active = TRUE
  AND app_has_feature_access('prep_concours')
);

-- Questions
DROP POLICY IF EXISTS public_select_published_prep_questions ON app.prep_questions;
CREATE POLICY public_select_published_prep_questions
ON app.prep_questions FOR SELECT
USING (
  is_published = TRUE
  AND app_has_feature_access('prep_concours')
);

-- Choices
DROP POLICY IF EXISTS public_select_published_prep_question_choices ON app.prep_question_choices;
CREATE POLICY public_select_published_prep_question_choices
ON app.prep_question_choices FOR SELECT
USING (
  app_has_feature_access('prep_concours')
  AND EXISTS (
    SELECT 1 FROM app.prep_questions q
    WHERE q.id = prep_question_choices.question_id
      AND q.is_published = TRUE
  )
);

-- Attempts
DROP POLICY IF EXISTS student_select_own_prep_attempts ON app.prep_attempts;
CREATE POLICY student_select_own_prep_attempts
ON app.prep_attempts FOR SELECT
USING (
  student_id = auth.uid()
  AND app_has_feature_access('prep_concours')
);

DROP POLICY IF EXISTS student_insert_own_prep_attempts ON app.prep_attempts;
CREATE POLICY student_insert_own_prep_attempts
ON app.prep_attempts FOR INSERT
WITH CHECK (
  student_id = auth.uid()
  AND app_has_feature_access('prep_concours')
);

-- Exams
DROP POLICY IF EXISTS public_select_published_prep_exams ON app.prep_exams;
CREATE POLICY public_select_published_prep_exams
ON app.prep_exams FOR SELECT
USING (
  is_published = TRUE
  AND app_has_feature_access('prep_concours')
);

DROP POLICY IF EXISTS public_select_published_prep_exam_items ON app.prep_exam_items;
CREATE POLICY public_select_published_prep_exam_items
ON app.prep_exam_items FOR SELECT
USING (
  app_has_feature_access('prep_concours')
  AND EXISTS (
    SELECT 1 FROM app.prep_exams e
    WHERE e.id = prep_exam_items.exam_id
      AND e.is_published = TRUE
  )
);
