-- 2025-12-28: Réactivation des RPC de suppression mini-site université (université + admin)
-- Objectif : remplacer d'éventuels shims legacy_rpc_disabled pour toutes les fonctions
-- app_delete_university_* et app_admin_delete_university_* utilisées par l'UI Flutter
-- (onglets mini-site côté université et admin).

-- On travaille dans le schéma public, comme pour les autres RPC mini-site.

-- 0) Nettoyage préalable : on supprime les versions existantes en public

DROP FUNCTION IF EXISTS public.app_delete_university_site_block(p_block_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_delete_university_media(p_media_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_delete_university_event(p_event_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_delete_university_news(p_news_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_delete_university_staff(p_staff_id UUID) CASCADE;

DROP FUNCTION IF EXISTS public.app_admin_delete_university_site_block(p_block_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_delete_university_media(p_media_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_delete_university_event(p_event_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_delete_university_news(p_news_id UUID) CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_delete_university_staff(p_staff_id UUID) CASCADE;


-- 1) Fonctions de suppression côté université (rôle "university")

-- 1.a) Suppression logique d'un bloc éditorial

CREATE OR REPLACE FUNCTION public.app_delete_university_site_block(
    p_block_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    UPDATE app.university_site_blocks
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_block_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'block_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'block_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_delete_university_site_block(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_university_site_block(UUID) TO service_role;


-- 1.b) Suppression logique d'un média

CREATE OR REPLACE FUNCTION public.app_delete_university_media(
    p_media_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    UPDATE app.university_media
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_media_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'media_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_delete_university_media(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_university_media(UUID) TO service_role;


-- 1.c) Suppression logique d'un événement

CREATE OR REPLACE FUNCTION public.app_delete_university_event(
    p_event_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    UPDATE app.university_events
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_event_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'event_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'event_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_delete_university_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_university_event(UUID) TO service_role;


-- 1.d) Suppression logique d'une actualité

CREATE OR REPLACE FUNCTION public.app_delete_university_news(
    p_news_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    UPDATE app.university_news
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_news_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'news_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'news_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_delete_university_news(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_university_news(UUID) TO service_role;


-- 1.e) Suppression logique d'un membre de l'équipe

CREATE OR REPLACE FUNCTION public.app_delete_university_staff(
    p_staff_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_deleted_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    UPDATE app.university_staff
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_staff_id
      AND university_id = v_university_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'staff_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'staff_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_delete_university_staff(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_university_staff(UUID) TO service_role;


-- 2) Fonctions de suppression côté admin (rôle "admin")

-- 2.a) Suppression logique d'un bloc éditorial (admin)

CREATE OR REPLACE FUNCTION public.app_admin_delete_university_site_block(
    p_block_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_site_blocks
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_block_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'block_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'block_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_site_block(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_site_block(UUID) TO service_role;


-- 2.b) Suppression logique d'un média (admin)

CREATE OR REPLACE FUNCTION public.app_admin_delete_university_media(
    p_media_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_media
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_media_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'media_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_media(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_media(UUID) TO service_role;


-- 2.c) Suppression logique d'un événement (admin)

CREATE OR REPLACE FUNCTION public.app_admin_delete_university_event(
    p_event_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_events
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_event_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'event_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'event_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_event(UUID) TO service_role;


-- 2.d) Suppression logique d'une actualité (admin)

CREATE OR REPLACE FUNCTION public.app_admin_delete_university_news(
    p_news_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_news
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_news_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'news_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'news_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_news(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_news(UUID) TO service_role;


-- 2.e) Suppression logique d'un membre de l'équipe (admin)

CREATE OR REPLACE FUNCTION public.app_admin_delete_university_staff(
    p_staff_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted_id UUID;
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

    UPDATE app.university_staff
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE id = p_staff_id
    RETURNING id INTO v_deleted_id;

    IF v_deleted_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'staff_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'staff_id', v_deleted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_staff(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_university_staff(UUID) TO service_role;
