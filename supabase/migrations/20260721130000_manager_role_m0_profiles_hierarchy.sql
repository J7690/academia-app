-- Role Manager — M0 : helper is_manager, manager_profiles, hierarchie.
-- Appliquee en prod le 2026-07-21 via MCP. RLS stricte.
CREATE OR REPLACE FUNCTION app.is_manager()
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'auth', 'app'
AS $$
DECLARE _r boolean;
BEGIN
  SELECT (u.raw_user_meta_data->>'role' = 'manager') INTO _r
  FROM auth.users u WHERE u.id = auth.uid();
  RETURN COALESCE(_r, false);
END;
$$;

CREATE TABLE app.manager_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  phone text,
  is_active boolean NOT NULL DEFAULT true,
  admin_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE app.manager_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY manager_profiles_admin_all ON app.manager_profiles
  FOR ALL USING (app.is_admin()) WITH CHECK (app.is_admin());
CREATE POLICY manager_profiles_self_select ON app.manager_profiles
  FOR SELECT USING (user_id = auth.uid());
REVOKE ALL ON app.manager_profiles FROM anon, authenticated;
GRANT SELECT ON app.manager_profiles TO authenticated;

ALTER TABLE app.commercial_profiles
  ADD COLUMN IF NOT EXISTS manager_user_id uuid NULL
  REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_commercial_profiles_manager
  ON app.commercial_profiles (manager_user_id) WHERE manager_user_id IS NOT NULL;
