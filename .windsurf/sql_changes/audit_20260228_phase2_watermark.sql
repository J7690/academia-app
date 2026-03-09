-- Audit Phase 2 watermark (read-only)

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'app'
  AND table_name IN (
    'video_assets',
    'video_sources',
    'video_renditions',
    'video_processing_jobs'
  )
ORDER BY table_name;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name = 'video_renditions'
ORDER BY ordinal_position;

SELECT schemaname, tablename, policyname, roles, cmd
FROM pg_policies
WHERE schemaname = 'app'
  AND tablename IN ('video_renditions', 'video_processing_jobs')
ORDER BY tablename, policyname;

SELECT rendition_key, kind, status, count(*) AS cnt
FROM app.video_renditions
GROUP BY rendition_key, kind, status
ORDER BY cnt DESC, rendition_key;

SELECT video_asset_id, rendition_key, kind, status, width, public_url_hint, storage_bucket, storage_path, created_at
FROM app.video_renditions
WHERE status = 'ready'
  AND kind = 'mp4'
ORDER BY created_at DESC
LIMIT 10;

SELECT id, video_asset_id, job_type, status, attempts, locked_at, locked_by, error, created_at
FROM app.video_processing_jobs
ORDER BY created_at DESC
LIMIT 10;
