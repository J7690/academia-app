-- ========================================
-- ACADEMIA - MODULE NOTIFICATIONS GENERIQUES
-- Suivi de la derniere consultation par utilisateur et domaine logique
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE ETAT DE LECTURE PAR UTILISATEUR / DOMAINE
-- ========================================

CREATE TABLE IF NOT EXISTS app.user_notification_state (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, domain)
);

ALTER TABLE app.user_notification_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notification_state_self ON app.user_notification_state;
CREATE POLICY user_notification_state_self
ON app.user_notification_state
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON app.user_notification_state TO authenticated;
GRANT ALL ON app.user_notification_state TO service_role;

-- ========================================
-- 2) RPC - MARQUER UN DOMAINE COMME VU
-- ========================================

CREATE OR REPLACE FUNCTION app_mark_domain_seen(
    p_domain TEXT
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

    IF p_domain IS NULL OR LENGTH(TRIM(p_domain)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_domain');
    END IF;

    INSERT INTO app.user_notification_state (user_id, domain, last_seen_at)
    VALUES (v_user_id, p_domain, NOW())
    ON CONFLICT (user_id, domain)
    DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_mark_domain_seen(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_mark_domain_seen(TEXT) TO service_role;

-- ========================================
-- 3) RPC - RESUME DES NOTIFICATIONS PAR ROLE / DOMAINE
-- ========================================

CREATE OR REPLACE FUNCTION app_get_notification_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'role_not_defined');
    END IF;

    -- ========================================
    -- Etudiant : contenu accueil + offres + formations courtes Nexium
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
            v_has_new := FALSE;
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

        -- Formations courtes Nexium (short_trainings)
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
            v_has_new := FALSE;
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

    -- ========================================
    -- Admin : contenu programmes + mini-sites + formations courtes
    -- ========================================
    ELSIF v_role = 'admin' THEN
        -- Contenu mini-sites / universités
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
            v_has_new := FALSE;
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

        -- Formations courtes Nexium côté admin (trainings + sessions + inscriptions + messages)
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
            v_has_new := FALSE;
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
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'summary', v_summary
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_get_notification_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION app_get_notification_summary() TO service_role;
