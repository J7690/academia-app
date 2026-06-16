-- ============================================================
-- CORRECTIF : app_student_delete_forum_message
-- Date : 2026-06-04
-- Type : Proxy/wrapper public → app
-- Objectif : Rendre fonctionnelle la suppression des messages forum
--            sans modifier la logique métier existante.
--
-- PRÉREQUIS : Vérifier la signature du RPC source dans app
--             (script de vérification ci-dessous)
--
-- AUCUNE MODIFICATION DU RPC SOURCE app.app_student_delete_forum_message
-- AUCUNE MODIFICATION DES TABLES
-- AUCUNE MODIFICATION DE FLUTTER
-- ============================================================

-- ============================================================
-- ÉTAPE 0 — VÉRIFICATION PRÉALABLE (à exécuter manuellement)
-- ============================================================
-- Exécuter ces requêtes dans Supabase SQL Editor AVANT le déploiement
-- pour confirmer la signature exacte du RPC source dans le schéma app.

/*
-- Vérifier l'existence et la signature du RPC source
SELECT 
  p.proname AS function_name,
  pg_get_function_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'app'
  AND p.proname = 'app_student_delete_forum_message';

-- Résultat attendu :
--   function_name                    | arguments          | return_type
--   ---------------------------------+--------------------+------------
--   app_student_delete_forum_message | p_message_id uuid  | jsonb
--
-- Si le résultat diffère (ex: p_message_id de type text), adapter
-- la ligne CREATE FUNCTION ci-dessous avant exécution.
*/

-- ============================================================
-- ÉTAPE 1 — CRÉATION DU PROXY DANS public
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_student_delete_forum_message(
  p_message_id UUID
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, app, auth
AS $$
  SELECT app.app_student_delete_forum_message(p_message_id);
$$;

-- ============================================================
-- ÉTAPE 2 — GRANT (pattern identique aux autres RPCs forum)
-- ============================================================

GRANT EXECUTE ON FUNCTION public.app_student_delete_forum_message(UUID) TO authenticated;

-- ============================================================
-- VÉRIFICATION POST-DÉPLOIEMENT (optionnel)
-- ============================================================

/*
-- Vérifier que le proxy est accessible depuis public
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_name = 'app_student_delete_forum_message'
  AND routine_schema = 'public';

-- Vérifier le grant
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_name = 'app_student_delete_forum_message'
  AND routine_schema = 'public';
*/
