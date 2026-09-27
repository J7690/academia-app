-- Audit notification paiement : un clic sur « Payer » créait une ligne
-- `application_payments` en statut `pending`, ce qui faisait apparaître
-- immédiatement un badge de notification (admin + étudiant) alors que la
-- transaction n'était pas aboutie.
--
-- Ce fichier fait deux choses :
-- 1. `app_get_notification_summary` ne compte plus les paiements qui ne
--    concernent pas réellement l'utilisateur (pending/processing).
-- 2. Les déclencheurs de notification push existants sont rattachés à
--    `app.application_payments` avec le filtrage déjà présent dans les
--    fonctions (uniquement `declared_by_student` / `confirmed`).

-- ── 1. Résumé de notifications : filtrer les statuts parasites ───────────────
CREATE OR REPLACE FUNCTION public.app_get_notification_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_summary JSONB := '{}'::JSONB;
    v_last_seen TIMESTAMPTZ;
    v_max_updated TIMESTAMPTZ;
    v_has_new BOOLEAN;
    v_new_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'role_not_defined');
    END IF;

    -- ========================================
    -- Etudiant
    -- ========================================
    IF v_role = 'student' THEN
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'student_home';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.student_home_announcements WHERE is_active = TRUE), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.student_home_videos WHERE is_active = TRUE), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(p.updated_at)
                             FROM app.programs p
                             JOIN app.universities u ON u.id = p.university_id
                             WHERE p.is_active = TRUE AND u.is_active = TRUE), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'student_home', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Formations courtes Nexium
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'short_trainings';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.short_trainings WHERE is_active = TRUE), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.short_training_sessions WHERE is_active = TRUE AND status = 'open'), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(last_message_at)
                             FROM app.short_training_registrations r
                             WHERE r.user_id = v_user_id), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'short_trainings', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Paiements c�té étudiant : on ignore pending/processing/declared_by_student
        -- (le pending est créé au clic sur Payer, pas une info utile en badge).
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'student_payments';

        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0))
        INTO v_max_updated
        FROM app.application_payments
        WHERE student_id = v_user_id
          AND status IN ('confirmed', 'failed', 'rejected', 'under_verification');

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.application_payments
                WHERE student_id = v_user_id
                  AND updated_at > v_last_seen
                  AND status IN ('confirmed', 'failed', 'rejected', 'under_verification');
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'student_payments', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Candidatures c�té étudiant
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'student_applications';

        SELECT COALESCE(
                   MAX(GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at))),
                   TO_TIMESTAMP(0)
               )
        INTO v_max_updated
        FROM app.applications a
        WHERE a.student_id = v_user_id;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.applications a
                WHERE a.student_id = v_user_id
                  AND GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) > v_last_seen;
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'student_applications', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Opportunités c�té étudiant
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'student_opportunities';

        SELECT COALESCE(
                   MAX(GREATEST(o.updated_at, COALESCE(o.last_message_at, o.updated_at))),
                   TO_TIMESTAMP(0)
               )
        INTO v_max_updated
        FROM app.opportunities o;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.opportunities o
                WHERE GREATEST(o.updated_at, COALESCE(o.last_message_at, o.updated_at)) > v_last_seen;
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'student_opportunities', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

    -- ========================================
    -- Admin
    -- ========================================
    ELSIF v_role = 'admin' THEN
        -- Candidatures c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_applications';

        SELECT COALESCE(
                   MAX(GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at))),
                   TO_TIMESTAMP(0)
               )
        INTO v_max_updated
        FROM app.applications a;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.applications a
                WHERE GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) > v_last_seen;
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_applications', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Paiements c�té admin : pending/processing ne doivent pas signaler un badge.
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_payments';

        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0))
        INTO v_max_updated
        FROM app.application_payments
        WHERE status IN ('declared_by_student', 'under_verification', 'confirmed', 'rejected');

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.application_payments
                WHERE updated_at > v_last_seen
                  AND status IN ('declared_by_student', 'under_verification', 'confirmed', 'rejected');
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_payments', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Opportunités c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_opportunities';

        SELECT COALESCE(
                   MAX(o.updated_at),
                   TO_TIMESTAMP(0)
               )
        INTO v_max_updated
        FROM app.opportunities o;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.opportunities o
                WHERE o.updated_at > v_last_seen;
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_opportunities', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Communautés c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_communities';

        SELECT COALESCE(
                   MAX(p.updated_at),
                   TO_TIMESTAMP(0)
               )
        INTO v_max_updated
        FROM app.community_posts p
        WHERE p.is_deleted = FALSE;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.community_posts p
                WHERE p.is_deleted = FALSE
                  AND p.updated_at > v_last_seen;
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_communities', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Formations courtes Nexium c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_short_trainings';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.short_trainings), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.short_training_sessions), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(created_at) FROM app.short_training_registrations), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(last_message_at) FROM app.short_training_registrations), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_short_trainings', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Mini-sites / universités c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_university_content';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.programs), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_site_blocks), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_media), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_site_config), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_site_banners), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_events), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_news), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_staff), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_university_content', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Bobodo c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_bobodo';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.bobodo_sessions), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(created_at) FROM app.bobodo_messages), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(created_at) FROM app.bobodo_unanswered_questions), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(created_at) FROM app.bobodo_detected_needs), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_bobodo', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Prépa concours c�té admin
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'admin_prep_concours';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.prep_subjects), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.prep_chapters), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.prep_questions), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(created_at) FROM app.prep_exams), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'admin_prep_concours', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

    -- ========================================
    -- Université partenaire
    -- ========================================
    ELSIF v_role = 'university' THEN
        -- Candidatures c�té université
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'university_applications';

        SELECT COALESCE(
                   MAX(GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at))),
                   TO_TIMESTAMP(0)
               )
        INTO v_max_updated
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        JOIN app.universities u ON u.id = p.university_id
        WHERE u.owner_user_id = v_user_id;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
            v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN
                SELECT COUNT(*)
                INTO v_new_count
                FROM app.applications a
                JOIN app.programs p ON p.id = a.program_id
                JOIN app.universities u ON u.id = p.university_id
                WHERE u.owner_user_id = v_user_id
                  AND GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) > v_last_seen;
            ELSE
                v_new_count := 0;
            END IF;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'university_applications', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

        -- Mini-site & offres c�té université
        SELECT last_seen_at
        INTO v_last_seen
        FROM app.user_notification_state
        WHERE user_id = v_user_id
          AND domain = 'university_site_content';

        SELECT GREATEST(
                   COALESCE((SELECT MAX(updated_at) FROM app.university_site_blocks), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_media), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_site_config), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_site_banners), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_events), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_news), TO_TIMESTAMP(0)),
                   COALESCE((SELECT MAX(updated_at) FROM app.university_staff), TO_TIMESTAMP(0))
               )
        INTO v_max_updated;

        IF v_last_seen IS NULL THEN
            v_has_new := (v_max_updated > TO_TIMESTAMP(0));
        ELSE
            v_has_new := v_max_updated > v_last_seen;
        END IF;

        IF v_has_new THEN
            v_new_count := 1;
        ELSE
            v_new_count := 0;
        END IF;

        v_summary := v_summary || JSONB_BUILD_OBJECT(
            'university_site_content', JSONB_BUILD_OBJECT(
                'has_new', v_has_new,
                'new_count', v_new_count
            )
        );

    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'summary', v_summary
    );
END;
$function$;

-- ── 2. Rattacher les déclencheurs de notification push ───────────────────────
DROP TRIGGER IF EXISTS trg_admin_payment_declared_notify ON app.application_payments;
CREATE TRIGGER trg_admin_payment_declared_notify
    AFTER INSERT OR UPDATE ON app.application_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.app_notify_admin_payment_declared();

DROP TRIGGER IF EXISTS trg_uni_payment_notify ON app.application_payments;
CREATE TRIGGER trg_uni_payment_notify
    AFTER INSERT OR UPDATE ON app.application_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.app_notify_university_payment();

DROP TRIGGER IF EXISTS trg_commercial_prospect_payment_notify ON app.application_payments;
CREATE TRIGGER trg_commercial_prospect_payment_notify
    AFTER INSERT OR UPDATE ON app.application_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.app_notify_commercial_prospect_payment();

DROP TRIGGER IF EXISTS trg_commercial_payment_confirmed_notify ON app.application_payments;
CREATE TRIGGER trg_commercial_payment_confirmed_notify
    AFTER UPDATE ON app.application_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.app_notify_commercial_payment_confirmed();

-- ── 3. Le push côté étudiant ne doit pas partir sur pending → processing ─────
-- `app_notify_student_payment_status` notifiait sur *tout* changement de
-- statut. Le passage `pending → processing` (initiation LigdiCash) déclenchait
-- donc une notification « paiement en attente » alors que l'étudiant n'avait
-- pas abouti sa transaction. On garde uniquement les statuts qui justifient
-- une alerte : confirmed, failed, rejected, under_verification.
CREATE OR REPLACE FUNCTION public.app_notify_student_payment_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE v_student_name TEXT; v_program_name TEXT;
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status IN ('confirmed', 'failed', 'rejected', 'under_verification')
       AND NEW.student_id IS NOT NULL THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        SELECT p.title INTO v_program_name FROM app.programs p
            JOIN app.applications a ON a.program_id = p.id
            WHERE a.id = NEW.application_id;
        PERFORM public.app_queue_notification_event(
            NEW.student_id,
            'student_payments',
            'payment_status_changed',
            JSONB_BUILD_OBJECT(
                'payment_id', NEW.id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'payment_reason', NEW.payment_reason,
                'amount_paid', COALESCE(NEW.amount_paid, 0),
                'amount_due', NEW.amount_due,
                'currency', NEW.currency,
                'program_name', COALESCE(v_program_name, ''),
                'reference_code', COALESCE(NEW.reference_code, '')
            )
        );
    END IF;
    RETURN NEW;
END;
$function$;

-- Note : app_notify_commercial_commission est appelée par un trigger sur
-- app.referral_commissions, qui sera créé ou recréé par la migration de gestion
-- des commissions si nécessaire. Ici on ne touche pas à cette table.
