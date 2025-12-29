-- Patch: sécuriser la suppression d'un item Hero playlist
-- Objectif : ne plus violer la contrainte FK hero_renders_playlist_item_id_fkey
-- À appliquer via:
--   python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251227_fix_hero_playlist_delete.sql

CREATE OR REPLACE FUNCTION app_admin_delete_hero_playlist_item(
    p_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
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

    IF p_item_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'item_id_required');
    END IF;

    -- D'abord supprimer les rendus Hero liés à cet item
    DELETE FROM app.hero_renders
    WHERE playlist_item_id = p_item_id;

    -- hero_overlays possède déjà ON DELETE CASCADE via hero_playlist
    -- La suppression de l'item de playlist supprime donc aussi les overlays.
    DELETE FROM app.hero_playlist
    WHERE id = p_item_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_hero_playlist_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_hero_playlist_item(UUID) TO service_role;
