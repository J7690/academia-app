-- Audit ultra rigoureux du module TD (app.td_fields, app.td_programs, etc.)
-- 1. Lister toutes les tables du schéma app liées au TD
SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name LIKE 'td_%';

-- 2. Lister toutes les policies RLS pour ces tables
SELECT * FROM pg_policies WHERE schemaname = 'app' AND tablename LIKE 'td_%';

-- 3. Lister tous les GRANTs effectifs pour ces tables
SELECT table_name, grantee, privilege_type FROM information_schema.role_table_grants WHERE table_schema = 'app' AND table_name LIKE 'td_%';

-- 4. Lister toutes les fonctions et RPCs liées au TD
SELECT routine_name, routine_type, routine_schema FROM information_schema.routines WHERE routine_schema IN ('app', 'public') AND routine_name LIKE '%td%';

-- 5. Lister les colonnes critiques pour td_fields et td_programs
SELECT table_name, column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name IN ('td_fields', 'td_programs');
