-- ========================================
-- ACADEMIA - ARCHITECTURE PUSH NOTIFICATIONS (OS / FCM)
-- Tables devices + file d'événements + fonctions génériques
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE DES DEVICES UTILISATEURS (TOKENS FCM)
-- ========================================

CREATE TABLE IF NOT EXISTS app.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    device_info JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, fcm_token)
);

ALTER TABLE app.user_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_manage_own_device_tokens ON app.user_device_tokens;
CREATE POLICY user_manage_own_device_tokens
ON app.user_device_tokens
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON app.user_device_tokens TO authenticated;
GRANT ALL ON app.user_device_tokens TO service_role;

-- ========================================
-- 2) TABLE FILE D'EVENEMENTS DE NOTIFICATIONS
-- ========================================

CREATE TABLE IF NOT EXISTS app.notification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT
);

CREATE INDEX IF NOT EXISTS idx_notification_events_pending
ON app.notification_events (created_at)
WHERE processed_at IS NULL;

GRANT SELECT, INSERT, UPDATE ON app.notification_events TO service_role;

-- ========================================
-- 3) RPC - GESTION DES TOKENS FCM
-- ========================================

CREATE OR REPLACE FUNCTION app_register_device_token(
    p_platform TEXT,
    p_fcm_token TEXT,
    p_device_info JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_fcm_token IS NULL OR LENGTH(TRIM(p_fcm_token)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_token');
    END IF;

    INSERT INTO app.user_device_tokens (user_id, platform, fcm_token, device_info, is_active, last_seen_at, updated_at)
    VALUES (v_user_id, LOWER(p_platform), p_fcm_token, COALESCE(p_device_info, '{}'::JSONB), TRUE, NOW(), NOW())
    ON CONFLICT (user_id, fcm_token) DO UPDATE
        SET platform = EXCLUDED.platform,
            device_info = EXCLUDED.device_info,
            is_active = TRUE,
            last_seen_at = NOW(),
            updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_register_device_token(TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_register_device_token(TEXT, TEXT, JSONB) TO service_role;

CREATE OR REPLACE FUNCTION app_unregister_device_token(
    p_fcm_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_fcm_token IS NULL OR LENGTH(TRIM(p_fcm_token)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_token');
    END IF;

    UPDATE app.user_device_tokens
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE user_id = v_user_id
      AND fcm_token = p_fcm_token;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_unregister_device_token(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_unregister_device_token(TEXT) TO service_role;

-- ========================================
-- 4) RPC - AJOUT D'UN EVENEMENT DE NOTIFICATION
-- ========================================

CREATE OR REPLACE FUNCTION app_queue_notification_event(
    p_user_id UUID,
    p_domain TEXT,
    p_event_type TEXT,
    p_payload JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    IF p_domain IS NULL OR LENGTH(TRIM(p_domain)) = 0 THEN
        RETURN;
    END IF;

    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (p_user_id, p_domain, p_event_type, COALESCE(p_payload, '{}'::JSONB));
END;
$$;

GRANT EXECUTE ON FUNCTION app_queue_notification_event(UUID, TEXT, TEXT, JSONB) TO service_role;

-- ========================================
-- 5) FONCTION + TRIGGER - PAIEMENTS (application_payments)
-- ========================================

CREATE OR REPLACE FUNCTION app_notify_application_payment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
BEGIN
    v_student_id := NEW.student_id;
    IF v_student_id IS NOT NULL THEN
        PERFORM app_queue_notification_event(
            v_student_id,
            'student_payments',
            'payment',
            JSONB_BUILD_OBJECT('payment_id', NEW.id)
        );
    END IF;

    PERFORM app_queue_notification_event(
        (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1),
        'admin_payments',
        'payment',
        JSONB_BUILD_OBJECT('payment_id', NEW.id)
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_application_payments_notify ON app.application_payments;
CREATE TRIGGER trg_app_application_payments_notify
AFTER INSERT OR UPDATE ON app.application_payments
FOR EACH ROW
EXECUTE FUNCTION app_notify_application_payment_change();

-- ========================================
-- 6) FONCTION + TRIGGER - MESSAGES DE CANDIDATURE (application_messages)
-- ========================================

CREATE OR REPLACE FUNCTION app_notify_application_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
    v_admin_id UUID;
BEGIN
    -- Message vers l'étudiant -> notif student_applications
    IF NEW.sender_role = 'admin' AND NEW.audience IN ('student', 'student_and_admin') THEN
        SELECT student_id
        INTO v_student_id
        FROM app.applications
        WHERE id = NEW.application_id;

        IF v_student_id IS NOT NULL THEN
            PERFORM app_queue_notification_event(
                v_student_id,
                'student_applications',
                'message',
                JSONB_BUILD_OBJECT(
                    'application_id', NEW.application_id,
                    'message_id', NEW.id
                )
            );
        END IF;
    END IF;

    -- Message de l'étudiant -> notif admin_applications (tous les admins)
    IF NEW.sender_role = 'student' THEN
        FOR v_admin_id IN
            SELECT id
            FROM auth.users
            WHERE raw_user_meta_data->>'role' = 'admin'
        LOOP
            PERFORM app_queue_notification_event(
                v_admin_id,
                'admin_applications',
                'message',
                JSONB_BUILD_OBJECT(
                    'application_id', NEW.application_id,
                    'message_id', NEW.id
                )
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_application_messages_notify ON app.application_messages;
CREATE TRIGGER trg_app_application_messages_notify
AFTER INSERT ON app.application_messages
FOR EACH ROW
EXECUTE FUNCTION app_notify_application_message();

-- ========================================
-- 7) FONCTION + TRIGGER - COMMUNAUTES (community_posts)
-- ========================================

CREATE OR REPLACE FUNCTION app_notify_community_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    IF NEW.is_deleted THEN
        RETURN NEW;
    END IF;

    FOR v_user_id IN
        SELECT m.user_id
        FROM app.community_memberships m
        WHERE m.community_id = NEW.community_id
          AND m.is_active = TRUE
    LOOP
        PERFORM app_queue_notification_event(
            v_user_id,
            'student_communities',
            'message',
            JSONB_BUILD_OBJECT(
                'community_id', NEW.community_id,
                'post_id', NEW.id
            )
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_community_posts_notify ON app.community_posts;
CREATE TRIGGER trg_app_community_posts_notify
AFTER INSERT ON app.community_posts
FOR EACH ROW
EXECUTE FUNCTION app_notify_community_post();

-- ========================================
-- 8) FONCTION + TRIGGER - BOBODO (bobodo_messages)
-- ========================================

CREATE OR REPLACE FUNCTION app_notify_bobodo_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
BEGIN
    -- On ne notifie l'étudiant que pour les messages non "student" (assistant / system)
    IF NEW.sender = 'student' THEN
        RETURN NEW;
    END IF;

    SELECT s.student_id
    INTO v_student_id
    FROM app.bobodo_sessions s
    WHERE s.id = NEW.session_id;

    IF v_student_id IS NOT NULL THEN
        PERFORM app_queue_notification_event(
            v_student_id,
            'student_bobodo',
            'message',
            JSONB_BUILD_OBJECT(
                'session_id', NEW.session_id,
                'message_id', NEW.id
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_bobodo_messages_notify ON app.bobodo_messages;
CREATE TRIGGER trg_app_bobodo_messages_notify
AFTER INSERT ON app.bobodo_messages
FOR EACH ROW
EXECUTE FUNCTION app_notify_bobodo_message();

-- ========================================
-- 9) FONCTION + TRIGGERS - OPPORTUNITES (opportunities)
-- ========================================

CREATE OR REPLACE FUNCTION app_notify_opportunity_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- On notifie uniquement pour les opportunités actives et publiées
    IF NEW.is_active = TRUE AND NEW.status = 'published' THEN
        PERFORM app_queue_notification_event(
            NULL, -- broadcast éventuel géré côté worker si nécessaire
            'student_opportunities',
            'info',
            JSONB_BUILD_OBJECT('opportunity_id', NEW.id)
        );

        PERFORM app_queue_notification_event(
            (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1),
            'admin_opportunities',
            'info',
            JSONB_BUILD_OBJECT('opportunity_id', NEW.id)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_opportunities_notify ON app.opportunities;
CREATE TRIGGER trg_app_opportunities_notify
AFTER INSERT OR UPDATE ON app.opportunities
FOR EACH ROW
EXECUTE FUNCTION app_notify_opportunity_change();

-- ========================================
-- 10) FONCTION + TRIGGERS - PREPA CONCOURS (prep_*)
-- ========================================

CREATE OR REPLACE FUNCTION app_notify_prep_concours_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM app_queue_notification_event(
        NULL,
        'student_prep_concours',
        'info',
        JSONB_BUILD_OBJECT('table', TG_TABLE_NAME, 'id', NEW.id)
    );

    PERFORM app_queue_notification_event(
        (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1),
        'admin_prep_concours',
        'info',
        JSONB_BUILD_OBJECT('table', TG_TABLE_NAME, 'id', NEW.id)
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_prep_subjects_notify ON app.prep_subjects;
CREATE TRIGGER trg_app_prep_subjects_notify
AFTER INSERT OR UPDATE ON app.prep_subjects
FOR EACH ROW
EXECUTE FUNCTION app_notify_prep_concours_change();

DROP TRIGGER IF EXISTS trg_app_prep_chapters_notify ON app.prep_chapters;
CREATE TRIGGER trg_app_prep_chapters_notify
AFTER INSERT OR UPDATE ON app.prep_chapters
FOR EACH ROW
EXECUTE FUNCTION app_notify_prep_concours_change();

DROP TRIGGER IF EXISTS trg_app_prep_questions_notify ON app.prep_questions;
CREATE TRIGGER trg_app_prep_questions_notify
AFTER INSERT OR UPDATE ON app.prep_questions
FOR EACH ROW
EXECUTE FUNCTION app_notify_prep_concours_change();

DROP TRIGGER IF EXISTS trg_app_prep_exams_notify ON app.prep_exams;
CREATE TRIGGER trg_app_prep_exams_notify
AFTER INSERT OR UPDATE ON app.prep_exams
FOR EACH ROW
EXECUTE FUNCTION app_notify_prep_concours_change();
