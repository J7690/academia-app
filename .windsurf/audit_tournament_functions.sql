SELECT routine_name, routine_type, data_type 
FROM information_schema.routines 
WHERE routine_schema = 'app' AND routine_name LIKE '%tournament%' 
ORDER BY routine_name;
