SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE position('click_at' in lower(column_name)) > 0
   OR position('clicked_at' in lower(column_name)) > 0
ORDER BY table_schema, table_name, column_name;

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND position('click_at' in lower(routine_definition)) > 0
ORDER BY routine_name;

SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND position('click_at' in lower(pg_get_functiondef(p.oid))) > 0
ORDER BY p.proname, args;
