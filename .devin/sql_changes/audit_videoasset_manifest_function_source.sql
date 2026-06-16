-- Audit: fetch deployed function definitions to explain runtime error

-- 1) public.app_videoasset_get_playback_manifest(uuid)
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'app_videoasset_get_playback_manifest'
  AND p.oid::regprocedure::text = 'app_videoasset_get_playback_manifest(uuid)';

-- 2) public.app_videoasset_get_playback_for_direct_url(text)
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'app_videoasset_get_playback_for_direct_url'
  AND p.oid::regprocedure::text = 'app_videoasset_get_playback_for_direct_url(text)';
