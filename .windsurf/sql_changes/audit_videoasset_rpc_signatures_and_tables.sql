-- Audit: verify deployed RPC overloads + table existence for VideoAsset pipeline

-- 1) RPC overloads (signatures)
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

-- 2) Tables existence (app vs public)
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
