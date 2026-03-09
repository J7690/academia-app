-- ========================================
-- ACADEMIA - ADMIN USERS
-- Enable merchant role in user invitations
-- ========================================

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

    IF v_target_role NOT IN ('admin', 'university', 'instructor', 'merchant') THEN
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
