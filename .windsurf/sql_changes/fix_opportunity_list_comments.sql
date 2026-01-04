-- Fix: Corriger la RPC app_opportunity_list_comments
-- Problème: ORDER BY en double causant une erreur SQL

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
    WITH comments_data AS (
        SELECT 
            c.id,
            c.user_id,
            c.content,
            c.created_at,
            COALESCE(
                u.raw_user_meta_data->>'full_name',
                u.raw_user_meta_data->>'name',
                'Utilisateur'
            ) AS user_name,
            u.raw_user_meta_data->>'avatar_url' AS user_avatar
        FROM app.opportunity_comments c
        LEFT JOIN auth.users u ON u.id = c.user_id
        WHERE c.opportunity_id = p_opportunity_id
        ORDER BY c.created_at DESC
        LIMIT p_limit OFFSET p_offset
    )
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', cd.id,
                'user_id', cd.user_id,
                'content', cd.content,
                'created_at', cd.created_at,
                'user_name', cd.user_name,
                'user_avatar', cd.user_avatar
            )
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM comments_data cd;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'comments', v_result,
        'total', v_total,
        'has_more', (p_offset + p_limit) < v_total
    );
END;
$$;
