-- Hero Studio Télé : RPC d'initialisation de rendu
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251210_hero_studio_rpcs.sql

-- 5.1) RPC ADMIN - CRÉATION D'UN JOB DE RENDU HERO

CREATE OR REPLACE FUNCTION app_admin_start_hero_render(
    p_playlist_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_render_id UUID;
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

    IF p_playlist_item_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'playlist_item_id_required');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.hero_playlist hp
        WHERE hp.id = p_playlist_item_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'playlist_item_not_found');
    END IF;

    INSERT INTO app.hero_renders (
        playlist_item_id,
        status
    )
    VALUES (
        p_playlist_item_id,
        'processing'
    )
    RETURNING id INTO v_render_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'render_id', v_render_id,
        'status', 'processing'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_start_hero_render(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_start_hero_render(UUID) TO service_role;
