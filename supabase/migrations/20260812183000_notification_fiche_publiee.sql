-- Notification « fiche de séance publiée » aux participants (12/08/2026).
--
-- ⚠️ NON APPLIQUÉE — en attente du feu vert de Jocelyn (écriture en prod).
--
-- Décision (conversation du 12/08) : à la publication de la fiche par l'hôte,
-- notifier les PARTICIPANTS de la séance, par push + in-app. Pas d'e-mail PDF
-- pour l'instant (reporté jusqu'à mesure d'usage réelle).
--
-- Le circuit réutilisé est celui des 29 notifications existantes :
-- `app.fn_enqueue_notification_event` → `app.notification_events` →
-- Edge Function `send-push-notifications` (cron + déclencheur applicatif).
--
-- Garde-fous :
--   · on ne notifie qu'au PASSAGE à publié (un « Retirer » puis « Publier »
--     de correction ne re-spamme pas les étudiants) ;
--   · jamais l'hôte lui-même ;
--   · le payload ne contient que session_id, titre et type — jamais le
--     contenu de la fiche, encore moins la version host ou les notes internes.
--
-- Base : définition de production rapatriée le 12/08
-- (20260812170000_rapatriement_fiche_seance_learning.sql). Seul le bloc
-- « notification » est ajouté ; le reste est inchangé à l'octet près.
--
-- VALEUR COUPLÉE — à modifier des DEUX côtés :
--   domaine `student_lives` + type `fiche_publiee` sont attendus par
--   `send-push-notifications/index.ts` (buildFcmMessage) et par
--   `notification_router.dart` côté Flutter.

CREATE OR REPLACE FUNCTION public.app_learning_publish_summary(p_session_id uuid, p_content jsonb DEFAULT NULL::jsonb, p_publish boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_host uuid;
  v_session record;
  v_was_published boolean;
  v_participant record;
  v_notified integer := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentification requise.');
  END IF;

  SELECT host_id, title, session_type INTO v_session
    FROM app.academia_sessions WHERE id = p_session_id;
  v_host := v_session.host_id;
  IF v_host IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Séance introuvable.');
  END IF;
  IF v_host IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seul l''enseignant peut publier la fiche.');
  END IF;

  SELECT is_published INTO v_was_published
    FROM app.academia_session_summaries
   WHERE session_id = p_session_id AND audience = 'student';

  UPDATE app.academia_session_summaries
     SET content = coalesce(p_content, content),
         is_published = p_publish,
         edited_by = CASE WHEN p_content IS NULL THEN edited_by ELSE v_user END,
         edited_at = CASE WHEN p_content IS NULL THEN edited_at ELSE now() END,
         updated_at = now()
   WHERE session_id = p_session_id AND audience = 'student';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aucune fiche à publier pour cette séance.');
  END IF;

  -- Notification : uniquement au PASSAGE à publié, jamais lors d'une
  -- republication de correction, jamais à l'hôte.
  IF p_publish AND NOT coalesce(v_was_published, false) THEN
    FOR v_participant IN
      SELECT DISTINCT pa.user_id
        FROM app.academia_session_participants pa
       WHERE pa.session_id = p_session_id
         AND pa.user_id IS DISTINCT FROM v_host
    LOOP
      PERFORM app.fn_enqueue_notification_event(
        v_participant.user_id,
        'student_lives',
        'fiche_publiee',
        jsonb_build_object(
          'session_id', p_session_id,
          'session_title', coalesce(v_session.title, ''),
          'session_type', coalesce(v_session.session_type, '')
        )
      );
      v_notified := v_notified + 1;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('success', true, 'published', p_publish, 'notified', v_notified);
END;
$function$;
