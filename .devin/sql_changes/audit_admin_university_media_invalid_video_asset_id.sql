-- Audit: what version of app_admin_upsert_university_media is deployed?
-- 1) List overloads + arguments
SELECT
  p.oid,
  n.nspname AS schema,
  p.proname AS name,
  pg_get_function_identity_arguments(p.oid) AS identity_args,
  pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'app_admin_upsert_university_media'
ORDER BY n.nspname, identity_args;

-- 2) Full function definition (all overloads)
SELECT
  n.nspname AS schema,
  p.proname AS name,
  pg_get_function_identity_arguments(p.oid) AS identity_args,
  pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'app_admin_upsert_university_media'
ORDER BY n.nspname, identity_args;

-- 3) Grep inside DB for the error code string
SELECT
  n.nspname AS schema,
  p.proname AS name,
  pg_get_function_identity_arguments(p.oid) AS identity_args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'app_admin_upsert_university_media'
  AND pg_get_functiondef(p.oid) ILIKE '%invalid_video_asset_id%';
