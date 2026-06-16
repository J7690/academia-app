-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 8)
-- Entitlement status helper for students
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) RPC: get current user entitlement status for a feature
-- ========================================

CREATE OR REPLACE FUNCTION app_prep_get_my_entitlement(
  p_feature_key TEXT DEFAULT 'prep_concours'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_ent app.user_feature_entitlements%ROWTYPE;
  v_has_access BOOLEAN := FALSE;
BEGIN
  -- Not authenticated
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', 'not_authenticated',
      'has_access', FALSE,
      'feature_key', p_feature_key
    );
  END IF;

  -- Get role from auth.users
  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  -- Admins are always considered as having access
  IF v_role = 'admin' THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'has_access', TRUE,
      'is_admin', TRUE,
      'feature_key', p_feature_key,
      'entitlement', NULL
    );
  END IF;

  -- Look for an active, non-expired entitlement for this user & feature
  SELECT *
  INTO v_ent
  FROM app.user_feature_entitlements e
  WHERE e.user_id = v_user_id
    AND e.feature_key = p_feature_key
    AND e.is_active = TRUE
    AND (e.expires_at IS NULL OR e.expires_at > NOW())
  ORDER BY e.granted_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_has_access := TRUE;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'has_access', v_has_access,
    'feature_key', p_feature_key,
    'entitlement', CASE
      WHEN v_has_access THEN JSONB_BUILD_OBJECT(
        'user_id', v_ent.user_id,
        'granted_by', v_ent.granted_by,
        'granted_at', v_ent.granted_at,
        'expires_at', v_ent.expires_at,
        'is_active', v_ent.is_active,
        'metadata', v_ent.metadata
      )
      ELSE NULL
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_get_my_entitlement(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_get_my_entitlement(TEXT) TO service_role;
