-- Audit Phase 2 watermark v2 (read-only, compact)

-- 1) RPC functions exist?
SELECT n.nspname AS schema, p.proname AS name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public')
  AND p.proname IN ('admin_execute_sql')
ORDER BY 1,2;

SELECT n.nspname AS schema, p.proname AS name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public')
  AND p.proname IN (
    'app_videoasset_enqueue_processing',
    'app_videoasset_claim_next_job',
    'app_videoasset_complete_job',
    'app_videoasset_get_playback_manifest'
  )
ORDER BY 1,2;

-- 2) Current distinct job types + statuses
SELECT job_type, status, count(*) AS cnt
FROM app.video_processing_jobs
GROUP BY job_type, status
ORDER BY cnt DESC, job_type, status;

-- 3) Existing rendition keys that look like exports
SELECT rendition_key, kind, status, count(*) AS cnt
FROM app.video_renditions
WHERE rendition_key ILIKE '%export%'
GROUP BY rendition_key, kind, status
ORDER BY cnt DESC, rendition_key;

-- 4) Sample recent mp4 renditions (minimal fields)
SELECT video_asset_id, rendition_key, kind, status, public_url_hint
FROM app.video_renditions
WHERE status = 'ready' AND kind = 'mp4'
ORDER BY created_at DESC
LIMIT 5;
