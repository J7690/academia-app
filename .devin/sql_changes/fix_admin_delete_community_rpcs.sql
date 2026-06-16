-- Fix pour les RPC admin Communautés
-- Objectif : garantir l'existence de public.app_admin_delete_community(p_community_id UUID)
-- et sa bonne exposition à PostgREST.

CREATE OR REPLACE FUNCTION public.app_admin_delete_community(
    p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
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

    DELETE FROM app.communities
    WHERE id = p_community_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'community_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'community_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_delete_community(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_community(UUID) TO service_role;
