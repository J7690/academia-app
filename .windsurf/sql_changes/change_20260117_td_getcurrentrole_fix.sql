-- ========================================
-- ACADEMIA - MODULE TD
-- Fix app.app_td_get_current_role: ignorer le claim JWT role='authenticated'
-- et utiliser user_metadata.role ou raw_user_meta_data->>'role'
-- Date: 2026-01-17
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app.app_td_get_current_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_claims  JSONB;
  v_role    TEXT;
  v_user_id UUID;
BEGIN
  -- 1) Essayer de lire le rôle applicatif dans les claims JWT
  BEGIN
    v_claims := current_setting('request.jwt.claims', true)::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_claims := NULL;
  END;

  IF v_claims IS NOT NULL THEN
    -- Rôle applicatif typique côté Supabase: user_metadata.role ou app_metadata.role
    v_role := COALESCE(
      v_claims->'user_metadata'->>'role',
      v_claims->'app_metadata'->>'role'
    );

    IF v_role IS NOT NULL AND TRIM(v_role) <> '' THEN
      IF v_role = 'instructor' THEN
        RETURN 'teacher';
      END IF;
      RETURN v_role;
    END IF;
  END IF;

  -- 2) Fallback robuste: lire le rôle dans auth.users.raw_user_meta_data->>'role'
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role = 'instructor' THEN
    RETURN 'teacher';
  END IF;

  RETURN v_role;
END;
$$;

REVOKE ALL ON FUNCTION app.app_td_get_current_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.app_td_get_current_role() TO authenticated;
GRANT EXECUTE ON FUNCTION app.app_td_get_current_role() TO service_role;
