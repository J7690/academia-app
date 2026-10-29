-- ============================================================================
-- Envoi des notifications : appels authentifiés (29/10/2026)
-- ============================================================================
-- Constat mesuré le 29/10 : `send-push-notifications` exige un JWT
-- (verify_jwt = true), mais ses deux appelants côté base l'appelaient SANS
-- en-tête Authorization :
--   - le cron `academia_send_push_notifications` (chaque minute)
--     → `app.app_run_send_push_notifications` ;
--   - le déclencheur d'envoi immédiat `trg_notification_events_instant_push`
--     → `app.trg_instant_push_notification`.
-- Résultat : POST | 401 à chaque appel (journaux v93 et v94). La file n'avançait
-- que lorsqu'une application ouverte déclenchait l'envoi elle-même
-- (`push_trigger_service.dart`, jeton de l'utilisateur). Délais mesurés sur
-- les alertes admin : jusqu'à 538 min (25/10), médiane de 3 à 6 h certains
-- jours. La nuit, rien ne partait.
--
-- Correctif : passer par `app.appeler_fonction_edge`, qui lit la clé
-- `service_role_key` dans le Vault (comme `studio_reveiller_sur_file`).
-- Le déclencheur ne doit JAMAIS empêcher l'insertion d'une alerte : il avale
-- l'erreur. Le cron, lui, échoue bruyamment (visible dans cron.job_run_details).
-- ============================================================================

CREATE OR REPLACE FUNCTION app.app_run_send_push_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM app.appeler_fonction_edge('send-push-notifications', '{}'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION app.trg_instant_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public', 'pg_temp'
AS $function$
BEGIN
  BEGIN
    PERFORM app.appeler_fonction_edge('send-push-notifications', '{}'::jsonb);
  EXCEPTION WHEN OTHERS THEN
    -- Le cron reprendra la file dans la minute.
    RAISE WARNING 'trg_instant_push_notification: %', SQLERRM;
  END;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION app.app_run_send_push_notifications() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.trg_instant_push_notification() FROM PUBLIC, anon, authenticated;
