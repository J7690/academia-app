-- ========================================
-- ACADEMIA - MODULE TD
-- Publication des programmes existants pour visibilité côté étudiant
-- Date: 2026-01-18
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- Tous les programmes encore en brouillon passent en "published"
UPDATE app.td_programs
SET status = 'published'
WHERE status = 'draft';
