-- 1. Toutes les tables liées aux tournois, leagues, jeux
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND (table_name LIKE '%tournament%' OR table_name LIKE '%league%' OR table_name LIKE '%game%' OR table_name LIKE '%match%' OR table_name LIKE '%multiplayer%' OR table_name LIKE '%arena%' OR table_name LIKE '%kellenge%')
ORDER BY table_name;
