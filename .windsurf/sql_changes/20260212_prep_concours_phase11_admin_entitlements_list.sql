-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 11)
-- Admin: listing des entitlements user_feature_entitlements
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) RPC ADMIN: lister les entitlements pour un feature_key
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_list_entitlements(
  p_feature_key TEXT DEFAULT 'prep_concours',
  p_only_active BOOLEAN DEFAULT TRUE
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
  -- Auth + admin check
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

  -- Liste des entitlements (avec email pour exploitation admin)
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'user_id', e.user_id,
        'email', u.email,
        'feature_key', e.feature_key,
        'is_active', e.is_active,
        'granted_at', e.granted_at,
        'expires_at', e.expires_at,
        'metadata', e.metadata
      )
      ORDER BY e.granted_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_result
  FROM app.user_feature_entitlements e
  JOIN auth.users u ON u.id = e.user_id
  WHERE (p_feature_key IS NULL OR e.feature_key = p_feature_key)
    AND (NOT p_only_active OR e.is_active = TRUE);

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'feature_key', p_feature_key,
    'only_active', p_only_active,
    'entitlements', v_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_list_entitlements(TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_list_entitlements(TEXT, BOOLEAN) TO service_role;
