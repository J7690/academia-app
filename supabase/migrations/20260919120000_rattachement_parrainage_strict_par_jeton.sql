-- ============================================================
-- Restauration du rattachement commercial, cette fois STRICT :
-- le client doit presenter un jeton (cree par referral-redirect),
-- pas un code brut que n'importe qui peut saisir.
--
-- Ce qui change :
--   1. app_register_referral_for_current_user prend p_token au lieu de p_ref_code
--   2. app_resolve_referral_token n'est plus necessaire cote client
--   3. Le role est lu depuis raw_app_meta_data (service-role only)
-- ============================================================

-- 1. Remplacer la RPC d'attachement : jeton obligatoire, role verifie
CREATE OR REPLACE FUNCTION public.app_register_referral_for_current_user(
    p_token TEXT,
    p_source TEXT DEFAULT 'link'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_user_id       UUID := auth.uid();
    v_role          TEXT;
    v_token_row     app.referral_tokens%ROWTYPE;
    v_ref_code      TEXT;
    v_existing      UUID;
    v_referral_id   UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Le role DOIT venir de raw_app_meta_data (pose par service-role),
    -- pas de raw_user_meta_data (modifiable par l'utilisateur).
    SELECT raw_app_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF COALESCE(v_role, 'student') <> 'student' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'only_students');
    END IF;

    -- Un seul rattachement par etudiant, jamais.
    SELECT id INTO v_existing
    FROM app.user_referrals WHERE student_id = v_user_id LIMIT 1;

    IF v_existing IS NOT NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_referred');
    END IF;

    -- Valider le jeton
    IF p_token IS NULL OR length(trim(p_token)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_token');
    END IF;

    SELECT * INTO v_token_row
    FROM app.referral_tokens
    WHERE token = upper(trim(p_token))
      AND expires_at > NOW()
      AND used_at IS NULL;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'token_invalid_or_expired');
    END IF;

    -- Verifier que le commercial est toujours actif
    SELECT ref_code INTO v_ref_code
    FROM app.commercial_profiles
    WHERE user_id = v_token_row.commercial_id
      AND is_active = TRUE;

    IF v_ref_code IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commercial_inactive');
    END IF;

    -- Un etudiant ne peut pas se rattacher a lui-meme
    IF v_user_id = v_token_row.commercial_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'self_referral');
    END IF;

    -- Marquer le jeton comme utilise
    UPDATE app.referral_tokens
    SET used_at = NOW(),
        used_by = v_user_id
    WHERE id = v_token_row.id;

    -- Creer le rattachement
    INSERT INTO app.user_referrals (student_id, commercial_user_id, source, ref_code)
    VALUES (v_user_id, v_token_row.commercial_id, COALESCE(p_source, 'link'), v_ref_code)
    RETURNING id INTO v_referral_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'referral_id', v_referral_id,
        'commercial_id', v_token_row.commercial_id
    );
END;
$function$;

-- 2. Supprimer l'ancienne surcharge (p_ref_code, p_source, p_metadata)
--    qui acceptait un code brut sans preuve de clic.
DROP FUNCTION IF EXISTS public.app_register_referral_for_current_user(text, text, jsonb);

-- 3. Revoquer app_resolve_referral_token pour anon : seul le serveur
--    en a besoin, et la nouvelle RPC combine les deux etapes.
REVOKE ALL ON FUNCTION public.app_resolve_referral_token(text) FROM anon;
