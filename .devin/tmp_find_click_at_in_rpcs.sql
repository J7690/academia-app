SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
    pg_get_functiondef(p.oid) ILIKE '%click_at%'
    OR pg_get_functiondef(p.oid) ILIKE '%l_click_at%'
  )
ORDER BY p.proname;

SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args,
  LEFT(pg_get_functiondef(p.oid), 3500) AS function_def_prefix
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
    pg_get_functiondef(p.oid) ILIKE '%click_at%'
    OR pg_get_functiondef(p.oid) ILIKE '%l_click_at%'
  )
ORDER BY p.proname
LIMIT 10;
