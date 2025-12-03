CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.user_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    role TEXT NOT NULL,
    university_id UUID REFERENCES app.universities (id) ON DELETE SET NULL,
    full_name TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_by_admin_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.user_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_user_invitations ON app.user_invitations;
CREATE POLICY admin_all_user_invitations
ON app.user_invitations
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.user_invitations TO authenticated;
GRANT ALL ON app.user_invitations TO service_role;

CREATE OR REPLACE FUNCTION app_admin_create_user_invitation(
    p_email TEXT,
    p_role TEXT,
    p_university_id UUID DEFAULT NULL,
    p_full_name TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_admin_role TEXT;
    v_token TEXT;
    v_id UUID;
    v_lower_email TEXT;
    v_target_role TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_admin_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_admin_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_email IS NULL OR LENGTH(TRIM(p_email)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_email');
    END IF;

    v_lower_email := LOWER(TRIM(p_email));

    IF p_role IS NULL OR LENGTH(TRIM(p_role)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_role');
    END IF;

    v_target_role := TRIM(p_role);

    IF v_target_role NOT IN ('admin', 'university', 'instructor') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unsupported_role');
    END IF;

    IF v_target_role = 'university' AND p_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_required');
    END IF;

    v_token := encode(gen_random_bytes(16), 'hex');

    INSERT INTO app.user_invitations (
        token,
        email,
        role,
        university_id,
        full_name,
        notes,
        status,
        created_by_admin_id,
        created_at,
        used_at,
        expires_at,
        updated_at
    )
    VALUES (
        v_token,
        v_lower_email,
        v_target_role,
        p_university_id,
        p_full_name,
        p_notes,
        'pending',
        v_user_id,
        NOW(),
        NULL,
        p_expires_at,
        NOW()
    )
    RETURNING id INTO v_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'invitation_id', v_id,
        'token', v_token
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_create_user_invitation(TEXT, TEXT, UUID, TEXT, TEXT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_create_user_invitation(TEXT, TEXT, UUID, TEXT, TEXT, TIMESTAMPTZ) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_user_invitations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_admin_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_admin_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_admin_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', i.id,
                'token', i.token,
                'email', i.email,
                'role', i.role,
                'university_id', i.university_id,
                'full_name', i.full_name,
                'notes', i.notes,
                'status', i.status,
                'created_by_admin_id', i.created_by_admin_id,
                'created_at', i.created_at,
                'used_at', i.used_at,
                'expires_at', i.expires_at,
                'updated_at', i.updated_at
            )
            ORDER BY i.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.user_invitations i;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'invitations', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_user_invitations() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_user_invitations() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_cancel_user_invitation(
    p_invitation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_admin_role TEXT;
    v_updated_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_admin_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_admin_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    UPDATE app.user_invitations
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_invitation_id
      AND status = 'pending'
    RETURNING id INTO v_updated_id;

    IF v_updated_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invitation_not_found_or_not_pending');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'invitation_id', v_updated_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_cancel_user_invitation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_cancel_user_invitation(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_accept_user_invitation(
    p_token TEXT,
    p_full_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_email TEXT;
    v_invitation_id UUID;
    v_inv_email TEXT;
    v_inv_role TEXT;
    v_inv_university_id UUID;
    v_status TEXT;
    v_expires_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ := NOW();
    v_meta JSONB;
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT email, raw_user_meta_data
    INTO v_email, v_meta
    FROM auth.users
    WHERE id = v_user_id;

    IF v_email IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
    END IF;

    SELECT id, email, role, university_id, status, expires_at
    INTO v_invitation_id, v_inv_email, v_inv_role, v_inv_university_id, v_status, v_expires_at
    FROM app.user_invitations
    WHERE token = p_token
    LIMIT 1;

    IF v_invitation_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invitation_not_found');
    END IF;

    IF LOWER(v_inv_email) <> LOWER(v_email) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'email_mismatch');
    END IF;

    IF v_status <> 'pending' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invitation_not_pending');
    END IF;

    IF v_expires_at IS NOT NULL AND v_expires_at <= v_now THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invitation_expired');
    END IF;

    v_meta := COALESCE(v_meta, '{}'::JSONB);

    IF v_inv_role = 'university' THEN
        IF v_inv_university_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invitation_missing_university');
        END IF;
        v_meta := v_meta
            || JSONB_BUILD_OBJECT('role', 'university')
            || JSONB_BUILD_OBJECT('university_id', v_inv_university_id::TEXT);
    ELSIF v_inv_role = 'instructor' THEN
        v_meta := v_meta || JSONB_BUILD_OBJECT('role', 'instructor');
    ELSIF v_inv_role = 'admin' THEN
        v_meta := v_meta || JSONB_BUILD_OBJECT('role', 'admin');
    ELSE
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unsupported_role');
    END IF;

    IF p_full_name IS NOT NULL AND LENGTH(TRIM(p_full_name)) > 0 THEN
        v_meta := v_meta || JSONB_BUILD_OBJECT('full_name', TRIM(p_full_name));
    END IF;

    UPDATE auth.users
    SET raw_user_meta_data = v_meta
    WHERE id = v_user_id;

    IF v_inv_role = 'instructor' THEN
        SELECT EXISTS(SELECT 1 FROM app.instructors WHERE id = v_user_id)
        INTO v_exists;

        IF NOT v_exists THEN
            INSERT INTO app.instructors (id, full_name)
            VALUES (v_user_id, NULLIF(TRIM(p_full_name), ''));
        ELSE
            UPDATE app.instructors
            SET full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
                updated_at = NOW()
            WHERE id = v_user_id;
        END IF;
    END IF;

    UPDATE app.user_invitations
    SET status = 'used',
        used_at = v_now,
        updated_at = v_now
    WHERE id = v_invitation_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'role', v_inv_role
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_accept_user_invitation(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_accept_user_invitation(TEXT, TEXT) TO service_role;
