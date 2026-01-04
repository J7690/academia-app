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

-- Extension pour supporter les groupes étudiants et l'état/modération
ALTER TABLE app.communities
    ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'student_group', -- student_group | official
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',       -- active | restricted | suspended | closed
    ADD COLUMN IF NOT EXISTS moderation_state TEXT NOT NULL DEFAULT 'clean', -- clean | flagged | under_review
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;

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
-- 1bis) TABLE ADMIN UTILISATEURS (SYSTEM ADMINS)
-- ========================================

CREATE TABLE IF NOT EXISTS app.admin_users (
    user_id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE
);

GRANT ALL ON app.admin_users TO service_role;

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

-- Extension progressive pour supporter les messages enrichis (images, fichiers, réponses)
ALTER TABLE app.community_posts
    ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'text',
    ADD COLUMN IF NOT EXISTS media_url TEXT,
    ADD COLUMN IF NOT EXISTS reply_to_post_id UUID REFERENCES app.community_posts (id);

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
-- 5bis) RPC ÉTUDIANT - CRÉER UN GROUPE (COMMUNAUTÉ ÉTUDIANTE)
-- ========================================

CREATE OR REPLACE FUNCTION app_student_create_group(
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_name TEXT := NULLIF(TRIM(COALESCE(p_name, '')), '');
    v_slug TEXT;
    v_community_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_name IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_name');
    END IF;

    -- Générer un slug simple à partir du nom
    v_slug := LOWER(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]+', '-', 'g'));

    -- Tentative d'insertion de la communauté, avec gestion explicite des collisions de slug
    BEGIN
        INSERT INTO app.communities (
            slug,
            name,
            description,
            category,
            visibility,
            is_active,
            is_featured,
            created_by_user_id,
            kind,
            status
        )
        VALUES (
            v_slug,
            v_name,
            p_description,
            p_category,
            'public',
            TRUE,
            FALSE,
            v_user_id,
            'student_group',
            'active'
        )
        RETURNING id INTO v_community_id;
    EXCEPTION
        WHEN unique_violation THEN
            -- En pratique, cela correspond au slug déjà pris
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slug_conflict');
    END;

    -- Le créateur devient owner du groupe
    INSERT INTO app.community_memberships (community_id, user_id, role, is_active)
    VALUES (v_community_id, v_user_id, 'owner', TRUE)
    ON CONFLICT (community_id, user_id) DO UPDATE
        SET role = EXCLUDED.role,
            is_active = TRUE,
            joined_at = NOW();

    -- Ajouter automatiquement les administrateurs plateforme comme system_admin
    INSERT INTO app.community_memberships (community_id, user_id, role, is_active)
    SELECT v_community_id, au.user_id, 'system_admin', TRUE
    FROM app.admin_users au
    ON CONFLICT (community_id, user_id) DO UPDATE
        SET role = EXCLUDED.role,
            is_active = TRUE,
            joined_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'community_id', v_community_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_create_group(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_create_group(TEXT, TEXT, TEXT) TO service_role;

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
                'type', p.type,
                'media_url', p.media_url,
                'reply_to_post_id', p.reply_to_post_id,
                'is_pinned', p.is_pinned,
                'is_deleted', p.is_deleted,
                'created_at', p.created_at,
                'updated_at', p.updated_at,
                'reactions', (
                    SELECT COALESCE(
                        JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                                'emoji', r.emoji,
                                'count', r.reaction_count,
                                'reacted_by_me', r.reacted_by_me
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM (
                        SELECT
                            r.emoji,
                            COUNT(*) AS reaction_count,
                            BOOL_OR(r.user_id = v_user_id) AS reacted_by_me
                        FROM app.community_post_reactions r
                        WHERE r.post_id = p.id
                        GROUP BY r.emoji
                    ) r
                )
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
    p_content TEXT,
    p_type TEXT DEFAULT 'text',
    p_media_url TEXT DEFAULT NULL,
    p_reply_to_post_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_member BOOLEAN;
    v_post_id UUID;
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_media_url TEXT := NULLIF(TRIM(COALESCE(p_media_url, '')), '');
    v_reply_to_post_id UUID := p_reply_to_post_id;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF (p_content IS NULL OR LENGTH(TRIM(p_content)) = 0)
       AND (v_media_url IS NULL OR v_media_url = '') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    IF v_type IS NULL THEN
        v_type := 'text';
    ELSE
        v_type := LOWER(v_type);
        IF v_type NOT IN ('text', 'image', 'file', 'audio') THEN
            v_type := 'text';
        END IF;
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

    INSERT INTO app.community_posts (
        community_id,
        author_id,
        content,
        type,
        media_url,
        reply_to_post_id
    )
    VALUES (
        p_community_id,
        v_user_id,
        TRIM(p_content),
        v_type,
        v_media_url,
        v_reply_to_post_id
    )
    RETURNING id INTO v_post_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'post_id', v_post_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_community_post(UUID, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_community_post(UUID, TEXT, TEXT, TEXT, UUID) TO service_role;

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
                'kind', c.kind,
                'status', c.status,
                'moderation_state', c.moderation_state,
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
                ),
                'last_message_at', (
                    SELECT MAX(p2.created_at)
                    FROM app.community_posts p2
                    WHERE p2.community_id = c.id
                      AND p2.is_deleted = FALSE
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
    p_is_featured BOOLEAN,
    p_kind TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_moderation_state TEXT DEFAULT NULL
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
    v_kind TEXT := NULLIF(TRIM(COALESCE(p_kind, '')), '');
    v_status TEXT := NULLIF(TRIM(COALESCE(p_status, '')), '');
    v_moderation_state TEXT := NULLIF(TRIM(COALESCE(p_moderation_state, '')), '');
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

    IF v_kind IS NOT NULL THEN
        v_kind := LOWER(v_kind);
        IF v_kind NOT IN ('student_group', 'official') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_kind');
        END IF;
    END IF;

    IF v_status IS NOT NULL THEN
        v_status := LOWER(v_status);
        IF v_status NOT IN ('active', 'restricted', 'suspended', 'closed') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
        END IF;
    END IF;

    IF v_moderation_state IS NOT NULL THEN
        v_moderation_state := LOWER(v_moderation_state);
        IF v_moderation_state NOT IN ('clean', 'flagged', 'under_review') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_moderation_state');
        END IF;
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
            created_by_user_id,
            kind,
            status,
            moderation_state
        )
        VALUES (
            v_slug,
            v_name,
            p_description,
            p_category,
            v_visibility,
            CASE
                WHEN COALESCE(v_status, 'active') IN ('suspended', 'closed') THEN FALSE
                ELSE COALESCE(p_is_active, TRUE)
            END,
            COALESCE(p_is_featured, FALSE),
            v_user_id,
            COALESCE(v_kind, 'student_group'),
            COALESCE(v_status, 'active'),
            COALESCE(v_moderation_state, 'clean')
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
            is_active = CASE
                WHEN v_status IN ('suspended', 'closed') THEN FALSE
                WHEN v_status = 'active' THEN TRUE
                ELSE COALESCE(p_is_active, is_active)
            END,
            is_featured = COALESCE(p_is_featured, is_featured),
            kind = COALESCE(v_kind, kind),
            status = COALESCE(v_status, status),
            moderation_state = COALESCE(v_moderation_state, moderation_state),
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

GRANT EXECUTE ON FUNCTION app_admin_upsert_community(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_community(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, TEXT, TEXT, TEXT) TO service_role;

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
                'type', p.type,
                'media_url', p.media_url,
                'reply_to_post_id', p.reply_to_post_id,
                'is_pinned', p.is_pinned,
                'is_deleted', p.is_deleted,
                'created_at', p.created_at,
                'updated_at', p.updated_at,
                'reactions', (
                    SELECT COALESCE(
                        JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                                'emoji', r.emoji,
                                'count', r.reaction_count,
                                'reacted_by_me', r.reacted_by_me
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM (
                        SELECT
                            r.emoji,
                            COUNT(*) AS reaction_count,
                            BOOL_OR(r.user_id = v_user_id) AS reacted_by_me
                        FROM app.community_post_reactions r
                        WHERE r.post_id = p.id
                        GROUP BY r.emoji
                    ) r
                )
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

-- ========================================
-- 10) TABLE & RPC ÉTUDIANT - RÉACTIONS SUR LES MESSAGES
-- ========================================

CREATE TABLE IF NOT EXISTS app.community_post_reactions (
    post_id UUID NOT NULL REFERENCES app.community_posts (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id, emoji)
);

ALTER TABLE app.community_post_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_community_post_reactions ON app.community_post_reactions;
CREATE POLICY student_select_community_post_reactions
ON app.community_post_reactions FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS student_upsert_community_post_reactions ON app.community_post_reactions;
CREATE POLICY student_insert_own_community_post_reactions
ON app.community_post_reactions FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY student_delete_own_community_post_reactions
ON app.community_post_reactions FOR DELETE
USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON app.community_post_reactions TO authenticated;
GRANT ALL ON app.community_post_reactions TO service_role;

CREATE OR REPLACE FUNCTION app_student_toggle_community_post_reaction(
    p_post_id UUID,
    p_emoji TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_member BOOLEAN;
    v_rows_deleted INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_emoji IS NULL OR LENGTH(TRIM(p_emoji)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_emoji');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.community_posts p
        JOIN app.community_memberships m
          ON m.community_id = p.community_id
         AND m.user_id = v_user_id
         AND m.is_active = TRUE
        WHERE p.id = p_post_id
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_member_or_post_not_found');
    END IF;

    DELETE FROM app.community_post_reactions r
    WHERE r.post_id = p_post_id
      AND r.user_id = v_user_id
      AND r.emoji = TRIM(p_emoji);

    GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;

    IF v_rows_deleted > 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'action', 'removed');
    END IF;

    INSERT INTO app.community_post_reactions (post_id, user_id, emoji)
    VALUES (p_post_id, v_user_id, TRIM(p_emoji));

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'action', 'added');
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_toggle_community_post_reaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_toggle_community_post_reaction(UUID, TEXT) TO service_role;

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

-- ========================================
-- 10) TABLE & RPC MODÉRATION COMMUNAUTÉS
-- ========================================

CREATE TABLE IF NOT EXISTS app.moderation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL, -- 'community' ou 'community_post'
    entity_id UUID NOT NULL,
    source TEXT NOT NULL, -- 'student_report', 'auto', 'admin'
    reason TEXT,
    details JSONB,
    created_by_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by_user_id UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    resolution TEXT
);

ALTER TABLE app.moderation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_moderation_events ON app.moderation_events;
CREATE POLICY admin_all_moderation_events
ON app.moderation_events FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE ON app.moderation_events TO authenticated;
GRANT ALL ON app.moderation_events TO service_role;

-- RPC étudiant : signaler une communauté
CREATE OR REPLACE FUNCTION public.app_student_report_community(
    p_community_id UUID,
    p_reason TEXT,
    p_details TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    PERFORM 1
    FROM app.communities c
    WHERE c.id = p_community_id
      AND c.is_active = TRUE;
    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'community_not_found');
    END IF;

    IF p_reason IS NULL OR LENGTH(TRIM(p_reason)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_reason');
    END IF;

    INSERT INTO app.moderation_events (
        entity_type,
        entity_id,
        source,
        reason,
        details,
        created_by_user_id
    )
    VALUES (
        'community',
        p_community_id,
        'student_report',
        TRIM(p_reason),
        CASE
            WHEN p_details IS NULL OR LENGTH(TRIM(p_details)) = 0 THEN NULL
            ELSE JSONB_BUILD_OBJECT('details', TRIM(p_details))
        END,
        v_user_id
    )
    RETURNING id INTO v_id;

    UPDATE app.communities
    SET moderation_state = CASE
            WHEN moderation_state = 'clean' THEN 'flagged'
            ELSE moderation_state
        END
    WHERE id = p_community_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'event_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_report_community(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_report_community(UUID, TEXT, TEXT) TO service_role;

-- RPC étudiant : signaler un message d'une communauté
CREATE OR REPLACE FUNCTION public.app_student_report_community_post(
    p_post_id UUID,
    p_reason TEXT,
    p_details TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_community_id UUID;
    v_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT p.community_id
    INTO v_community_id
    FROM app.community_posts p
    WHERE p.id = p_post_id
      AND p.is_deleted = FALSE;

    IF v_community_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'post_not_found');
    END IF;

    IF p_reason IS NULL OR LENGTH(TRIM(p_reason)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_reason');
    END IF;

    INSERT INTO app.moderation_events (
        entity_type,
        entity_id,
        source,
        reason,
        details,
        created_by_user_id
    )
    VALUES (
        'community_post',
        p_post_id,
        'student_report',
        TRIM(p_reason),
        CASE
            WHEN p_details IS NULL OR LENGTH(TRIM(p_details)) = 0 THEN NULL
            ELSE JSONB_BUILD_OBJECT('details', TRIM(p_details))
        END,
        v_user_id
    )
    RETURNING id INTO v_id;

    UPDATE app.communities
    SET moderation_state = CASE
            WHEN moderation_state = 'clean' THEN 'flagged'
            ELSE moderation_state
        END
    WHERE id = v_community_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'event_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_report_community_post(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_report_community_post(UUID, TEXT, TEXT) TO service_role;

-- RPC admin : lister les événements de modération pour une communauté
CREATE OR REPLACE FUNCTION public.app_admin_list_community_moderation_events(
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
                'id', e.id,
                'entity_type', e.entity_type,
                'entity_id', e.entity_id,
                'source', e.source,
                'reason', e.reason,
                'details', e.details,
                'created_by_user_id', e.created_by_user_id,
                'created_at', e.created_at,
                'resolved_at', e.resolved_at,
                'resolved_by_user_id', e.resolved_by_user_id,
                'resolution', e.resolution
            )
            ORDER BY e.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.moderation_events e
    WHERE e.entity_type = 'community'
      AND e.entity_id = p_community_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'events', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_community_moderation_events(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_community_moderation_events(UUID) TO service_role;

-- RPC admin : résoudre un événement de modération (et éventuellement ajuster l'état de la communauté)
CREATE OR REPLACE FUNCTION public.app_admin_resolve_moderation_event(
    p_event_id UUID,
    p_resolution TEXT,
    p_new_moderation_state TEXT DEFAULT NULL,
    p_new_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_entity_type TEXT;
    v_entity_id UUID;
    v_moderation_state TEXT := NULLIF(TRIM(COALESCE(p_new_moderation_state, '')), '');
    v_status TEXT := NULLIF(TRIM(COALESCE(p_new_status, '')), '');
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

    IF p_resolution IS NULL OR LENGTH(TRIM(p_resolution)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_resolution');
    END IF;

    IF v_moderation_state IS NOT NULL THEN
        v_moderation_state := LOWER(v_moderation_state);
        IF v_moderation_state NOT IN ('clean', 'flagged', 'under_review') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_moderation_state');
        END IF;
    END IF;

    IF v_status IS NOT NULL THEN
        v_status := LOWER(v_status);
        IF v_status NOT IN ('active', 'restricted', 'suspended', 'closed') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
        END IF;
    END IF;

    SELECT entity_type, entity_id
    INTO v_entity_type, v_entity_id
    FROM app.moderation_events e
    WHERE e.id = p_event_id;

    IF v_entity_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'event_not_found');
    END IF;

    UPDATE app.moderation_events
    SET
        resolved_at = COALESCE(resolved_at, NOW()),
        resolved_by_user_id = COALESCE(resolved_by_user_id, v_user_id),
        resolution = COALESCE(resolution, TRIM(p_resolution))
    WHERE id = p_event_id;

    IF v_entity_type = 'community' THEN
        UPDATE app.communities
        SET
            moderation_state = COALESCE(v_moderation_state, moderation_state),
            status = COALESCE(v_status, status),
            is_active = CASE
                WHEN v_status IN ('suspended', 'closed') THEN FALSE
                WHEN v_status = 'active' THEN TRUE
                ELSE is_active
            END,
            updated_at = NOW()
        WHERE id = v_entity_id;
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'event_id', p_event_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_resolve_moderation_event(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_resolve_moderation_event(UUID, TEXT, TEXT, TEXT) TO service_role;

-- ========================================
-- 11) TABLE & RPC ÉTUDIANT - ÉTAT DE LECTURE (NON-LUS)
-- ========================================

CREATE TABLE IF NOT EXISTS app.community_read_states (
    community_id UUID NOT NULL REFERENCES app.communities (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (community_id, user_id)
);

ALTER TABLE app.community_read_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_read_states ON app.community_read_states;
CREATE POLICY student_select_own_read_states
ON app.community_read_states FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS student_upsert_own_read_states ON app.community_read_states;
CREATE POLICY student_insert_own_read_states
ON app.community_read_states FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY student_update_own_read_states
ON app.community_read_states FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.community_read_states TO authenticated;
GRANT ALL ON app.community_read_states TO service_role;

-- RPC étudiant pour marquer une communauté comme lue
CREATE OR REPLACE FUNCTION app_student_mark_community_read(
    p_community_id UUID,
    p_last_read_at TIMESTAMPTZ DEFAULT NOW()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Vérifier que la communauté existe et est active
    PERFORM 1
    FROM app.communities c
    WHERE c.id = p_community_id
      AND c.is_active = TRUE;
    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'community_not_found');
    END IF;

    INSERT INTO app.community_read_states (community_id, user_id, last_read_at)
    VALUES (p_community_id, v_user_id, p_last_read_at)
    ON CONFLICT (community_id, user_id) DO UPDATE
        SET last_read_at = GREATEST(app.community_read_states.last_read_at, EXCLUDED.last_read_at)
    RETURNING community_id INTO v_id;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'community_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_mark_community_read(UUID, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_mark_community_read(UUID, TIMESTAMPTZ) TO service_role;

-- RPC étudiant pour récupérer l'activité et les non-lus sur ses communautés
CREATE OR REPLACE FUNCTION app_student_list_my_communities_activity()
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
                'joined_at', m.joined_at,
                'last_post_at', stats.last_post_at,
                'last_read_at', rs.last_read_at,
                'unread_count', COALESCE(stats.unread_count, 0)
            )
            ORDER BY COALESCE(stats.last_post_at, m.joined_at) DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_memberships m
    JOIN app.communities c ON c.id = m.community_id
    LEFT JOIN app.community_read_states rs
      ON rs.community_id = m.community_id
     AND rs.user_id = v_user_id
    LEFT JOIN LATERAL (
        SELECT
            MAX(p.created_at) AS last_post_at,
            COUNT(*) FILTER (
                WHERE p.created_at > COALESCE(rs.last_read_at, m.joined_at)
            ) AS unread_count
        FROM app.community_posts p
        WHERE p.community_id = m.community_id
          AND p.is_deleted = FALSE
    ) AS stats ON TRUE
    WHERE m.user_id = v_user_id
      AND m.is_active = TRUE
      AND c.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'communities', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_communities_activity() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_communities_activity() TO service_role;

-- ========================================
-- 11) RPC ÉTUDIANT - HOME "CHATS" (LISTE DES GROUPES)
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_chats()
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
                'kind', c.kind,
                'status', c.status,
                'moderation_state', c.moderation_state,
                'joined_at', m.joined_at,
                'last_message_content', stats.last_message_content,
                'last_message_author_display', stats.last_message_author_display,
                'last_message_at', stats.last_message_at,
                'unread_count', COALESCE(stats.unread_count, 0)
            )
            ORDER BY COALESCE(stats.last_message_at, m.joined_at) DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_memberships m
    JOIN app.communities c ON c.id = m.community_id
    LEFT JOIN app.community_read_states rs
      ON rs.community_id = m.community_id
     AND rs.user_id = v_user_id
    LEFT JOIN LATERAL (
        SELECT
            p_last.created_at AS last_message_at,
            p_last.content AS last_message_content,
            CASE
                WHEN p_last.author_id = v_user_id THEN 'Toi'
                ELSE 'Membre'
            END AS last_message_author_display,
            (
                SELECT COUNT(*)
                FROM app.community_posts p2
                WHERE p2.community_id = m.community_id
                  AND p2.is_deleted = FALSE
                  AND p2.created_at > COALESCE(rs.last_read_at, m.joined_at)
            ) AS unread_count
        FROM app.community_posts p_last
        WHERE p_last.community_id = m.community_id
          AND p_last.is_deleted = FALSE
        ORDER BY p_last.created_at DESC
        LIMIT 1
    ) AS stats ON TRUE
    WHERE m.user_id = v_user_id
      AND m.is_active = TRUE
      AND c.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'chats', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_chats() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_chats() TO service_role;

-- ========================================
-- 12) TABLE & RPC ÉTUDIANT - SONDAGES DE COMMUNAUTÉ
-- ========================================

CREATE TABLE IF NOT EXISTS app.community_polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES app.communities (id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    options TEXT[] NOT NULL,
    is_multiple BOOLEAN NOT NULL DEFAULT FALSE,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    created_by_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS app.community_poll_votes (
    poll_id UUID NOT NULL REFERENCES app.community_polls (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    option_index INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (poll_id, user_id)
);

ALTER TABLE app.community_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.community_poll_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_community_polls ON app.community_polls;
CREATE POLICY student_select_community_polls
ON app.community_polls FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS student_select_community_poll_votes ON app.community_poll_votes;
CREATE POLICY student_select_community_poll_votes
ON app.community_poll_votes FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS student_insert_community_polls ON app.community_polls;
CREATE POLICY student_insert_community_polls
ON app.community_polls FOR INSERT
WITH CHECK (created_by_user_id = auth.uid());

DROP POLICY IF EXISTS student_insert_community_poll_votes ON app.community_poll_votes;
CREATE POLICY student_insert_community_poll_votes
ON app.community_poll_votes FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_update_community_poll_votes ON app.community_poll_votes;
CREATE POLICY student_update_community_poll_votes
ON app.community_poll_votes FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_delete_community_poll_votes ON app.community_poll_votes;
CREATE POLICY student_delete_community_poll_votes
ON app.community_poll_votes FOR DELETE
USING (user_id = auth.uid());

GRANT SELECT, INSERT ON app.community_polls TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.community_poll_votes TO authenticated;
GRANT ALL ON app.community_polls TO service_role;
GRANT ALL ON app.community_poll_votes TO service_role;

CREATE OR REPLACE FUNCTION app_student_create_community_poll(
    p_community_id UUID,
    p_question TEXT,
    p_options TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_member BOOLEAN;
    v_clean_options TEXT[];
    v_len INT;
    v_poll_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_question IS NULL OR LENGTH(TRIM(p_question)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_question');
    END IF;

    IF p_options IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_options');
    END IF;

    SELECT ARRAY(
        SELECT TRIM(opt)
        FROM UNNEST(p_options) AS opt
        WHERE TRIM(opt) <> ''
    ) INTO v_clean_options;

    SELECT COALESCE(ARRAY_LENGTH(v_clean_options, 1), 0) INTO v_len;

    IF v_len < 2 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_enough_options');
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

    INSERT INTO app.community_polls (
        community_id,
        question,
        options,
        created_by_user_id
    )
    VALUES (
        p_community_id,
        TRIM(p_question),
        v_clean_options,
        v_user_id
    )
    RETURNING id INTO v_poll_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'poll_id', v_poll_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_create_community_poll(UUID, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_create_community_poll(UUID, TEXT, TEXT[]) TO service_role;

CREATE OR REPLACE FUNCTION app_student_vote_community_poll(
    p_poll_id UUID,
    p_option_index INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_community_id UUID;
    v_is_member BOOLEAN;
    v_max INT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT community_id, COALESCE(ARRAY_LENGTH(options, 1), 0)
    INTO v_community_id, v_max
    FROM app.community_polls
    WHERE id = p_poll_id
      AND is_closed = FALSE;

    IF v_community_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'poll_not_found_or_closed');
    END IF;

    IF p_option_index IS NULL OR p_option_index < 1 OR p_option_index > v_max THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_option');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.community_memberships m
        WHERE m.community_id = v_community_id
          AND m.user_id = v_user_id
          AND m.is_active = TRUE
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_member');
    END IF;

    INSERT INTO app.community_poll_votes (poll_id, user_id, option_index)
    VALUES (p_poll_id, v_user_id, p_option_index)
    ON CONFLICT (poll_id, user_id) DO UPDATE
        SET option_index = EXCLUDED.option_index,
            created_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_vote_community_poll(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_vote_community_poll(UUID, INT) TO service_role;

CREATE OR REPLACE FUNCTION app_student_list_community_polls(
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
                'id', cp.id,
                'community_id', cp.community_id,
                'question', cp.question,
                'is_multiple', cp.is_multiple,
                'is_closed', cp.is_closed,
                'created_by_user_id', cp.created_by_user_id,
                'created_at', cp.created_at,
                'closed_at', cp.closed_at,
                'options', options.options_json
            )
            ORDER BY cp.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_polls cp
    LEFT JOIN LATERAL (
        SELECT COALESCE(
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'index', o.idx,
                    'text', o.option_text,
                    'votes', COALESCE(o.votes, 0),
                    'voted_by_me', COALESCE(o.voted_by_me, FALSE)
                ) ORDER BY o.idx
            ),
            '[]'::JSONB
        ) AS options_json
        FROM (
            SELECT
                t.idx,
                t.option_text,
                v.count_votes AS votes,
                vbm.voted_by_me
            FROM UNNEST(cp.options) WITH ORDINALITY AS t(option_text, idx)
            LEFT JOIN (
                SELECT option_index, COUNT(*) AS count_votes
                FROM app.community_poll_votes
                WHERE poll_id = cp.id
                GROUP BY option_index
            ) v ON v.option_index = t.idx
            LEFT JOIN (
                SELECT option_index, TRUE AS voted_by_me
                FROM app.community_poll_votes
                WHERE poll_id = cp.id AND user_id = v_user_id
            ) vbm ON vbm.option_index = t.idx
        ) o
    ) AS options ON TRUE
    WHERE cp.community_id = p_community_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_community_polls(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_community_polls(UUID) TO service_role;
