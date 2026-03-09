SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE column_name ILIKE '%click_at%'
ORDER BY table_schema, table_name, column_name;

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_definition ILIKE '%click_at%'
ORDER BY routine_name;
