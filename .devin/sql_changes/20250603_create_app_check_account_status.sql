-- ============================================================================
-- RPC : public.app_check_account_status
-- Date  : 2026-06-03
-- Audit : exhaustive audits completed (referential integrity, delete behavior,
--         auth.users columns, app.user_admin_status structure, RPC equivalents)
-- ============================================================================
-- PURPOSE
--   Called by AuthWrapper after login to enforce server-side account status.
--   Returns {"active": true/false, "reason": "..."}.
--   If active=false → Flutter signs out and redirects to AuthLandingScreen.
-- ============================================================================
-- QUALIFICATION : all tables/schemas are fully qualified (no search_path reliance)
-- TABLES USED   : auth.users, app.user_admin_status
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_check_account_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_suspended BOOLEAN;
  v_is_deleted BOOLEAN;
  v_suspended_reason TEXT;
  v_deleted_reason TEXT;
  v_banned_until TIMESTAMPTZ;
BEGIN
  -- Defensive: unauthenticated caller
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('active', FALSE, 'reason', 'not_authenticated');
  END IF;

  -- Read status from auth.users + app.user_admin_status
  SELECT
    COALESCE(s.is_suspended, FALSE),
    COALESCE(s.is_deleted, FALSE),
    s.suspended_reason,
    s.deleted_reason,
    u.banned_until
  INTO
    v_is_suspended,
    v_is_deleted,
    v_suspended_reason,
    v_deleted_reason,
    v_banned_until
  FROM auth.users u
  LEFT JOIN app.user_admin_status s ON s.user_id = u.id
  WHERE u.id = v_user_id;

  -- Defensive: user not found in auth.users
  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('active', FALSE, 'reason', 'user_not_found');
  END IF;

  -- Priority: deleted > suspended > banned > active

  -- Deleted
  IF v_is_deleted THEN
    RETURN JSONB_BUILD_OBJECT(
      'active', FALSE,
      'reason', COALESCE(v_deleted_reason, 'account_deleted')
    );
  END IF;

  -- Suspended
  IF v_is_suspended THEN
    RETURN JSONB_BUILD_OBJECT(
      'active', FALSE,
      'reason', COALESCE(v_suspended_reason, 'account_suspended')
    );
  END IF;

  -- Banned (banned_until in the future)
  IF v_banned_until IS NOT NULL AND v_banned_until > NOW() THEN
    RETURN JSONB_BUILD_OBJECT(
      'active', FALSE,
      'reason', 'account_banned'
    );
  END IF;

  -- Active
  RETURN JSONB_BUILD_OBJECT('active', TRUE, 'reason', NULL);
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.app_check_account_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_check_account_status() TO service_role;
