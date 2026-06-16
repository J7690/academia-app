-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Complément Phase 2 - Droits d'accès tables TD
-- Date: 2026-01-17
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- Accorder les droits de base au rôle authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_fields      TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_programs    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_collections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_sessions    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_teachers    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_enrollments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_messages    TO authenticated;

-- Rôle service_role (backend) : accès complet
GRANT ALL ON app.td_fields      TO service_role;
GRANT ALL ON app.td_programs    TO service_role;
GRANT ALL ON app.td_collections TO service_role;
GRANT ALL ON app.td_sessions    TO service_role;
GRANT ALL ON app.td_teachers    TO service_role;
GRANT ALL ON app.td_enrollments TO service_role;
GRANT ALL ON app.td_messages    TO service_role;
