-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 12)
-- Désactivation du paywall pour le module Prépa concours
-- -> app_has_feature_access('prep_concours') retourne toujours TRUE
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Override de app_has_feature_access pour prep_concours
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
  -- Utilisateur non authentifié : pas d'accès
  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Rôle dans auth.users
  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  -- Admins toujours autorisés
  IF v_role = 'admin' THEN
    RETURN TRUE;
  END IF;

  -- Spécifique Prépa concours : paywall désactivé, accès libre
  IF p_feature_key = 'prep_concours' THEN
    RETURN TRUE;
  END IF;

  -- Comportement générique pour les autres features (paywall conservé)
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
