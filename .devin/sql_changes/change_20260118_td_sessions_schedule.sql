-- ========================================
-- ACADEMIA - MODULE TD
-- Ajout de la programmation des horaires pour les séances TD
-- Date: 2026-01-18
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

ALTER TABLE app.td_sessions
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS duration_minutes INTEGER;
