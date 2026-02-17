-- ========================================
-- ACADEMIA - ADMIN DELETED USERS ARCHIVE + LIST RPC
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE: app.admin_deleted_users_archive
-- ========================================

CREATE TABLE IF NOT EXISTS app.admin_deleted_users_archive (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  email TEXT NOT NULL,
  role TEXT,
  full_name TEXT,
  original_university_id UUID,
  original_metadata JSONB,
  original_created_at TIMESTAMPTZ,
  original_last_sign_in_at TIMESTAMPTZ,
  deleted_reason TEXT,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_by UUID
);

ALTER TABLE app.admin_deleted_users_archive ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_admin_deleted_users_archive ON app.admin_deleted_users_archive;
CREATE POLICY admin_all_admin_deleted_users_archive
ON app.admin_deleted_users_archive
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.admin_deleted_users_archive TO authenticated;
GRANT ALL ON app.admin_deleted_users_archive TO service_role;

CREATE INDEX IF NOT EXISTS admin_deleted_users_archive_email_idx
  ON app.admin_deleted_users_archive(email);

CREATE INDEX IF NOT EXISTS admin_deleted_users_archive_deleted_at_idx
  ON app.admin_deleted_users_archive(deleted_at DESC);

-- ========================================
-- 2) RPC: app_admin_list_deleted_users
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_deleted_users(
  p_limit INT DEFAULT 200,
  p_offset INT DEFAULT 0
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
        'id', d.id,
        'user_id', d.user_id,
        'email', d.email,
        'role', d.role,
        'full_name', d.full_name,
        'original_university_id', d.original_university_id,
        'deleted_reason', d.deleted_reason,
        'deleted_at', d.deleted_at,
        'deleted_by', d.deleted_by
      )
      ORDER BY d.deleted_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.admin_deleted_users_archive d
  ORDER BY d.deleted_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 200), 0)
  OFFSET GREATEST(COALESCE(p_offset, 0), 0);

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'deleted_users', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_deleted_users(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_deleted_users(INT, INT) TO service_role;
