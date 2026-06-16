-- Migration: Déplacer les RPCs app_prep_teacher_* du schéma app vers public
-- Date: 2026-06-06
-- Projet: academia_app
-- Objectif: Corriger le bug 404 NOT FOUND pour les RPCs Prépa Enseignant

-- Étape 1: Déplacer les RPCs du schéma app vers public
ALTER FUNCTION app.app_prep_teacher_list_assignments() SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_upsert_assignment(uuid, text, text, text, text, text, jsonb, jsonb, timestamp with time zone, integer, boolean, text) SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_list_submissions(uuid) SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_grade_submission(uuid, integer, text) SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_list_live_sessions() SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_upsert_live_session(uuid, text, text, text, text, text, text, text, timestamp with time zone, timestamp with time zone, text, integer, uuid) SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_start_live_session(uuid) SET SCHEMA public;
ALTER FUNCTION app.app_prep_teacher_end_live_session(uuid) SET SCHEMA public;

-- Étape 2: Accorder les permissions EXECUTE (authenticated et service_role uniquement)
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(uuid, text, text, text, text, text, jsonb, jsonb, timestamp with time zone, integer, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(uuid, text, text, text, text, text, jsonb, jsonb, timestamp with time zone, integer, boolean, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(uuid, integer, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(uuid, text, text, text, text, text, text, text, timestamp with time zone, timestamp with time zone, text, integer, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(uuid, text, text, text, text, text, text, text, timestamp with time zone, timestamp with time zone, text, integer, uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(uuid) TO service_role;
