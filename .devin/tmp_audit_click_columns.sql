SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE column_name = 'click_at'
   OR column_name = 'l_click_at'
   OR column_name ILIKE '%click%'
ORDER BY table_schema, table_name, column_name;

SELECT
  n.nspname AS schema,
  c.relname AS relation,
  a.attname AS column,
  pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE a.attnum > 0
  AND NOT a.attisdropped
  AND a.attname IN ('click_at', 'l_click_at')
ORDER BY n.nspname, c.relname, a.attname;

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_definition ILIKE '%click_at%'
ORDER BY routine_name;
