-- Fix RLS for Hero Video Studio tables by avoiding direct SELECT on auth.users
-- to check the admin role. Uses a SECURITY DEFINER helper.
--
-- Apply via:
--   python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251230_hero_video_studio_rls_fix.sql

-- 1) Helper function: app.is_admin()
--
-- This function returns TRUE if the current JWT user has role = 'admin'
-- according to auth.users.raw_user_meta_data->>'role'. It runs as its owner
-- (postgres/service_role) so it can read auth.users without granting SELECT
-- on auth.users to anon/authenticated.

CREATE OR REPLACE FUNCTION app.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, app
AS $$
DECLARE
  _is_admin boolean;
BEGIN
  SELECT (u.raw_user_meta_data->>'role' = 'admin')
  INTO _is_admin
  FROM auth.users u
  WHERE u.id = auth.uid();

  RETURN COALESCE(_is_admin, false);
END;
$$;

REVOKE ALL ON FUNCTION app.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.is_admin() TO anon, authenticated, service_role;

-- 2) Recreate RLS policy on app.hero_video_jobs to use app.is_admin()

DROP POLICY IF EXISTS admin_all_hero_video_jobs ON app.hero_video_jobs;
CREATE POLICY admin_all_hero_video_jobs
ON app.hero_video_jobs
FOR ALL
USING (app.is_admin())
WITH CHECK (app.is_admin());

-- 3) Recreate RLS policy on app.hero_videos to use app.is_admin()

DROP POLICY IF EXISTS admin_all_hero_videos ON app.hero_videos;
CREATE POLICY admin_all_hero_videos
ON app.hero_videos
FOR ALL
USING (app.is_admin())
WITH CHECK (app.is_admin());
