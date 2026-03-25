SELECT routine_name, routine_type, data_type 
FROM information_schema.routines 
WHERE routine_schema = 'app' 
ORDER BY routine_name 
LIMIT 50;
