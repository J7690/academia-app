-- ============================================================
-- Fix: app_resolve_referral_token ne renvoyait que commercial_id (UUID),
-- mais app_register_referral_for_current_user attend un ref_code (TEXT).
-- Sans ce fix, InstallReferrerService ne pouvait jamais rattacher
-- automatiquement un prospect venu du Play Store.
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_resolve_referral_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_token_record app.referral_tokens%ROWTYPE;
    v_user_id UUID := auth.uid();
    v_ref_code TEXT;
BEGIN
    IF p_token IS NULL OR p_token = '' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_token');
    END IF;

    SELECT * INTO v_token_record
    FROM app.referral_tokens
    WHERE token = p_token
      AND expires_at > NOW()
      AND used_at IS NULL
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'token_not_found_or_expired');
    END IF;

    SELECT ref_code INTO v_ref_code
    FROM app.commercial_profiles
    WHERE user_id = v_token_record.commercial_id
      AND is_active = TRUE
    LIMIT 1;

    IF v_ref_code IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commercial_not_found');
    END IF;

    UPDATE app.referral_tokens
    SET used_at = NOW(),
        used_by = v_user_id
    WHERE id = v_token_record.id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'commercial_id', v_token_record.commercial_id,
        'ref_code', v_ref_code,
        'token_id', v_token_record.id
    );
END;
$function$;
