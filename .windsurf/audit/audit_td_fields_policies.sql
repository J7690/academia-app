-- Audit des policies RLS et des GRANTs effectifs sur la table app.td_fields
SELECT * FROM pg_policies WHERE tablename = 'td_fields';
SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE table_name = 'td_fields';
