-- ========================================
-- CONFIGURATION SQL RPC SUPABASE - VERSION FINALE
-- Corrige les dernières erreurs SQL
-- ========================================

-- Supprimer les anciennes fonctions pour recréation propre
DROP FUNCTION IF EXISTS execute_sql(TEXT);
DROP FUNCTION IF EXISTS create_table_safe(TEXT, JSONB);
DROP FUNCTION IF EXISTS list_tables_detailed();
DROP FUNCTION IF EXISTS describe_table_detailed(TEXT);
DROP FUNCTION IF EXISTS insert_data_safe(TEXT, JSONB);
DROP FUNCTION IF EXISTS update_data_safe(TEXT, JSONB, TEXT);
DROP FUNCTION IF EXISTS delete_data_safe(TEXT, TEXT);
DROP FUNCTION IF EXISTS table_exists(TEXT);
DROP FUNCTION IF EXISTS column_exists(TEXT, TEXT);

-- ========================================
-- 1. FONCTION RPC POUR EXÉCUTER SQL DYNAMIQUE (FINALE)
-- ========================================

CREATE OR REPLACE FUNCTION execute_sql(sql_query TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    query_result JSONB;
    clean_query TEXT;
BEGIN
    -- Nettoyer et valider la requête
    clean_query := TRIM(sql_query);
    
    -- Interdire les commandes dangereuses
    IF clean_query ~* '(DROP\s+DATABASE|ALTER\s+DATABASE|CREATE\s+DATABASE|TRUNCATE\s+DATABASE)' THEN
        RETURN JSONB_BUILD_OBJECT('error', 'Commande non autorisée');
    END IF;
    
    -- Exécuter la requête SQL dynamiquement
    EXECUTE 'SELECT ARRAY_TO_JSON(ARRAY_AGG(ROW_TO_JSON(t)))::JSONB FROM (' || clean_query || ') t'
    INTO query_result;
    
    RETURN query_result;
EXCEPTION WHEN OTHERS THEN
    -- En cas d'erreur, retourner le message d'erreur
    RETURN JSONB_BUILD_OBJECT('error', SQLERRM, 'sqlstate', SQLSTATE);
END;
$$;

-- ========================================
-- 2. FONCTION RPC POUR CRÉER DES TABLES SÉCURISÉES (FINALE)
-- ========================================

CREATE OR REPLACE FUNCTION create_table_safe(p_table_name TEXT, p_table_definition JSONB)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    create_sql TEXT;
    column_count INTEGER;
    col_def JSONB;
    col_name TEXT;
    col_type TEXT;
    col_nullable BOOLEAN;
    col_default TEXT;
BEGIN
    -- Valider le nom de la table
    IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
        RETURN 'Erreur: nom de table invalide';
    END IF;
    
    -- Valider la définition
    IF p_table_definition IS NULL OR JSONB_ARRAY_LENGTH(p_table_definition) = 0 THEN
        RETURN 'Erreur: définition de table invalide';
    END IF;
    
    column_count := JSONB_ARRAY_LENGTH(p_table_definition);
    
    -- Construire le SQL de création de table
    create_sql := 'CREATE TABLE IF NOT EXISTS ' || QUOTE_IDENT(p_table_name) || ' (';
    
    -- Ajouter les colonnes
    FOR i IN 0..(column_count - 1) LOOP
        col_def := p_table_definition -> i;
        col_name := col_def ->> 'name';
        col_type := col_def ->> 'type';
        col_nullable := COALESCE((col_def ->> 'nullable')::BOOLEAN, TRUE);
        col_default := col_def ->> 'default';
        
        -- Valider le nom et type de colonne
        IF col_name IS NULL OR LENGTH(TRIM(col_name)) = 0 THEN
            CONTINUE;
        END IF;
        
        IF col_type IS NULL OR LENGTH(TRIM(col_type)) = 0 THEN
            CONTINUE;
        END IF;
        
        IF i > 0 THEN
            create_sql := create_sql || ', ';
        END IF;
        
        create_sql := create_sql || QUOTE_IDENT(col_name) || ' ' || col_type;
        
        IF NOT col_nullable THEN
            create_sql := create_sql || ' NOT NULL';
        END IF;
        
        IF col_default IS NOT NULL AND LENGTH(TRIM(col_default)) > 0 THEN
            create_sql := create_sql || ' DEFAULT ' || col_default;
        END IF;
        
        -- Ajouter PRIMARY KEY si spécifié
        IF COALESCE((col_def ->> 'primary_key')::BOOLEAN, FALSE) THEN
            create_sql := create_sql || ' PRIMARY KEY';
        END IF;
    END LOOP;
    
    create_sql := create_sql || ')';
    
    -- Exécuter la création
    EXECUTE create_sql;
    
    RETURN 'Table ' || p_table_name || ' créée avec succès';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erreur: ' || SQLERRM;
END;
$$;

-- ========================================
-- 3. FONCTION RPC POUR LISTER LES TABLES DÉTAILLÉES (CORRIGÉE)
-- ========================================

CREATE OR REPLACE FUNCTION list_tables_detailed()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Corriger le GROUP BY en utilisant une sous-requête
    SELECT JSONB_AGG(
        JSONB_BUILD_OBJECT(
            'table_name', t.table_name::TEXT,
            'table_schema', t.table_schema::TEXT,
            'row_count', COALESCE(s.n_tup_ins + s.n_tup_upd + s.n_tup_del, 0)::BIGINT,
            'size_bytes', COALESCE(PG_TOTAL_RELATION_SIZE(QUOTE_IDENT(t.table_schema) || '.' || QUOTE_IDENT(t.table_name)), 0)::BIGINT
        )
    ) INTO result
    FROM (
        SELECT table_name, table_schema
        FROM information_schema.tables 
        WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY table_schema, table_name
    ) t
    LEFT JOIN pg_stat_user_tables s ON s.relname = t.table_name;
    
    RETURN COALESCE(result, '[]'::JSONB);
END;
$$;

-- ========================================
-- 4. FONCTION RPC POUR DÉCRIRE UNE TABLE (CORRIGÉE)
-- ========================================

CREATE OR REPLACE FUNCTION describe_table_detailed(p_table_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- S'assurer de retourner un tableau JSON même pour une seule colonne
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'column_name', c.column_name::TEXT,
                'data_type', c.data_type::TEXT,
                'is_nullable', c.is_nullable::TEXT,
                'column_default', c.column_default::TEXT,
                'character_maximum_length', c.character_maximum_length::INTEGER,
                'numeric_precision', c.numeric_precision::INTEGER,
                'numeric_scale', c.numeric_scale::INTEGER,
                'ordinal_position', c.ordinal_position::INTEGER
            )
        ),
        '[]'::JSONB
    ) INTO result
    FROM information_schema.columns c
    WHERE c.table_name = p_table_name
      AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
    
    RETURN result;
EXCEPTION WHEN OTHERS THEN
    RETURN JSONB_BUILD_OBJECT('error', SQLERRM);
END;
$$;

-- ========================================
-- 5. FONCTION RPC POUR INSÉRER DES DONNÉES SÉCURISÉES (FINALE)
-- ========================================

CREATE OR REPLACE FUNCTION insert_data_safe(p_table_name TEXT, p_data JSONB)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    inserted_id BIGINT;
    columns TEXT[];
    values TEXT[];
    insert_sql TEXT;
    column_count INTEGER;
BEGIN
    -- Valider les entrées
    IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
        RAISE EXCEPTION 'Nom de table invalide';
    END IF;
    
    IF p_data IS NULL OR JSONB_TYPEOF(p_data) != 'object' THEN
        RAISE EXCEPTION 'Données invalides';
    END IF;
    
    -- Extraire les colonnes et valeurs
    SELECT ARRAY_AGG(KEY), ARRAY_AGG(VALUE)
    INTO columns, values
    FROM JSONB_EACH_TEXT(p_data);
    
    -- Valider qu'on a des colonnes
    IF columns IS NULL OR ARRAY_LENGTH(columns, 1) = 0 THEN
        RAISE EXCEPTION 'Aucune colonne spécifiée';
    END IF;
    
    column_count := ARRAY_LENGTH(columns, 1);
    
    -- Construire le SQL d'insertion
    insert_sql := 'INSERT INTO ' || QUOTE_IDENT(p_table_name) || ' (';
    
    -- Ajouter les colonnes
    FOR i IN 1..column_count LOOP
        IF i > 1 THEN
            insert_sql := insert_sql || ', ';
        END IF;
        insert_sql := insert_sql || QUOTE_IDENT(columns[i]);
    END LOOP;
    
    insert_sql := insert_sql || ') VALUES (';
    
    -- Ajouter les valeurs
    FOR i IN 1..column_count LOOP
        IF i > 1 THEN
            insert_sql := insert_sql || ', ';
        END IF;
        insert_sql := insert_sql || QUOTE_LITERAL(values[i]);
    END LOOP;
    
    insert_sql := insert_sql || ') RETURNING id';
    
    -- Exécuter l'insertion
    EXECUTE insert_sql INTO inserted_id;
    
    RETURN inserted_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erreur insertion: %', SQLERRM;
END;
$$;

-- ========================================
-- 6. FONCTION RPC POUR METTRE À JOUR DES DONNÉES (FINALE)
-- ========================================

CREATE OR REPLACE FUNCTION update_data_safe(p_table_name TEXT, p_data JSONB, p_where_condition TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    update_sql TEXT;
    affected_rows BIGINT;
    columns TEXT[];
    values TEXT[];
    column_count INTEGER;
BEGIN
    -- Valider les entrées
    IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
        RAISE EXCEPTION 'Nom de table invalide';
    END IF;
    
    IF p_data IS NULL OR JSONB_TYPEOF(p_data) != 'object' THEN
        RAISE EXCEPTION 'Données invalides';
    END IF;
    
    IF p_where_condition IS NULL OR LENGTH(TRIM(p_where_condition)) = 0 THEN
        RAISE EXCEPTION 'Condition WHERE requise';
    END IF;
    
    -- Extraire les colonnes et valeurs
    SELECT ARRAY_AGG(KEY), ARRAY_AGG(VALUE)
    INTO columns, values
    FROM JSONB_EACH_TEXT(p_data);
    
    -- Valider qu'on a des colonnes
    IF columns IS NULL OR ARRAY_LENGTH(columns, 1) = 0 THEN
        RAISE EXCEPTION 'Aucune colonne spécifiée';
    END IF;
    
    column_count := ARRAY_LENGTH(columns, 1);
    
    -- Construire le SQL de mise à jour
    update_sql := 'UPDATE ' || QUOTE_IDENT(p_table_name) || ' SET ';
    
    -- Ajouter les colonnes = valeurs
    FOR i IN 1..column_count LOOP
        IF i > 1 THEN
            update_sql := update_sql || ', ';
        END IF;
        update_sql := update_sql || QUOTE_IDENT(columns[i]) || ' = ' || QUOTE_LITERAL(values[i]);
    END LOOP;
    
    update_sql := update_sql || ' WHERE ' || p_where_condition;
    
    -- Exécuter la mise à jour
    EXECUTE update_sql;
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    RETURN affected_rows;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erreur mise à jour: %', SQLERRM;
END;
$$;

-- ========================================
-- 7. FONCTION RPC POUR SUPPRIMER DES DONNÉES (FINALE)
-- ========================================

CREATE OR REPLACE FUNCTION delete_data_safe(p_table_name TEXT, p_where_condition TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    delete_sql TEXT;
    affected_rows BIGINT;
BEGIN
    -- Valider les entrées
    IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
        RAISE EXCEPTION 'Nom de table invalide';
    END IF;
    
    IF p_where_condition IS NULL OR LENGTH(TRIM(p_where_condition)) = 0 THEN
        RAISE EXCEPTION 'Condition WHERE requise pour la suppression';
    END IF;
    
    -- Construire le SQL de suppression
    delete_sql := 'DELETE FROM ' || QUOTE_IDENT(p_table_name) || ' WHERE ' || p_where_condition;
    
    -- Exécuter la suppression
    EXECUTE delete_sql;
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    RETURN affected_rows;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erreur suppression: %', SQLERRM;
END;
$$;

-- ========================================
-- 8. FONCTION RPC POUR VALIDER L'EXISTANCE (FINALE)
-- ========================================

CREATE OR REPLACE FUNCTION table_exists(p_table_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_name = p_table_name
          AND table_schema = 'public'
    );
END;
$$;

CREATE OR REPLACE FUNCTION column_exists(p_table_name TEXT, p_column_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = p_table_name
          AND column_name = p_column_name
          AND table_schema = 'public'
    );
END;
$$;

-- ========================================
-- 9. RECÉER LA TABLE DE TEST
-- ========================================

-- Table de test pour validation
CREATE TABLE IF NOT EXISTS rpc_validation_test (
    id SERIAL PRIMARY KEY,
    test_name TEXT NOT NULL,
    test_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insérer des données de test
INSERT INTO rpc_validation_test (test_name, test_data) VALUES 
    ('Test RPC Execute SQL', '{"status": "success", "timestamp": "2024-01-01"}'),
    ('Test RPC Create Table', '{"table": "created", "columns": 5}'),
    ('Test RPC Insert Data', '{"rows": 3, "status": "completed"}')
ON CONFLICT DO NOTHING;

-- ========================================
-- 10. ACCORDER LES PERMISSIONS
-- ========================================

-- Donner les permissions à service_role (accès complet)
GRANT EXECUTE ON FUNCTION execute_sql TO service_role;
GRANT EXECUTE ON FUNCTION create_table_safe TO service_role;
GRANT EXECUTE ON FUNCTION list_tables_detailed TO service_role;
GRANT EXECUTE ON FUNCTION describe_table_detailed TO service_role;
GRANT EXECUTE ON FUNCTION insert_data_safe TO service_role;
GRANT EXECUTE ON FUNCTION update_data_safe TO service_role;
GRANT EXECUTE ON FUNCTION delete_data_safe TO service_role;
GRANT EXECUTE ON FUNCTION table_exists TO service_role;
GRANT EXECUTE ON FUNCTION column_exists TO service_role;

-- Donner les permissions à authenticated (utilisateur connecté)
GRANT EXECUTE ON FUNCTION execute_sql TO authenticated;
GRANT EXECUTE ON FUNCTION create_table_safe TO authenticated;
GRANT EXECUTE ON FUNCTION list_tables_detailed TO authenticated;
GRANT EXECUTE ON FUNCTION describe_table_detailed TO authenticated;
GRANT EXECUTE ON FUNCTION insert_data_safe TO authenticated;
GRANT EXECUTE ON FUNCTION update_data_safe TO authenticated;
GRANT EXECUTE ON FUNCTION delete_data_safe TO authenticated;
GRANT EXECUTE ON FUNCTION table_exists TO authenticated;
GRANT EXECUTE ON FUNCTION column_exists TO authenticated;

-- Donner les permissions sur la table de test
GRANT ALL ON rpc_validation_test TO service_role;
GRANT SELECT, INSERT, UPDATE ON rpc_validation_test TO authenticated;

-- ========================================
-- 11. VALIDATION FINALE
-- ========================================

-- Vérifier que toutes les fonctions ont été créées
SELECT 
    'RPC Functions Final Setup Complete' as status,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name IN (
        'execute_sql', 'create_table_safe', 'list_tables_detailed', 
        'describe_table_detailed', 'insert_data_safe', 'update_data_safe', 
        'delete_data_safe', 'table_exists', 'column_exists'
    ) AND routine_schema = 'public') as functions_created,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'rpc_validation_test' AND table_schema = 'public') as test_tables_created,
    (SELECT COUNT(*) FROM rpc_validation_test) as test_data_inserted;

-- Afficher un résumé des fonctions disponibles
SELECT 
    routine_name as function_name,
    routine_type as type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_name IN (
    'execute_sql',
    'create_table_safe', 
    'list_tables_detailed',
    'describe_table_detailed',
    'insert_data_safe',
    'update_data_safe',
    'delete_data_safe',
    'table_exists',
    'column_exists'
)
ORDER BY routine_name;
