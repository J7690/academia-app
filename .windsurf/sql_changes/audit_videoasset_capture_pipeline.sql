-- Audit: VideoAsset capture pipeline (filmer / enregistrement)
-- Run via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/audit_videoasset_capture_pipeline.sql

-- 1) Which RPC overloads exist (signatures) + owners
SELECT
  n.nspname AS schema,
  p.proname AS function_name,
  p.oid::regprocedure::text AS signature,
  r.rolname AS owner,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_roles r ON r.oid = p.proowner
WHERE p.proname IN (
  'app_videoasset_create_upload_intent',
  'app_videoasset_register_uploaded_source',
  'app_videoasset_get_playback_for_direct_url',
  'app_videoasset_get_playback_manifest'
)
ORDER BY n.nspname, p.proname, p.oid::regprocedure::text;

-- 2) Which tables exist (app vs public)
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name IN (
  'video_assets',
  'video_sources',
  'video_renditions',
  'video_asset_contexts',
  'video_processing_jobs'
)
  AND table_schema IN ('app', 'public')
ORDER BY table_schema, table_name;

-- 3) Columns check (detect mismatches like is_ready vs status, label vs rendition_key)
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN (
  'video_assets',
  'video_sources',
  'video_renditions',
  'video_asset_contexts',
  'video_processing_jobs'
)
  AND table_schema IN ('app', 'public')
ORDER BY table_schema, table_name, ordinal_position;

-- 4) Basic counts by status (app.* only)
SELECT status, COUNT(*)::bigint AS n
FROM app.video_assets
GROUP BY status
ORDER BY n DESC;

SELECT status, job_type, COUNT(*)::bigint AS n
FROM app.video_processing_jobs
GROUP BY status, job_type
ORDER BY n DESC;

SELECT kind, status, COUNT(*)::bigint AS n
FROM app.video_renditions
GROUP BY kind, status
ORDER BY n DESC;

-- 5) Recent assets snapshot (last 30)
SELECT
  a.id,
  a.owner_user_id,
  a.origin,
  a.status,
  a.created_at,
  a.updated_at
FROM app.video_assets a
ORDER BY a.created_at DESC
LIMIT 30;

-- 6) For each recent asset: count sources + renditions + jobs
SELECT
  a.id AS video_asset_id,
  a.status,
  (SELECT COUNT(*) FROM app.video_sources s WHERE s.video_asset_id = a.id) AS sources_count,
  (SELECT COUNT(*) FROM app.video_renditions r WHERE r.video_asset_id = a.id) AS renditions_count,
  (SELECT COUNT(*) FROM app.video_renditions r WHERE r.video_asset_id = a.id AND r.status = 'ready') AS renditions_ready,
  (SELECT COUNT(*) FROM app.video_processing_jobs j WHERE j.video_asset_id = a.id) AS jobs_count,
  (SELECT COUNT(*) FROM app.video_processing_jobs j WHERE j.video_asset_id = a.id AND j.status = 'failed') AS jobs_failed
FROM app.video_assets a
ORDER BY a.created_at DESC
LIMIT 30;

-- 7) Detect direct-url mapping effectiveness: how many renditions have a public_url_hint
SELECT
  COUNT(*)::bigint AS total_renditions,
  COUNT(*) FILTER (WHERE NULLIF(TRIM(COALESCE(public_url_hint,'')), '') IS NOT NULL)::bigint AS with_public_url_hint
FROM app.video_renditions;
