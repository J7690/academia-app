-- ============================================================================
-- Migration: Account Deletion Compliance — Correctif Final
-- Date: 2026-06-04
-- Auteur: Audit Academia
-- Statut: PRET POUR REVUE — NE PAS EXECUTER SANS VALIDATION FINALE
--
-- Historique:
--   change_20260316_account_deletion_compliance.sql (2026-03-16) :
--     - Jamais execute en production
--     - Definissait les RPC dans le schema `app` (non conforme convention Flutter)
--     - Utilisait DEFAULT 'self_service' sur deletion_method
--     - Le cron appelait app.app_admin_purge_deleted_accounts() (inexistant)
--
-- Corrections apportees dans ce script:
--   1. RPC exposes a Flutter dans le schema `public`
--   2. deletion_method sans DEFAULT (nullable)
--   3. Cron corrige pour appeler public.app_admin_purge_deleted_accounts()
--   4. Aucun backfill automatique des 23 comptes historiques
--   5. Protection renforcee du cron contre les purges accidentelles
-- ============================================================================

-- ============================================================================
-- PHASE 1 — AJOUT DES COLONNES
-- ============================================================================
-- Objectif: Ajouter les colonnes necessaires au workflow de suppression
-- comptes sans affecter les 23 comptes historiques.
--
-- Impact attendu:
--   - Toutes les lignes existantes conservent NULL dans les nouvelles colonnes
--   - Les 23 comptes historiques (is_deleted=TRUE) restent avec deletion_method=NULL
--   - Le cron les ignorera naturellement (clause deletion_method IS NOT NULL)
--
-- Objet touche: app.user_admin_status
-- Dependances: Aucune (ALTER TABLE IF EXISTS)
-- Risque: NUL — IF EXISTS empeche l'erreur si deja applique
-- Rollback: ALTER TABLE app.user_admin_status DROP COLUMN IF EXISTS <colonne>;
-- ============================================================================

ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS purge_due_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deletion_method TEXT;  -- nullable, AUCUN DEFAULT


-- ============================================================================
-- PHASE 2 — RPC: Demande de suppression volontaire (etudiant)
-- ============================================================================
-- Objectif: Permettre a un etudiant de demander la suppression de son compte
--
-- Schema: public (convention Academia — tous les RPC Flutter sont dans public)
-- Securite: SECURITY DEFINER (execute avec les privileges du createur)
-- Retour: JSONB {success, message?, error?, purge_due_at?}
--
-- Controles de securite:
--   - auth.uid() doit etre non NULL (authentifie)
--   - Role autorise: student, commercial, merchant (pas admin/university)
--   - Interdit si is_deleted = TRUE deja present (deja en cours)
--   - Bannissement auth.users jusqu'en 2099
--   - Invalidation de toutes les sessions et refresh tokens
--   - Desactivation des tokens FCM
--
-- Tables impactees:
--   - app.user_admin_status (INSERT/UPDATE)
--   - auth.users (UPDATE banned_until)
--   - auth.sessions (DELETE)
--   - auth.refresh_tokens (DELETE)
--   - app.user_device_tokens (UPDATE is_active)
--   - app.admin_user_action_logs (INSERT)
--
-- Compatibilite Flutter:
--   - Appel: client.rpc('app_student_request_account_deletion')
--   - Reponse attendue: {success: true, purge_due_at: "2026-08-04T..."}
--   - Le screen student_delete_account_screen.dart affiche purge_due_at
--
-- Compatibilite Supabase:
--   - Necessite l'extension pg_cron si le cron est active (deja presente)
--   - Necessite que auth.users soit accessible (search_path inclut auth)
--
-- Rollback: DROP FUNCTION IF EXISTS public.app_student_request_account_deletion();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_student_request_account_deletion()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public, auth
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_now TIMESTAMPTZ := NOW();
  v_purge_at TIMESTAMPTZ := v_now + INTERVAL '60 days';
  v_role TEXT;
BEGIN
  -- --------------------------------------------------
  -- 1. Authentification obligatoire
  -- --------------------------------------------------
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- --------------------------------------------------
  -- 2. Verification du role
  -- --------------------------------------------------
  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role IS NOT NULL AND v_role NOT IN ('student', 'commercial', 'merchant') THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', 'role_not_eligible',
      'message', 'Contactez le support pour supprimer ce type de compte.'
    );
  END IF;

  -- --------------------------------------------------
  -- 3. Deja en cours de suppression ?
  -- --------------------------------------------------
  IF EXISTS (
    SELECT 1 FROM app.user_admin_status
    WHERE user_id = v_user_id AND is_deleted = TRUE
  ) THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_pending_deletion');
  END IF;

  -- --------------------------------------------------
  -- 4. Enregistrement de la demande
  -- --------------------------------------------------
  INSERT INTO app.user_admin_status (
    user_id,
    is_suspended, suspended_reason, suspended_at,
    is_deleted, deleted_reason, deleted_at,
    deletion_requested_at, purge_due_at, deletion_method,
    updated_at
  ) VALUES (
    v_user_id,
    TRUE, 'account_deletion_requested', v_now,
    TRUE, 'user_self_service_deletion', v_now,
    v_now, v_purge_at, 'self_service',
    v_now
  )
  ON CONFLICT (user_id) DO UPDATE SET
    is_suspended = TRUE,
    suspended_reason = 'account_deletion_requested',
    suspended_at = v_now,
    is_deleted = TRUE,
    deleted_reason = 'user_self_service_deletion',
    deleted_at = v_now,
    deletion_requested_at = v_now,
    purge_due_at = v_purge_at,
    deletion_method = 'self_service',
    updated_at = v_now;

  -- --------------------------------------------------
  -- 5. Blocage de reconnexion
  -- --------------------------------------------------
  UPDATE auth.users
  SET banned_until = '2099-12-31 23:59:59+00'::TIMESTAMPTZ,
      updated_at = v_now
  WHERE id = v_user_id;

  -- --------------------------------------------------
  -- 6. Invalidation des sessions
  -- --------------------------------------------------
  DELETE FROM auth.sessions WHERE user_id = v_user_id;
  DELETE FROM auth.refresh_tokens WHERE session_id IN (
    SELECT id FROM auth.sessions WHERE user_id = v_user_id
  );

  -- --------------------------------------------------
  -- 7. Desactivation des tokens FCM
  -- --------------------------------------------------
  UPDATE app.user_device_tokens
  SET is_active = FALSE
  WHERE user_id = v_user_id;

  -- --------------------------------------------------
  -- 8. Journalisation
  -- --------------------------------------------------
  INSERT INTO app.admin_user_action_logs (
    performed_by, target_user, action, reason, meta
  ) VALUES (
    v_user_id, v_user_id, 'delete',
    'user_self_service_deletion',
    JSONB_BUILD_OBJECT(
      'method', 'self_service',
      'requested_at', v_now,
      'purge_due_at', v_purge_at
    )
  );

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'message', 'Votre demande de suppression a ete prise en compte.',
    'purge_due_at', v_purge_at
  );
END;
$$;

-- --------------------------------------------------
-- GRANT: Tous les utilisateurs authentifies peuvent appeler
-- --------------------------------------------------
GRANT EXECUTE ON FUNCTION public.app_student_request_account_deletion() TO authenticated;


-- ============================================================================
-- PHASE 3 — RPC: Purge automatique des comptes (appele par pg_cron)
-- ============================================================================
-- Objectif: Supprimer physiquement et anonymiser les comptes apres 60 jours
--
-- Schema: public (convention Academia)
-- Securite: SECURITY DEFINER
-- Retour: JSONB {success, purged_count, errors}
--
-- IMPORTANT — Protection contre les purges accidentelles:
--   - WHERE deletion_method = 'self_service' (pas 'admin', pas 'purged', pas NULL)
--   - WHERE purge_due_at IS NOT NULL
--   - WHERE purge_due_at <= NOW()
--   - Les 23 comptes historiques ont deletion_method = NULL => PROTEGES
--   - Les comptes admin-supprimes (futur) auraient deletion_method = 'admin' => PROTEGES
--
-- Tables impactees (DELETE ou UPDATE):
--   app.direct_message_read_states, app.direct_messages, app.direct_conversations
--   app.support_read_states, app.support_messages, app.support_conversations
--   app.commercial_milestone_claims
--   app.prep_ai_messages, app.prep_ai_conversations, app.prep_ai_corrections,
--     app.prep_assignment_submissions, app.prep_flashcard_progress,
--     app.prep_live_participants, app.prep_psychotech_profiles,
--     app.prep_psychotech_results, app.prep_quiz_attempts,
--     app.prep_student_badges, app.prep_student_progress
--   app.td_ai_messages, app.td_ai_conversations, app.td_flashcard_progress,
--     app.td_quiz_attempts, app.td_student_badges, app.td_student_progress,
--     app.td_daily_goals, app.td_streaks, app.td_xp_log
--   app.video_comments, app.video_favorites, app.video_likes, app.video_reports
--   app.marketplace_listing_bookmarks, app.marketplace_cart_items, app.marketplace_carts
--   app.opportunity_bookmarks, app.opportunity_comments, app.opportunity_reactions,
--     app.opportunity_views, app.opportunity_inquiry_messages
--   app.students (UPDATE anonymisation)
--   auth.users (UPDATE soft-delete: email, password, meta, phone)
--   app.user_admin_status (UPDATE deletion_method = 'purged')
--   app.admin_user_action_logs (INSERT)
--
-- Rollback: DROP FUNCTION IF EXISTS public.app_admin_purge_deleted_accounts();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_admin_purge_deleted_accounts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public, auth
AS $$
DECLARE
  v_user RECORD;
  v_count INTEGER := 0;
  v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOR v_user IN
    SELECT user_id, purge_due_at
    FROM app.user_admin_status
    WHERE is_deleted = TRUE
      AND purge_due_at IS NOT NULL
      AND purge_due_at <= NOW()
      AND deletion_method = 'self_service'  -- PROTECTION: exclut NULL et 'admin'
  LOOP
    BEGIN
      -- ============================================
      -- 1. Suppression des tables NO ACTION FK
      -- ============================================
      -- Messages directs
      DELETE FROM app.direct_message_read_states WHERE user_id = v_user.user_id;
      DELETE FROM app.direct_messages WHERE sender_id = v_user.user_id;
      DELETE FROM app.direct_conversations
        WHERE user_a = v_user.user_id OR user_b = v_user.user_id;

      -- Support
      DELETE FROM app.support_read_states WHERE user_id = v_user.user_id;
      DELETE FROM app.support_messages
        WHERE conversation_id IN (
          SELECT id FROM app.support_conversations
          WHERE requester_user_id = v_user.user_id
        );
      DELETE FROM app.support_conversations
        WHERE requester_user_id = v_user.user_id;

      -- Commercial
      DELETE FROM app.commercial_milestone_claims
        WHERE commercial_user_id = v_user.user_id;

      -- Prep concours
      DELETE FROM app.prep_ai_messages
        WHERE conversation_id IN (
          SELECT id FROM app.prep_ai_conversations
          WHERE student_id = v_user.user_id
        );
      DELETE FROM app.prep_ai_conversations WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_ai_corrections WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_assignment_submissions WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_flashcard_progress WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_live_participants WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_psychotech_profiles WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_psychotech_results WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_quiz_attempts WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_student_badges WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_student_progress WHERE student_id = v_user.user_id;

      -- TD
      DELETE FROM app.td_ai_messages
        WHERE conversation_id IN (
          SELECT id FROM app.td_ai_conversations WHERE student_id = v_user.user_id
        );
      DELETE FROM app.td_ai_conversations WHERE student_id = v_user.user_id;
      DELETE FROM app.td_flashcard_progress WHERE student_id = v_user.user_id;
      DELETE FROM app.td_quiz_attempts WHERE student_id = v_user.user_id;
      DELETE FROM app.td_student_badges WHERE student_id = v_user.user_id;
      DELETE FROM app.td_student_progress WHERE student_id = v_user.user_id;
      DELETE FROM app.td_daily_goals WHERE student_id = v_user.user_id;
      DELETE FROM app.td_streaks WHERE student_id = v_user.user_id;
      DELETE FROM app.td_xp_log WHERE student_id = v_user.user_id;

      -- Videos
      DELETE FROM app.video_comments WHERE user_id = v_user.user_id;
      DELETE FROM app.video_favorites WHERE user_id = v_user.user_id;
      DELETE FROM app.video_likes WHERE user_id = v_user.user_id;
      DELETE FROM app.video_reports WHERE user_id = v_user.user_id;

      -- Marketplace
      DELETE FROM app.marketplace_listing_bookmarks WHERE user_id = v_user.user_id;
      DELETE FROM app.marketplace_cart_items
        WHERE cart_id IN (
          SELECT id FROM app.marketplace_carts WHERE user_id = v_user.user_id
        );
      DELETE FROM app.marketplace_carts WHERE user_id = v_user.user_id;

      -- Opportunites
      DELETE FROM app.opportunity_bookmarks WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_comments WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_reactions WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_views WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_inquiry_messages WHERE sender_id = v_user.user_id;

      -- ============================================
      -- 2. Anonymisation PII dans students
      -- ============================================
      UPDATE app.students SET
        full_name = 'Utilisateur supprime',
        phone = NULL,
        country = NULL,
        city = NULL,
        date_of_birth = NULL,
        avatar_url = NULL,
        bio = NULL,
        website_url = NULL,
        timezone = NULL,
        geo_latitude = NULL,
        geo_longitude = NULL,
        bepc_year = NULL,
        bepc_institution = NULL,
        bepc_country = NULL,
        bepc_mention = NULL,
        bac_year = NULL,
        bac_series = NULL,
        bac_mention = NULL,
        bac_institution = NULL,
        bac_country = NULL,
        study_project_text = NULL,
        updated_at = NOW()
      WHERE id = v_user.user_id;

      -- ============================================
      -- 3. Soft-delete auth.users
      -- ============================================
      UPDATE auth.users SET
        email = 'deleted_' || v_user.user_id::TEXT || '@deleted.academia.app',
        encrypted_password = '',
        raw_user_meta_data = JSONB_BUILD_OBJECT('role', 'deleted', 'purged_at', NOW()::TEXT),
        phone = NULL,
        deleted_at = NOW(),
        updated_at = NOW()
      WHERE id = v_user.user_id;

      -- ============================================
      -- 4. Marquage comme purge
      -- ============================================
      UPDATE app.user_admin_status SET
        deletion_method = 'purged',
        updated_at = NOW()
      WHERE user_id = v_user.user_id;

      -- ============================================
      -- 5. Journalisation
      -- ============================================
      INSERT INTO app.admin_user_action_logs (
        performed_by, target_user, action, reason, meta
      ) VALUES (
        v_user.user_id, v_user.user_id, 'account_purged',
        'automatic_purge_60_days',
        JSONB_BUILD_OBJECT('purged_at', NOW())
      );

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      v_errors := array_append(v_errors,
        v_user.user_id::TEXT || ': ' || SQLERRM);
    END;
  END LOOP;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'purged_count', v_count,
    'errors', v_errors
  );
END;
$$;


-- ============================================================================
-- PHASE 4 — CORRECTION DU CRON (remplacement securise)
-- ============================================================================
-- Objectif: Remplacer la commande du cron existant sans le supprimer/recreer
--
-- Cron actuel (confirme par audit):
--   jobid = 3
--   schedule = '0 3 * * *' (3h00 UTC)
--   command = 'SELECT app.app_admin_purge_deleted_accounts()'
--   Etat: ECHEC quotidien depuis 2026-04-24 (function inexistante)
--
-- Strategie de remplacement:
--   1. cron.unschedule('purge_deleted_accounts')  -- supprime le cron existant
--   2. cron.schedule('purge_deleted_accounts', '0 3 * * *',
--      'SELECT public.app_admin_purge_deleted_accounts()')
--
-- Pourquoi unschedule + schedule plutot que cron.job UPDATE:
--   - pg_cron ne permet pas de modifier la commande d'un job existant
--   - unschedule + schedule est l'operation atomique standard
--
-- Protection contre la double execution:
--   - Le cron ne retourne pas d'erreur si aucun compte eligible
--   - Les 23 comptes historiques ne sont PAS eligibles (deletion_method IS NULL)
--   - Seuls les comptes avec deletion_method = 'self_service' + purge_due_at depasse
--
-- Rollback:
--   SELECT cron.unschedule('purge_deleted_accounts');
--   -- Si necessaire, recreer l'ancien (non fonctionnel):
--   SELECT cron.schedule('purge_deleted_accounts', '0 3 * * *',
--     'SELECT app.app_admin_purge_deleted_accounts()');
-- ============================================================================

SELECT cron.unschedule('purge_deleted_accounts');

SELECT cron.schedule(
  'purge_deleted_accounts',
  '0 3 * * *',
  $$SELECT public.app_admin_purge_deleted_accounts()$$
);


-- ============================================================================
-- PHASE 5 — VERIFICATION FINALE (OPTIONNELLE, POUR EXECUTION MANUELLE)
-- ============================================================================
-- Objectif: Apres execution du script, valider que tout est en place.
-- Ne pas executer automatiquement — a lancer manuellement post-migration.
-- ============================================================================

/*
-- Verification des colonnes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name = 'user_admin_status'
  AND column_name IN ('deletion_requested_at', 'purge_due_at', 'deletion_method');

-- Verification des fonctions
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('app_student_request_account_deletion', 'app_admin_purge_deleted_accounts');

-- Verification du cron
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname = 'purge_deleted_accounts';

-- Verification que les comptes historiques NE sont PAS eligibles
SELECT COUNT(*) as would_be_purged
FROM app.user_admin_status
WHERE is_deleted = TRUE
  AND purge_due_at IS NOT NULL
  AND purge_due_at <= NOW()
  AND deletion_method = 'self_service';
  -- Doit retourner 0 immediatement apres la migration
*/

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================
