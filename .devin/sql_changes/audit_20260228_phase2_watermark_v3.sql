SELECT n.nspname AS schema, p.proname AS name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public')
  AND p.proname IN ('admin_execute_sql')
ORDER BY 1,2;

SELECT n.nspname AS schema, p.proname AS name, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public')
  AND p.proname IN (
    'app_videoasset_enqueue_processing',
    'app_videoasset_claim_next_job',
    'app_videoasset_complete_job',
    'app_videoasset_get_playback_manifest'
  )
ORDER BY 1,2,3;

SELECT job_type, status, count(*) AS cnt
FROM app.video_processing_jobs
GROUP BY job_type, status
ORDER BY cnt DESC, job_type, status;

SELECT rendition_key, kind, status, count(*) AS cnt
FROM app.video_renditions
WHERE rendition_key ILIKE '%export%'
GROUP BY rendition_key, kind, status
ORDER BY cnt DESC, rendition_key;

SELECT video_asset_id, rendition_key, kind, status, public_url_hint
FROM app.video_renditions
WHERE status = 'ready' AND kind = 'mp4'
ORDER BY created_at DESC
LIMIT 5;
