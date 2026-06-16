SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name LIKE '%challenge%' 
ORDER BY table_name, ordinal_position;
