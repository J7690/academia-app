-- ============================================================
-- PHASE 1 : Extensions backend - Module Opportunités Mini-Facebook
-- Date : 2025-01-04
-- ============================================================
-- CONTENU :
-- 1. Extension table opportunities (price, reactions_count, comments_count)
-- 2. Extension table opportunity_applications (admin_notes, reviewed_at, reviewed_by)
-- 3. Nouvelle table opportunity_reactions
-- 4. Nouvelle table opportunity_comments
-- 5. Policies RLS pour les nouvelles tables
-- 6. Nouvelles RPC réactions
-- 7. Nouvelles RPC commentaires
-- 8. Nouvelle RPC admin update application status
-- 9. Modification RPC listing pour inclure compteurs
-- ============================================================

-- ============================================================
-- 1. EXTENSION TABLE OPPORTUNITIES
-- ============================================================

ALTER TABLE app.opportunities 
ADD COLUMN IF NOT EXISTS price NUMERIC(12,2) DEFAULT NULL;

ALTER TABLE app.opportunities 
ADD COLUMN IF NOT EXISTS reactions_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE app.opportunities 
ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 2. EXTENSION TABLE OPPORTUNITY_APPLICATIONS
-- ============================================================

ALTER TABLE app.opportunity_applications 
ADD COLUMN IF NOT EXISTS admin_notes TEXT DEFAULT NULL;

ALTER TABLE app.opportunity_applications 
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE app.opportunity_applications 
ADD COLUMN IF NOT EXISTS reviewed_by UUID DEFAULT NULL;

-- ============================================================
-- 3. NOUVELLE TABLE OPPORTUNITY_REACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS app.opportunity_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id UUID NOT NULL REFERENCES app.opportunities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like', 'love')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(opportunity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_opportunity_reactions_opportunity 
ON app.opportunity_reactions(opportunity_id);

CREATE INDEX IF NOT EXISTS idx_opportunity_reactions_user 
ON app.opportunity_reactions(user_id);

-- ============================================================
-- 4. NOUVELLE TABLE OPPORTUNITY_COMMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS app.opportunity_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id UUID NOT NULL REFERENCES app.opportunities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_opportunity_comments_opportunity 
ON app.opportunity_comments(opportunity_id);

CREATE INDEX IF NOT EXISTS idx_opportunity_comments_user 
ON app.opportunity_comments(user_id);

CREATE INDEX IF NOT EXISTS idx_opportunity_comments_created 
ON app.opportunity_comments(created_at DESC);

-- ============================================================
-- 5. ENABLE RLS ET POLICIES
-- ============================================================

ALTER TABLE app.opportunity_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.opportunity_comments ENABLE ROW LEVEL SECURITY;

-- Reactions: tout le monde peut voir, seul l'utilisateur peut gérer les siennes
DROP POLICY IF EXISTS public_select_opportunity_reactions ON app.opportunity_reactions;
CREATE POLICY public_select_opportunity_reactions ON app.opportunity_reactions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS user_manage_own_reactions ON app.opportunity_reactions;
CREATE POLICY user_manage_own_reactions ON app.opportunity_reactions
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Comments: tout le monde peut voir, authenticated peut insérer, owner peut supprimer
DROP POLICY IF EXISTS public_select_opportunity_comments ON app.opportunity_comments;
CREATE POLICY public_select_opportunity_comments ON app.opportunity_comments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS authenticated_insert_comments ON app.opportunity_comments;
CREATE POLICY authenticated_insert_comments ON app.opportunity_comments
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

DROP POLICY IF EXISTS user_delete_own_comments ON app.opportunity_comments;
CREATE POLICY user_delete_own_comments ON app.opportunity_comments
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- 6. RPC RÉACTIONS
-- ============================================================

-- Toggle reaction (like/love) - retourne le nouvel état
CREATE OR REPLACE FUNCTION public.app_opportunity_toggle_reaction(
    p_opportunity_id UUID,
    p_reaction_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_existing_type TEXT;
    v_new_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_reaction_type NOT IN ('like', 'love') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_reaction_type');
    END IF;

    -- Vérifier si l'opportunité existe et est active
    IF NOT EXISTS (
        SELECT 1 FROM app.opportunities 
        WHERE id = p_opportunity_id AND is_active = TRUE AND status = 'published'
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_found');
    END IF;

    -- Vérifier si une réaction existe déjà
    SELECT reaction_type INTO v_existing_type
    FROM app.opportunity_reactions
    WHERE opportunity_id = p_opportunity_id AND user_id = v_user_id;

    IF v_existing_type IS NOT NULL THEN
        IF v_existing_type = p_reaction_type THEN
            -- Même type: supprimer la réaction (toggle off)
            DELETE FROM app.opportunity_reactions
            WHERE opportunity_id = p_opportunity_id AND user_id = v_user_id;
            
            -- Décrémenter le compteur
            UPDATE app.opportunities 
            SET reactions_count = GREATEST(0, reactions_count - 1), updated_at = NOW()
            WHERE id = p_opportunity_id
            RETURNING reactions_count INTO v_new_count;
            
            RETURN JSONB_BUILD_OBJECT(
                'success', TRUE, 
                'action', 'removed',
                'my_reaction', NULL,
                'reactions_count', v_new_count
            );
        ELSE
            -- Type différent: mettre à jour
            UPDATE app.opportunity_reactions
            SET reaction_type = p_reaction_type
            WHERE opportunity_id = p_opportunity_id AND user_id = v_user_id;
            
            SELECT reactions_count INTO v_new_count
            FROM app.opportunities WHERE id = p_opportunity_id;
            
            RETURN JSONB_BUILD_OBJECT(
                'success', TRUE, 
                'action', 'updated',
                'my_reaction', p_reaction_type,
                'reactions_count', v_new_count
            );
        END IF;
    ELSE
        -- Pas de réaction: en créer une
        INSERT INTO app.opportunity_reactions (opportunity_id, user_id, reaction_type)
        VALUES (p_opportunity_id, v_user_id, p_reaction_type);
        
        -- Incrémenter le compteur
        UPDATE app.opportunities 
        SET reactions_count = reactions_count + 1, updated_at = NOW()
        WHERE id = p_opportunity_id
        RETURNING reactions_count INTO v_new_count;
        
        RETURN JSONB_BUILD_OBJECT(
            'success', TRUE, 
            'action', 'added',
            'my_reaction', p_reaction_type,
            'reactions_count', v_new_count
        );
    END IF;
END;
$$;

-- Obtenir les compteurs de réactions par type
CREATE OR REPLACE FUNCTION public.app_opportunity_get_reactions(
    p_opportunity_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_likes INTEGER;
    v_loves INTEGER;
    v_total INTEGER;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE reaction_type = 'like'),
        COUNT(*) FILTER (WHERE reaction_type = 'love'),
        COUNT(*)
    INTO v_likes, v_loves, v_total
    FROM app.opportunity_reactions
    WHERE opportunity_id = p_opportunity_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'likes', COALESCE(v_likes, 0),
        'loves', COALESCE(v_loves, 0),
        'total', COALESCE(v_total, 0)
    );
END;
$$;

-- Obtenir ma réaction sur une opportunité
CREATE OR REPLACE FUNCTION public.app_opportunity_get_my_reaction(
    p_opportunity_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_reaction_type TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'my_reaction', NULL);
    END IF;

    SELECT reaction_type INTO v_reaction_type
    FROM app.opportunity_reactions
    WHERE opportunity_id = p_opportunity_id AND user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'my_reaction', v_reaction_type);
END;
$$;

-- ============================================================
-- 7. RPC COMMENTAIRES
-- ============================================================

-- Ajouter un commentaire
CREATE OR REPLACE FUNCTION public.app_opportunity_add_comment(
    p_opportunity_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_comment_id UUID;
    v_new_count INTEGER;
    v_content TEXT := TRIM(COALESCE(p_content, ''));
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF v_content = '' OR LENGTH(v_content) < 2 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'content_too_short');
    END IF;

    IF LENGTH(v_content) > 1000 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'content_too_long');
    END IF;

    -- Vérifier si l'opportunité existe et est active
    IF NOT EXISTS (
        SELECT 1 FROM app.opportunities 
        WHERE id = p_opportunity_id AND is_active = TRUE AND status = 'published'
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_found');
    END IF;

    -- Insérer le commentaire
    INSERT INTO app.opportunity_comments (opportunity_id, user_id, content)
    VALUES (p_opportunity_id, v_user_id, v_content)
    RETURNING id INTO v_comment_id;

    -- Incrémenter le compteur
    UPDATE app.opportunities 
    SET comments_count = comments_count + 1, updated_at = NOW()
    WHERE id = p_opportunity_id
    RETURNING comments_count INTO v_new_count;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'comment_id', v_comment_id,
        'comments_count', v_new_count
    );
END;
$$;

-- Lister les commentaires d'une opportunité (paginé)
CREATE OR REPLACE FUNCTION public.app_opportunity_list_comments(
    p_opportunity_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_total INTEGER;
BEGIN
    -- Compter le total
    SELECT COUNT(*) INTO v_total
    FROM app.opportunity_comments
    WHERE opportunity_id = p_opportunity_id;

    -- Récupérer les commentaires avec infos utilisateur
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'user_id', c.user_id,
                'content', c.content,
                'created_at', c.created_at,
                'user_name', COALESCE(
                    u.raw_user_meta_data->>'full_name',
                    u.raw_user_meta_data->>'name',
                    'Utilisateur'
                ),
                'user_avatar', u.raw_user_meta_data->>'avatar_url'
            )
            ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunity_comments c
    LEFT JOIN auth.users u ON u.id = c.user_id
    WHERE c.opportunity_id = p_opportunity_id
    ORDER BY c.created_at DESC
    LIMIT p_limit OFFSET p_offset;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'comments', v_result,
        'total', v_total,
        'has_more', (p_offset + p_limit) < v_total
    );
END;
$$;

-- Supprimer un commentaire (owner uniquement)
CREATE OR REPLACE FUNCTION public.app_opportunity_delete_comment(
    p_comment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_opportunity_id UUID;
    v_owner_id UUID;
    v_new_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Vérifier ownership
    SELECT opportunity_id, user_id INTO v_opportunity_id, v_owner_id
    FROM app.opportunity_comments
    WHERE id = p_comment_id;

    IF v_opportunity_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'comment_not_found');
    END IF;

    IF v_owner_id != v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    -- Supprimer
    DELETE FROM app.opportunity_comments WHERE id = p_comment_id;

    -- Décrémenter le compteur
    UPDATE app.opportunities 
    SET comments_count = GREATEST(0, comments_count - 1), updated_at = NOW()
    WHERE id = v_opportunity_id
    RETURNING comments_count INTO v_new_count;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'comments_count', v_new_count
    );
END;
$$;

-- ============================================================
-- 8. RPC ADMIN UPDATE APPLICATION STATUS
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_admin_update_application_status(
    p_application_id UUID,
    p_status TEXT,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_application_id UUID;
    v_student_id UUID;
    v_opportunity_id UUID;
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

    IF p_status NOT IN ('pending', 'submitted', 'accepted', 'rejected') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    -- Mettre à jour
    UPDATE app.opportunity_applications
    SET 
        status = p_status,
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        reviewed_at = NOW(),
        reviewed_by = v_user_id,
        updated_at = NOW()
    WHERE id = p_application_id
    RETURNING id, student_id, opportunity_id 
    INTO v_application_id, v_student_id, v_opportunity_id;

    IF v_application_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application_id', v_application_id,
        'new_status', p_status
    );
END;
$$;

-- ============================================================
-- 9. MODIFICATION RPC LISTING ÉTUDIANT (avec compteurs et ma réaction)
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_student_list_opportunities(
    p_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_user_id UUID := auth.uid();
    v_search TEXT := NULLIF(TRIM(COALESCE(p_search, '')), '');
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_total INTEGER;
BEGIN
    -- Compter le total avec filtres
    SELECT COUNT(*) INTO v_total
    FROM app.opportunities o
    WHERE o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
      AND (v_type IS NULL OR LOWER(o.type) = LOWER(v_type))
      AND (
          v_search IS NULL
          OR o.title ILIKE '%' || v_search || '%'
          OR o.organization_name ILIKE '%' || v_search || '%'
          OR o.city ILIKE '%' || v_search || '%'
          OR o.country ILIKE '%' || v_search || '%'
      );

    -- Récupérer les opportunités avec compteurs et ma réaction
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', o.id,
                'title', o.title,
                'short_description', o.short_description,
                'description', o.description,
                'type', o.type,
                'category', o.category,
                'organization_name', o.organization_name,
                'organization_logo_url', o.organization_logo_url,
                'country', o.country,
                'city', o.city,
                'is_remote_possible', o.is_remote_possible,
                'contract_type', o.contract_type,
                'duration_months', o.duration_months,
                'start_date', o.start_date,
                'application_deadline', o.application_deadline,
                'price', o.price,
                'status', o.status,
                'is_featured', o.is_featured,
                'reactions_count', o.reactions_count,
                'comments_count', o.comments_count,
                'created_at', o.created_at,
                'updated_at', o.updated_at,
                'my_reaction', (
                    SELECT reaction_type 
                    FROM app.opportunity_reactions r 
                    WHERE r.opportunity_id = o.id AND r.user_id = v_user_id
                )
            )
            ORDER BY o.is_featured DESC, o.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.opportunities o
    WHERE o.is_active = TRUE
      AND o.status = 'published'
      AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
      AND (v_type IS NULL OR LOWER(o.type) = LOWER(v_type))
      AND (
          v_search IS NULL
          OR o.title ILIKE '%' || v_search || '%'
          OR o.organization_name ILIKE '%' || v_search || '%'
          OR o.city ILIKE '%' || v_search || '%'
          OR o.country ILIKE '%' || v_search || '%'
      )
    LIMIT p_limit OFFSET p_offset;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'opportunities', v_result,
        'total', v_total,
        'has_more', (p_offset + p_limit) < v_total
    );
END;
$$;

-- ============================================================
-- 10. MODIFICATION RPC ADMIN UPSERT (ajout price)
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_admin_upsert_opportunity(
    p_opportunity_id UUID,
    p_title TEXT,
    p_short_description TEXT,
    p_description TEXT,
    p_type TEXT,
    p_category TEXT,
    p_organization_name TEXT,
    p_organization_logo_url TEXT,
    p_country TEXT,
    p_city TEXT,
    p_is_remote_possible BOOLEAN,
    p_contract_type TEXT,
    p_duration_months INTEGER,
    p_start_date DATE,
    p_application_deadline DATE,
    p_status TEXT,
    p_is_featured BOOLEAN,
    p_is_active BOOLEAN,
    p_price NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_opportunity_id UUID;
    v_title TEXT := NULLIF(TRIM(COALESCE(p_title, '')), '');
    v_short_desc TEXT := NULLIF(TRIM(COALESCE(p_short_description, '')), '');
    v_type TEXT := NULLIF(TRIM(COALESCE(p_type, '')), '');
    v_org_name TEXT := NULLIF(TRIM(COALESCE(p_organization_name, '')), '');
    v_country TEXT := NULLIF(TRIM(COALESCE(p_country, '')), '');
    v_city TEXT := NULLIF(TRIM(COALESCE(p_city, '')), '');
    v_status TEXT := COALESCE(NULLIF(TRIM(COALESCE(p_status, '')), ''), 'draft');
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

    IF v_title IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF v_short_desc IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_short_description');
    END IF;

    IF v_type IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_type');
    END IF;

    IF v_org_name IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_organization_name');
    END IF;

    IF v_country IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_country');
    END IF;

    IF v_city IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_city');
    END IF;

    IF p_opportunity_id IS NULL THEN
        -- Création
        INSERT INTO app.opportunities (
            title,
            short_description,
            description,
            type,
            category,
            organization_name,
            organization_logo_url,
            country,
            city,
            is_remote_possible,
            contract_type,
            duration_months,
            start_date,
            application_deadline,
            status,
            is_featured,
            is_active,
            price,
            created_by_user_id
        )
        VALUES (
            v_title,
            v_short_desc,
            p_description,
            v_type,
            p_category,
            v_org_name,
            p_organization_logo_url,
            v_country,
            v_city,
            COALESCE(p_is_remote_possible, FALSE),
            p_contract_type,
            p_duration_months,
            p_start_date,
            p_application_deadline,
            v_status,
            COALESCE(p_is_featured, FALSE),
            COALESCE(p_is_active, TRUE),
            p_price,
            v_user_id
        )
        RETURNING id INTO v_opportunity_id;
    ELSE
        -- Mise à jour
        UPDATE app.opportunities
        SET
            title = v_title,
            short_description = v_short_desc,
            description = p_description,
            type = v_type,
            category = p_category,
            organization_name = v_org_name,
            organization_logo_url = p_organization_logo_url,
            country = v_country,
            city = v_city,
            is_remote_possible = COALESCE(p_is_remote_possible, is_remote_possible),
            contract_type = p_contract_type,
            duration_months = p_duration_months,
            start_date = p_start_date,
            application_deadline = p_application_deadline,
            status = v_status,
            is_featured = COALESCE(p_is_featured, is_featured),
            is_active = COALESCE(p_is_active, is_active),
            price = p_price,
            updated_at = NOW()
        WHERE id = p_opportunity_id
        RETURNING id INTO v_opportunity_id;
    END IF;

    IF v_opportunity_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'opportunity_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'opportunity_id', v_opportunity_id);
END;
$$;
