-- ============================================================================
-- Alerte administrateur quand un étudiant sollicite Bobodo (29/10/2026)
-- ============================================================================
-- Constat mesuré le 29/10 : `app.notification_events` ne contient AUCUN
-- événement `admin_bobodo` depuis l'origine. Le seul déclencheur sur
-- `app.bobodo_messages` (`app_notify_bobodo_message`) ne prévient que
-- l'étudiant, quand Bobodo lui répond. L'Edge Function savait afficher
-- « 🤖 Bobodo » aux admins, mais personne n'émettait l'événement.
--
-- Règle : une alerte au PREMIER message étudiant d'une session, puis de
-- nouveau si l'étudiant revient après 30 min de silence. Pas une par message :
-- une conversation de vingt questions ne doit pas faire vingt sonneries.
--
-- Mêmes destinataires que l'alerte support (`app_notify_admin_new_support_
-- conversation`) : tous les comptes dont le rôle est `admin`.
--
-- VALEUR COUPLÉE : domaine `admin_bobodo`, type `new_question`, clés
-- `student_name` et `content_preview` — lues par `send-push-notifications`
-- (buildFcmMessage) et routées par `notification_router.dart`.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_notify_admin_bobodo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
    v_student_id UUID;
    v_nom TEXT;
    v_admin RECORD;
BEGIN
    IF NEW.sender <> 'student' THEN
        RETURN NEW;
    END IF;

    -- Déjà sollicité dans cette session il y a moins de 30 min : on se tait.
    IF EXISTS (
        SELECT 1 FROM app.bobodo_messages m
         WHERE m.session_id = NEW.session_id
           AND m.sender = 'student'
           AND m.id <> NEW.id
           AND m.created_at > NEW.created_at - INTERVAL '30 minutes'
           AND m.created_at <= NEW.created_at
    ) THEN
        RETURN NEW;
    END IF;

    SELECT s.student_id INTO v_student_id
      FROM app.bobodo_sessions s
     WHERE s.id = NEW.session_id;

    SELECT COALESCE(NULLIF(TRIM(st.full_name), ''),
                    NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
                    u.email, u.phone, 'Un étudiant')
      INTO v_nom
      FROM auth.users u
      LEFT JOIN app.students st ON st.id = u.id
     WHERE u.id = v_student_id;

    FOR v_admin IN
        SELECT id FROM auth.users
         WHERE raw_user_meta_data->>'role' = 'admin'
    LOOP
        PERFORM app_queue_notification_event(
            v_admin.id,
            'admin_bobodo',
            'new_question',
            JSONB_BUILD_OBJECT(
                'session_id', NEW.session_id,
                'message_id', NEW.id,
                'student_id', v_student_id,
                'student_name', COALESCE(v_nom, 'Un étudiant'),
                'content_preview', LEFT(REGEXP_REPLACE(COALESCE(NEW.content, ''), '\s+', ' ', 'g'), 90),
                'origine', NEW.origine
            )
        );
    END LOOP;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Une alerte ne doit jamais empêcher l'étudiant de parler à Bobodo.
    RAISE WARNING 'app_notify_admin_bobodo: %', SQLERRM;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.app_notify_admin_bobodo() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notify_admin_bobodo ON app.bobodo_messages;
CREATE TRIGGER trg_notify_admin_bobodo
AFTER INSERT ON app.bobodo_messages
FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_bobodo();
