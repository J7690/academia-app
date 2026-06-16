SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'app' AND routine_name LIKE '%game%' 
ORDER BY routine_name;
