-- Audit: find ALL overloads of app_videoasset_get_playback_manifest
SELECT
  n.nspname AS schema,
  p.proname AS function_name,
  p.oid::regprocedure::text AS signature,
  pg_get_function_identity_arguments(p.oid) AS identity_args,
  r.rolname AS owner,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_roles r ON r.oid = p.proowner
WHERE p.proname = 'app_videoasset_get_playback_manifest'
ORDER BY n.nspname, p.oid::regprocedure::text;
