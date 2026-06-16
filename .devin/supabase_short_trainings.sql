-- ========================================
-- ACADEMIA - MODULE FORMATIONS COURTES NEXIUM GROUP
-- Formations internes courtes (sans dossier) + sessions + inscriptions
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE FORMATIONS COURTES
-- ========================================

CREATE TABLE IF NOT EXISTS app.short_trainings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    short_description TEXT,
    full_description TEXT,
    category TEXT,
    modality TEXT,
    duration_days INTEGER,
    price NUMERIC,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.short_trainings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_short_trainings ON app.short_trainings;
CREATE POLICY public_select_active_short_trainings
ON app.short_trainings FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.short_trainings TO authenticated;
GRANT ALL ON app.short_trainings TO service_role;

-- ========================================
-- 2) TABLE SESSIONS DE FORMATIONS COURTES
-- ========================================

CREATE TABLE IF NOT EXISTS app.short_training_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    training_id UUID NOT NULL REFERENCES app.short_trainings(id) ON DELETE CASCADE,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    location TEXT,
    capacity INTEGER,
    status TEXT NOT NULL DEFAULT 'open', -- open, closed, cancelled
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.short_training_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_public_short_training_sessions ON app.short_training_sessions;
CREATE POLICY student_select_public_short_training_sessions
ON app.short_training_sessions FOR SELECT
USING (is_active = TRUE AND status = 'open');

GRANT SELECT ON app.short_training_sessions TO authenticated;
GRANT ALL ON app.short_training_sessions TO service_role;

-- ========================================
-- 3) TABLE INSCRIPTIONS AUX FORMATIONS COURTES
-- ========================================

CREATE TABLE IF NOT EXISTS app.short_training_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.short_training_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'registered', -- registered, cancelled, attended, absent
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (session_id, user_id)
);

ALTER TABLE app.short_training_registrations
    ADD COLUMN IF NOT EXISTS contact_phone TEXT,
    ADD COLUMN IF NOT EXISTS preferred_channel TEXT,
    ADD COLUMN IF NOT EXISTS payment_method TEXT,
    ADD COLUMN IF NOT EXISTS wants_invoice BOOLEAN,
    ADD COLUMN IF NOT EXISTS company_name TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS student_last_read_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS admin_last_read_at TIMESTAMPTZ;

ALTER TABLE app.short_training_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_short_training_registrations ON app.short_training_registrations;
CREATE POLICY student_select_own_short_training_registrations
ON app.short_training_registrations FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_short_training_registrations ON app.short_training_registrations;
CREATE POLICY student_insert_own_short_training_registrations
ON app.short_training_registrations FOR INSERT
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT ON app.short_training_registrations TO authenticated;
GRANT ALL ON app.short_training_registrations TO service_role;

-- ========================================
-- 3b) TABLE MESSAGES D'INSCRIPTION À UNE FORMATION COURTE
-- ========================================

CREATE TABLE IF NOT EXISTS app.short_training_registration_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID NOT NULL REFERENCES app.short_training_registrations(id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL,
    audience TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.short_training_registration_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_short_training_registration_messages ON app.short_training_registration_messages;
CREATE POLICY student_select_own_short_training_registration_messages
ON app.short_training_registration_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.short_training_registrations r
    WHERE r.id = short_training_registration_messages.registration_id
      AND r.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_own_short_training_registration_messages ON app.short_training_registration_messages;
CREATE POLICY student_insert_own_short_training_registration_messages
ON app.short_training_registration_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.short_training_registrations r
    WHERE r.id = short_training_registration_messages.registration_id
      AND r.user_id = auth.uid()
  )
  AND sender_role = 'student'
);

GRANT SELECT, INSERT ON app.short_training_registration_messages TO authenticated;
GRANT ALL ON app.short_training_registration_messages TO service_role;

-- ========================================
-- 4) RPC ADMIN - LISTE FORMATIONS + SESSIONS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_short_trainings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', t.id,
                'title', t.title,
                'short_description', t.short_description,
                'full_description', t.full_description,
                'category', t.category,
                'modality', t.modality,
                'duration_days', t.duration_days,
                'price', t.price,
                'is_active', t.is_active,
                'created_at', t.created_at,
                'updated_at', t.updated_at,
                'sessions', COALESCE(
                    (
                        SELECT JSONB_AGG(
                                   JSONB_BUILD_OBJECT(
                                       'id', s.id,
                                       'start_at', s.start_at,
                                       'end_at', s.end_at,
                                       'location', s.location,
                                       'capacity', s.capacity,
                                       'status', s.status,
                                       'is_active', s.is_active,
                                       'created_at', s.created_at,
                                       'updated_at', s.updated_at
                                   )
                                   ORDER BY s.start_at ASC
                               )
                        FROM app.short_training_sessions s
                        WHERE s.training_id = t.id
                    ),
                    '[]'::JSONB
                )
            )
            ORDER BY t.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.short_trainings t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'trainings', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_short_trainings() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_short_trainings() TO service_role;

-- ========================================
-- 5) RPC ADMIN - UPSERT FORMATION COURTE
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_short_training(
    p_training_id UUID,
    p_title TEXT,
    p_short_description TEXT,
    p_full_description TEXT,
    p_category TEXT,
    p_modality TEXT,
    p_duration_days INTEGER,
    p_price NUMERIC,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_training_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_training_id IS NULL THEN
        INSERT INTO app.short_trainings (
            title,
            short_description,
            full_description,
            category,
            modality,
            duration_days,
            price,
            is_active,
            created_by
        )
        VALUES (
            p_title,
            p_short_description,
            p_full_description,
            p_category,
            p_modality,
            p_duration_days,
            p_price,
            COALESCE(p_is_active, TRUE),
            v_user_id
        )
        RETURNING id INTO v_training_id;
    ELSE
        UPDATE app.short_trainings
        SET
            title = p_title,
            short_description = p_short_description,
            full_description = p_full_description,
            category = p_category,
            modality = p_modality,
            duration_days = p_duration_days,
            price = p_price,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_training_id
        RETURNING id INTO v_training_id;
    END IF;

    IF v_training_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'training_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'training_id', v_training_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_short_training(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_short_training(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, BOOLEAN) TO service_role;

-- ========================================
-- 6) RPC ADMIN - UPSERT SESSION DE FORMATION COURTE
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_short_training_session(
    p_session_id UUID,
    p_training_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ,
    p_location TEXT,
    p_capacity INTEGER,
    p_status TEXT,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_session_id UUID;
    v_training_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_training_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'training_required');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM app.short_trainings t WHERE t.id = p_training_id
    ) INTO v_training_exists;

    IF NOT v_training_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'training_not_found');
    END IF;

    IF p_start_at IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'start_at_required');
    END IF;

    IF p_status IS NULL OR LENGTH(TRIM(p_status)) = 0 THEN
        p_status := 'open';
    END IF;

    IF p_session_id IS NULL THEN
        INSERT INTO app.short_training_sessions (
            training_id,
            start_at,
            end_at,
            location,
            capacity,
            status,
            is_active
        )
        VALUES (
            p_training_id,
            p_start_at,
            p_end_at,
            p_location,
            p_capacity,
            p_status,
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_session_id;
    ELSE
        UPDATE app.short_training_sessions
        SET
            training_id = p_training_id,
            start_at = p_start_at,
            end_at = p_end_at,
            location = p_location,
            capacity = p_capacity,
            status = p_status,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_session_id
        RETURNING id INTO v_session_id;
    END IF;

    IF v_session_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'session_id', v_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_short_training_session(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_short_training_session(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- ========================================
-- 7) RPC ADMIN - LISTE DES INSCRIPTIONS D'UNE SESSION
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_short_training_registrations(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_session_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_required');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'registration_id', r.id,
                'user_id', r.user_id,
                'status', r.status,
                'created_at', r.created_at,
                'updated_at', r.updated_at,
                'contact_phone', r.contact_phone,
                'preferred_channel', r.preferred_channel,
                'payment_method', r.payment_method,
                'wants_invoice', r.wants_invoice,
                'company_name', r.company_name,
                'notes', r.notes,
                'last_message_at', r.last_message_at,
                'student_last_read_at', r.student_last_read_at,
                'admin_last_read_at', r.admin_last_read_at,
                'student_full_name', s.full_name,
                'student_profile_phone', s.phone,
                'student_email', u.email
            )
            ORDER BY r.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.short_training_registrations r
    LEFT JOIN app.students s ON s.id = r.user_id
    LEFT JOIN auth.users u ON u.id = r.user_id
    WHERE r.session_id = p_session_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'registrations', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_short_training_registrations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_short_training_registrations(UUID) TO service_role;

-- ========================================
-- 8) RPC ÉTUDIANT - LISTE DES SESSIONS PUBLIQUES À VENIR
-- ========================================

CREATE OR REPLACE FUNCTION app_list_public_short_training_sessions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'session_id', s.id,
                'training_id', t.id,
                'title', t.title,
                'short_description', t.short_description,
                'category', t.category,
                'modality', t.modality,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'location', s.location,
                'capacity', s.capacity,
                'status', s.status,
                'price', t.price
            )
            ORDER BY s.start_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.short_training_sessions s
    JOIN app.short_trainings t ON t.id = s.training_id
    WHERE s.is_active = TRUE
      AND t.is_active = TRUE
      AND s.status = 'open'
      AND s.start_at >= NOW();

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_public_short_training_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_public_short_training_sessions() TO service_role;

-- ========================================
-- 9) RPC ÉTUDIANT - LISTE DES FORMATIONS COURTES DE L'ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_list_my_short_trainings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'registration_id', r.id,
                'session_id', s.id,
                'training_id', t.id,
                'title', t.title,
                'short_description', t.short_description,
                'category', t.category,
                'modality', t.modality,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'location', s.location,
                'status', r.status,
                'created_at', r.created_at,
                'last_message_at', r.last_message_at,
                'student_last_read_at', r.student_last_read_at,
                'admin_last_read_at', r.admin_last_read_at
            )
            ORDER BY s.start_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.short_training_registrations r
    JOIN app.short_training_sessions s ON s.id = r.session_id
    JOIN app.short_trainings t ON t.id = s.training_id
    WHERE r.user_id = v_user_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_my_short_trainings() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_my_short_trainings() TO service_role;

-- ========================================
-- 10) RPC ÉTUDIANT - INSCRIPTION À UNE SESSION DE FORMATION COURTE
-- ========================================

CREATE OR REPLACE FUNCTION app_register_short_training(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_session_id UUID;
    v_training_id UUID;
    v_capacity INTEGER;
    v_status TEXT;
    v_start_at TIMESTAMPTZ;
    v_current_count INTEGER;
    v_registration_id UUID;
    v_existing_status TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_session_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_required');
    END IF;

    SELECT s.id, s.training_id, s.capacity, s.status, s.start_at
    INTO v_session_id, v_training_id, v_capacity, v_status, v_start_at
    FROM app.short_training_sessions s
    JOIN app.short_trainings t ON t.id = s.training_id
    WHERE s.id = p_session_id
      AND s.is_active = TRUE
      AND t.is_active = TRUE;

    IF v_session_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    IF v_status <> 'open' OR v_start_at < NOW() THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_closed');
    END IF;

    SELECT id, status
    INTO v_registration_id, v_existing_status
    FROM app.short_training_registrations
    WHERE session_id = v_session_id
      AND user_id = v_user_id;

    IF v_registration_id IS NOT NULL AND v_existing_status = 'registered' THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', 'already_registered');
    END IF;

    IF v_capacity IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_current_count
        FROM app.short_training_registrations r
        WHERE r.session_id = v_session_id
          AND r.status = 'registered';

        IF v_current_count >= v_capacity THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_full');
        END IF;
    END IF;

    IF v_registration_id IS NULL THEN
        INSERT INTO app.short_training_registrations (
            session_id,
            user_id,
            status
        )
        VALUES (
            v_session_id,
            v_user_id,
            'registered'
        )
        RETURNING id INTO v_registration_id;
    ELSE
        UPDATE app.short_training_registrations
        SET status = 'registered',
            updated_at = NOW()
        WHERE id = v_registration_id;
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', 'registered');
END;
$$;

GRANT EXECUTE ON FUNCTION app_register_short_training(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_register_short_training(UUID) TO service_role;

-- ========================================
-- 11) RPC ÉTUDIANT - INSCRIPTION AVEC COORDONNÉES DÉTAILLÉES
-- ========================================

CREATE OR REPLACE FUNCTION app_register_short_training_full(
    p_session_id UUID,
    p_contact_phone TEXT,
    p_preferred_channel TEXT,
    p_payment_method TEXT,
    p_wants_invoice BOOLEAN,
    p_company_name TEXT,
    p_notes TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
    v_success BOOLEAN;
    v_registration_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT app_register_short_training(p_session_id)
    INTO v_result;

    IF v_result IS NULL OR (v_result->>'success')::BOOLEAN IS DISTINCT FROM TRUE THEN
        RETURN v_result;
    END IF;

    SELECT id
    INTO v_registration_id
    FROM app.short_training_registrations
    WHERE session_id = p_session_id
      AND user_id = v_user_id;

    IF v_registration_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'registration_not_found');
    END IF;

    UPDATE app.short_training_registrations
    SET
        contact_phone = p_contact_phone,
        preferred_channel = p_preferred_channel,
        payment_method = p_payment_method,
        wants_invoice = p_wants_invoice,
        company_name = p_company_name,
        notes = p_notes,
        updated_at = NOW()
    WHERE id = v_registration_id;

    RETURN v_result || JSONB_BUILD_OBJECT('registration_id', v_registration_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_register_short_training_full(UUID, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_register_short_training_full(UUID, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT) TO service_role;

-- ========================================
-- 12) RPC MESSAGES FORMATIONS COURTES - ÉTUDIANT & ADMIN
-- ========================================

CREATE OR REPLACE FUNCTION app_list_short_training_messages_for_student(
    p_registration_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'registration_id', m.registration_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.short_training_registration_messages m
    JOIN app.short_training_registrations r ON r.id = m.registration_id
    WHERE m.registration_id = p_registration_id
      AND r.user_id = v_user_id
      AND (m.sender_role = 'student' OR m.audience = 'student');

    UPDATE app.short_training_registrations
    SET student_last_read_at = NOW()
    WHERE id = p_registration_id
      AND user_id = v_user_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_short_training_messages_for_student(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_short_training_messages_for_student(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_add_short_training_message_from_student(
    p_registration_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT user_id
    INTO v_owner_id
    FROM app.short_training_registrations
    WHERE id = p_registration_id;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'registration_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.short_training_registration_messages (registration_id, sender_role, audience, content)
    VALUES (p_registration_id, 'student', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.short_training_registrations
    SET last_message_at = NOW(), updated_at = NOW()
    WHERE id = p_registration_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_short_training_message_from_student(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_short_training_message_from_student(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_list_short_training_messages_for_admin(
    p_registration_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.short_training_registrations r WHERE r.id = p_registration_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'registration_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'registration_id', m.registration_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.short_training_registration_messages m
    WHERE m.registration_id = p_registration_id;

    UPDATE app.short_training_registrations
    SET admin_last_read_at = NOW()
    WHERE id = p_registration_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_short_training_messages_for_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_short_training_messages_for_admin(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_add_short_training_message_from_admin_to_student(
    p_registration_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.short_training_registrations r WHERE r.id = p_registration_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'registration_not_found');
    END IF;

    INSERT INTO app.short_training_registration_messages (registration_id, sender_role, audience, content)
    VALUES (p_registration_id, 'admin', 'student', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.short_training_registrations
    SET last_message_at = NOW(), updated_at = NOW()
    WHERE id = p_registration_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_short_training_message_from_admin_to_student(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_short_training_message_from_admin_to_student(UUID, TEXT) TO service_role;
