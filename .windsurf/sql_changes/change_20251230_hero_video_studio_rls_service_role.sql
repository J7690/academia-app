-- Hero Video Studio RLS: allow service_role (service key) to write hero_video_jobs and hero_videos
--
-- The FastAPI Hero Video Encoder uses SUPABASE_SERVICE_KEY to call
--   /rest/v1/app.hero_video_jobs
--   /rest/v1/app.hero_videos
-- directly. Even with GRANTs, RLS still applies, so we need explicit
-- policies for the database role service_role.
--
-- Apply via:
--   python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251230_hero_video_studio_rls_service_role.sql

-- 1) app.hero_video_jobs: full access for service_role through RLS

DROP POLICY IF EXISTS service_role_all_hero_video_jobs ON app.hero_video_jobs;
CREATE POLICY service_role_all_hero_video_jobs
ON app.hero_video_jobs
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 2) app.hero_videos: full access for service_role through RLS

DROP POLICY IF EXISTS service_role_all_hero_videos ON app.hero_videos;
CREATE POLICY service_role_all_hero_videos
ON app.hero_videos
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
