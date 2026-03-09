-- ========================================
-- CORRECTION FINALE: describe_table_detailed
-- Résout l'erreur GROUP BY
-- ========================================

-- Supprimer l'ancienne fonction
DROP FUNCTION IF EXISTS describe_table_detailed(TEXT);

-- ========================================
-- 4. FONCTION RPC POUR DÉCRIRE UNE TABLE (VERSION 100% CORRIGÉE)
-- ========================================

CREATE OR REPLACE FUNCTION describe_table_detailed(p_table_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Utiliser une sous-requête pour éviter le problème GROUP BY
    -- et garantir un retour JSONB array même pour une seule colonne
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'column_name', col_info.column_name::TEXT,
                'data_type', col_info.data_type::TEXT,
                'is_nullable', col_info.is_nullable::TEXT,
                'column_default', col_info.column_default::TEXT,
                'character_maximum_length', col_info.character_maximum_length::INTEGER,
                'numeric_precision', col_info.numeric_precision::INTEGER,
                'numeric_scale', col_info.numeric_scale::INTEGER,
                'ordinal_position', col_info.ordinal_position::INTEGER
            )
        ),
        '[]'::JSONB
    ) INTO result
    FROM (
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length,
            numeric_precision,
            numeric_scale,
            ordinal_position
        FROM information_schema.columns 
        WHERE table_name = p_table_name
          AND table_schema = 'public'
        ORDER BY ordinal_position
    ) col_info;
    
    RETURN result;
EXCEPTION WHEN OTHERS THEN
    RETURN JSONB_BUILD_OBJECT('error', SQLERRM);
END;
$$;

-- ========================================
-- ACCORDER LES PERMISSIONS
-- ========================================

GRANT EXECUTE ON FUNCTION describe_table_detailed TO service_role;
GRANT EXECUTE ON FUNCTION describe_table_detailed TO authenticated;

-- ========================================
-- VALIDATION
-- ========================================

-- Vérifier que la fonction a été créée
SELECT 
    'describe_table_detailed fixed' as status,
    routine_name as function_name,
    routine_type as type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_name = 'describe_table_detailed'
  AND routine_schema = 'public';
