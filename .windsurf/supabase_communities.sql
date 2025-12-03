-- ========================================
-- ACADEMIA - MODULE COMMUNAUTÉS
-- Espaces communautaires (groupes), adhésions et messages
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE COMMUNAUTÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.communities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    visibility TEXT NOT NULL DEFAULT 'public', -- public, private
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.communities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_public_communities ON app.communities;
CREATE POLICY public_select_active_public_communities
ON app.communities FOR SELECT
USING (
  is_active = TRUE
  AND visibility = 'public'
);

GRANT SELECT ON app.communities TO anon, authenticated;
GRANT ALL ON app.communities TO service_role;

-- ========================================
-- 2) TABLE ADHÉSIONS AUX COMMUNAUTÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.community_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES app.communities (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member', -- member, moderator, owner
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (community_id, user_id)
);

ALTER TABLE app.community_memberships
    ADD COLUMN IF NOT EXISTS is_banned BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE app.community_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_community_memberships ON app.community_memberships;
CREATE POLICY student_select_own_community_memberships
ON app.community_memberships FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_community_memberships ON app.community_memberships;
CREATE POLICY student_insert_own_community_memberships
ON app.community_memberships FOR INSERT
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT ON app.community_memberships TO authenticated;
GRANT ALL ON app.community_memberships TO service_role;

-- ========================================
-- 3) TABLE MESSAGES DES COMMUNAUTÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES app.communities (id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.community_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS member_select_community_posts ON app.community_posts;
CREATE POLICY member_select_community_posts
ON app.community_posts FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM app.community_memberships m
    WHERE m.community_id = community_posts.community_id
      AND m.user_id = auth.uid()
      AND m.is_active = TRUE
  )
);

DROP POLICY IF EXISTS member_insert_community_posts ON app.community_posts;
CREATE POLICY member_insert_community_posts
ON app.community_posts FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM app.community_memberships m
    WHERE m.community_id = community_posts.community_id
      AND m.user_id = auth.uid()
      AND m.is_active = TRUE
  )
);

GRANT SELECT, INSERT ON app.community_posts TO authenticated;
GRANT ALL ON app.community_posts TO service_role;

-- ========================================
-- 4) RPC ÉTUDIANT - LISTE DES COMMUNAUTÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_communities(
    p_search TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
    v_category TEXT := NULLIF(TRIM(COALESCE(p_category, '')), '');
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'slug', c.slug,
                'name', c.name,
                'description', c.description,
                'category', c.category,
                'visibility', c.visibility,
                'is_active', c.is_active,
                'is_featured', c.is_featured,
                'created_at', c.created_at,
                'updated_at', c.updated_at,
                'members_count', COALESCE(
                    (
                        SELECT COUNT(*)
                        FROM app.community_memberships m
                        WHERE m.community_id = c.id
                          AND m.is_active = TRUE
                    ),
                    0
                ),
                'is_member', EXISTS (
                    SELECT 1
                    FROM app.community_memberships m2
                    WHERE m2.community_id = c.id
                      AND m2.user_id = v_user_id
                      AND m2.is_active = TRUE
                )
            )
            ORDER BY c.is_featured DESC, c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.communities c
    WHERE c.is_active = TRUE
      AND c.visibility = 'public'
      AND (v_category IS NULL OR LOWER(c.category) = LOWER(v_category))
      AND (
        v_search IS NULL
        OR c.name ILIKE '%' || v_search || '%'
        OR c.description ILIKE '%' || v_search || '%'
        OR c.category ILIKE '%' || v_search || '%'
      );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'communities', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_communities(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_communities(TEXT, TEXT) TO service_role;

-- ========================================
-- 5) RPC ÉTUDIANT - MES COMMUNAUTÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_communities()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'community_id', c.id,
                'slug', c.slug,
                'name', c.name,
                'description', c.description,
                'category', c.category,
                'visibility', c.visibility,
                'is_active', c.is_active,
                'is_featured', c.is_featured,
                'joined_at', m.joined_at
            )
            ORDER BY m.joined_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_memberships m
    JOIN app.communities c ON c.id = m.community_id
    WHERE m.user_id = v_user_id
      AND m.is_active = TRUE
      AND c.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'communities', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_communities() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_communities() TO service_role;

-- ========================================
-- 6) RPC ÉTUDIANT - REJOINDRE / QUITTER UNE COMMUNAUTÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_student_join_community(
    p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_exists BOOLEAN;
    v_membership_id UUID;
    v_is_banned BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.communities c
        WHERE c.id = p_community_id
          AND c.is_active = TRUE
          AND c.visibility = 'public'
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'community_not_joinable');
    END IF;

    SELECT is_banned
    INTO v_is_banned
    FROM app.community_memberships
    WHERE community_id = p_community_id
      AND user_id = v_user_id
    LIMIT 1;

    IF COALESCE(v_is_banned, FALSE) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_community');
    END IF;

    INSERT INTO app.community_memberships (community_id, user_id, role, is_active)
    VALUES (p_community_id, v_user_id, 'member', TRUE)
    ON CONFLICT (community_id, user_id) DO UPDATE
        SET is_active = TRUE,
            joined_at = NOW()
    RETURNING id INTO v_membership_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'membership_id', v_membership_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_join_community(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_join_community(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_leave_community(
    p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_membership_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    UPDATE app.community_memberships
    SET is_active = FALSE
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_active = TRUE
    RETURNING id INTO v_membership_id;

    IF v_membership_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'membership_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'membership_id', v_membership_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_leave_community(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_leave_community(UUID) TO service_role;

-- ========================================
-- 7) RPC ÉTUDIANT - MESSAGES D'UNE COMMUNAUTÉ
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_community_posts(
    p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_member BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.community_memberships m
        WHERE m.community_id = p_community_id
          AND m.user_id = v_user_id
          AND m.is_active = TRUE
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
                'community_id', p.community_id,
                'author_id', p.author_id,
                'content', p.content,
                'is_pinned', p.is_pinned,
                'is_deleted', p.is_deleted,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            )
            ORDER BY p.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_posts p
    WHERE p.community_id = p_community_id
      AND p.is_deleted = FALSE;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_community_posts(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_community_posts(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_add_community_post(
    p_community_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_member BOOLEAN;
    v_post_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.community_memberships m
        WHERE m.community_id = p_community_id
          AND m.user_id = v_user_id
          AND m.is_active = TRUE
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_member');
    END IF;

    INSERT INTO app.community_posts (community_id, author_id, content)
    VALUES (p_community_id, v_user_id, TRIM(p_content))
    RETURNING id INTO v_post_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'post_id', v_post_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_community_post(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_community_post(UUID, TEXT) TO service_role;

-- ========================================
-- 8) RPC ADMIN - GESTION DES COMMUNAUTÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_communities()
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
                'id', c.id,
                'slug', c.slug,
                'name', c.name,
                'description', c.description,
                'category', c.category,
                'visibility', c.visibility,
                'is_active', c.is_active,
                'is_featured', c.is_featured,
                'created_by_user_id', c.created_by_user_id,
                'created_at', c.created_at,
                'updated_at', c.updated_at,
                'members_count', COALESCE(
                    (
                        SELECT COUNT(*)
                        FROM app.community_memberships m
                        WHERE m.community_id = c.id
                          AND m.is_active = TRUE
                    ),
                    0
                ),
                'posts_count', COALESCE(
                    (
                        SELECT COUNT(*)
                        FROM app.community_posts p
                        WHERE p.community_id = c.id
                          AND p.is_deleted = FALSE
                    ),
                    0
                )
            )
            ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.communities c;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'communities', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_communities() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_communities() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_community(
    p_community_id UUID,
    p_slug TEXT,
    p_name TEXT,
    p_description TEXT,
    p_category TEXT,
    p_visibility TEXT,
    p_is_active BOOLEAN,
    p_is_featured BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_slug TEXT := NULLIF(TRIM(COALESCE(p_slug, '')), '');
    v_name TEXT := NULLIF(TRIM(COALESCE(p_name, '')), '');
    v_visibility TEXT := LOWER(TRIM(COALESCE(p_visibility, 'public')));
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

    IF v_name IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_name');
    END IF;

    IF v_slug IS NULL THEN
        v_slug := LOWER(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]+', '-', 'g'));
    END IF;

    IF v_visibility NOT IN ('public', 'private') THEN
        v_visibility := 'public';
    END IF;

    IF p_community_id IS NULL THEN
        INSERT INTO app.communities (
            slug,
            name,
            description,
            category,
            visibility,
            is_active,
            is_featured,
            created_by_user_id
        )
        VALUES (
            v_slug,
            v_name,
            p_description,
            p_category,
            v_visibility,
            COALESCE(p_is_active, TRUE),
            COALESCE(p_is_featured, FALSE),
            v_user_id
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.communities
        SET
            slug = v_slug,
            name = v_name,
            description = p_description,
            category = p_category,
            visibility = v_visibility,
            is_active = COALESCE(p_is_active, is_active),
            is_featured = COALESCE(p_is_featured, is_featured),
            updated_at = NOW()
        WHERE id = p_community_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'community_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'community_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_community(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_community(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_update_community_status(
    p_community_id UUID,
    p_is_active BOOLEAN,
    p_is_featured BOOLEAN
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

    UPDATE app.communities
    SET
        is_active = COALESCE(p_is_active, is_active),
        is_featured = COALESCE(p_is_featured, is_featured),
        updated_at = NOW()
    WHERE id = p_community_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'community_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'community_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_community_status(UUID, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_community_status(UUID, BOOLEAN, BOOLEAN) TO service_role;

-- ========================================
-- 9) RPC ADMIN - MODÉRATION DES MESSAGES & BANNISSEMENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_community_posts(
    p_community_id UUID
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

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
                'community_id', p.community_id,
                'author_id', p.author_id,
                'content', p.content,
                'is_pinned', p.is_pinned,
                'is_deleted', p.is_deleted,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            )
            ORDER BY p.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_posts p
    WHERE p.community_id = p_community_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'posts', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_community_posts(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_community_posts(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_community_post(
    p_post_id UUID
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

    UPDATE app.community_posts
    SET is_deleted = TRUE,
        updated_at = NOW()
    WHERE id = p_post_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'post_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'post_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_community_post(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_community_post(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_ban_user_from_community(
    p_community_id UUID,
    p_user_id UUID
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

    UPDATE app.community_memberships
    SET is_banned = TRUE,
        is_active = FALSE
    WHERE community_id = p_community_id
      AND user_id = p_user_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        INSERT INTO app.community_memberships (
            community_id,
            user_id,
            role,
            joined_at,
            is_active,
            is_banned
        )
        VALUES (
            p_community_id,
            p_user_id,
            'member',
            NOW(),
            FALSE,
            TRUE
        )
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'membership_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'membership_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_ban_user_from_community(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_ban_user_from_community(UUID, UUID) TO service_role;
