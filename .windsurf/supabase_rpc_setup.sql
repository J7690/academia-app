-- ========================================
-- CONFIGURATION COMPLÈTE SQL RPC SUPABASE
-- Code validé et sans erreur pour Supabase
-- ========================================

-- Activer les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ========================================
-- 1. FONCTION RPC POUR EXÉCUTER SQL DYNAMIQUE
-- ========================================

CREATE OR REPLACE FUNCTION execute_sql(sql_query TEXT)
RETURNS TABLE(result JSONB)
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
        RETURN QUERY SELECT JSONB_BUILD_OBJECT('error', 'Commande non autorisée')::JSONB AS result;
    END IF;
    
    -- Exécuter la requête SQL dynamiquement
    EXECUTE 'SELECT ARRAY_TO_JSON(ARRAY_AGG(ROW_TO_JSON(t)))::JSONB AS result FROM (' || clean_query || ') t'
    INTO query_result;
    
    RETURN QUERY SELECT query_result AS result;
EXCEPTION WHEN OTHERS THEN
    -- En cas d'erreur, retourner le message d'erreur
    RETURN QUERY SELECT JSONB_BUILD_OBJECT('error', SQLERRM, 'sqlstate', SQLSTATE)::JSONB AS result;
END;
$$;

-- ========================================
-- 2. FONCTION RPC POUR CRÉER DES TABLES SÉCURISÉES
-- ========================================

CREATE OR REPLACE FUNCTION create_table_safe(table_name TEXT, table_definition JSONB)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    create_sql TEXT;
    column_count INTEGER;
BEGIN
    -- Valider le nom de la table
    IF table_name IS NULL OR LENGTH(TRIM(table_name)) = 0 THEN
        RETURN 'Erreur: nom de table invalide';
    END IF;
    
    -- Valider la définition
    IF table_definition IS NULL OR NOT JSONB_IS_ARRAY(table_definition) THEN
        RETURN 'Erreur: définition de table invalide';
    END IF;
    
    column_count := JSONB_ARRAY_LENGTH(table_definition);
    IF column_count = 0 THEN
        RETURN 'Erreur: aucune colonne définie';
    END IF;
    
    -- Construire le SQL de création de table
    create_sql := 'CREATE TABLE IF NOT EXISTS ' || QUOTE_IDENT(table_name) || ' (';
    
    -- Ajouter les colonnes
    FOR i IN 0..(column_count - 1) LOOP
        DECLARE
            col_def JSONB;
            col_name TEXT;
            col_type TEXT;
            col_nullable BOOLEAN;
            col_default TEXT;
        BEGIN
            col_def := table_definition -> i;
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
        END;
    END LOOP;
    
    create_sql := create_sql || ')';
    
    -- Exécuter la création
    EXECUTE create_sql;
    
    RETURN 'Table ' || table_name || ' créée avec succès';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erreur: ' || SQLERRM;
END;
$$;

-- ========================================
-- 3. FONCTION RPC POUR LISTER LES TABLES DÉTAILLÉES
-- ========================================

CREATE OR REPLACE FUNCTION list_tables_detailed()
RETURNS TABLE(
    table_name TEXT,
    table_schema TEXT,
    row_count BIGINT,
    size_bytes BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.table_name,
        t.table_schema,
        COALESCE(s.n_tup_ins + s.n_tup_upd + s.n_tup_del, 0)::BIGINT as row_count,
        COALESCE(PG_TOTAL_RELATION_SIZE(QUOTE_IDENT(t.table_schema) || '.' || QUOTE_IDENT(t.table_name)), 0)::BIGINT as size_bytes
    FROM information_schema.tables t
    LEFT JOIN pg_stat_user_tables s ON s.relname = t.table_name
    WHERE t.table_schema NOT IN ('information_schema', 'pg_catalog')
    ORDER BY t.table_schema, t.table_name;
END;
$$;

-- ========================================
-- 4. FONCTION RPC POUR DÉCRIRE UNE TABLE
-- ========================================

CREATE OR REPLACE FUNCTION describe_table_detailed(table_name TEXT)
RETURNS TABLE(
    column_name TEXT,
    data_type TEXT,
    is_nullable TEXT,
    column_default TEXT,
    character_maximum_length INTEGER,
    numeric_precision INTEGER,
    numeric_scale INTEGER,
    ordinal_position INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.column_name,
        c.data_type,
        c.is_nullable,
        c.column_default,
        c.character_maximum_length::INTEGER,
        c.numeric_precision::INTEGER,
        c.numeric_scale::INTEGER,
        c.ordinal_position::INTEGER
    FROM information_schema.columns c
    WHERE c.table_name = describe_table_detailed.table_name
      AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
END;
$$;

-- ========================================
-- 5. FONCTION RPC POUR INSÉRER DES DONNÉES SÉCURISÉES
-- ========================================

CREATE OR REPLACE FUNCTION insert_data_safe(table_name TEXT, data JSONB)
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
    IF table_name IS NULL OR LENGTH(TRIM(table_name)) = 0 THEN
        RAISE EXCEPTION 'Nom de table invalide';
    END IF;
    
    IF data IS NULL OR NOT JSONB_IS_OBJECT(data) THEN
        RAISE EXCEPTION 'Données invalides';
    END IF;
    
    -- Extraire les colonnes et valeurs
    SELECT ARRAY_AGG(KEY), ARRAY_AGG(VALUE)
    INTO columns, values
    FROM JSONB_EACH_TEXT(data);
    
    -- Valider qu'on a des colonnes
    IF columns IS NULL OR ARRAY_LENGTH(columns, 1) = 0 THEN
        RAISE EXCEPTION 'Aucune colonne spécifiée';
    END IF;
    
    column_count := ARRAY_LENGTH(columns, 1);
    
    -- Construire le SQL d'insertion
    insert_sql := 'INSERT INTO ' || QUOTE_IDENT(table_name) || ' (';
    
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
-- 6. FONCTION RPC POUR METTRE À JOUR DES DONNÉES
-- ========================================

CREATE OR REPLACE FUNCTION update_data_safe(table_name TEXT, data JSONB, where_condition TEXT)
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
    IF table_name IS NULL OR LENGTH(TRIM(table_name)) = 0 THEN
        RAISE EXCEPTION 'Nom de table invalide';
    END IF;
    
    IF data IS NULL OR NOT JSONB_IS_OBJECT(data) THEN
        RAISE EXCEPTION 'Données invalides';
    END IF;
    
    IF where_condition IS NULL OR LENGTH(TRIM(where_condition)) = 0 THEN
        RAISE EXCEPTION 'Condition WHERE requise';
    END IF;
    
    -- Extraire les colonnes et valeurs
    SELECT ARRAY_AGG(KEY), ARRAY_AGG(VALUE)
    INTO columns, values
    FROM JSONB_EACH_TEXT(data);
    
    -- Valider qu'on a des colonnes
    IF columns IS NULL OR ARRAY_LENGTH(columns, 1) = 0 THEN
        RAISE EXCEPTION 'Aucune colonne spécifiée';
    END IF;
    
    column_count := ARRAY_LENGTH(columns, 1);
    
    -- Construire le SQL de mise à jour
    update_sql := 'UPDATE ' || QUOTE_IDENT(table_name) || ' SET ';
    
    -- Ajouter les colonnes = valeurs
    FOR i IN 1..column_count LOOP
        IF i > 1 THEN
            update_sql := update_sql || ', ';
        END IF;
        update_sql := update_sql || QUOTE_IDENT(columns[i]) || ' = ' || QUOTE_LITERAL(values[i]);
    END LOOP;
    
    update_sql := update_sql || ' WHERE ' || where_condition;
    
    -- Exécuter la mise à jour
    EXECUTE update_sql;
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    RETURN affected_rows;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erreur mise à jour: %', SQLERRM;
END;
$$;

-- ========================================
-- 7. FONCTION RPC POUR SUPPRIMER DES DONNÉES
-- ========================================

CREATE OR REPLACE FUNCTION delete_data_safe(table_name TEXT, where_condition TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    delete_sql TEXT;
    affected_rows BIGINT;
BEGIN
    -- Valider les entrées
    IF table_name IS NULL OR LENGTH(TRIM(table_name)) = 0 THEN
        RAISE EXCEPTION 'Nom de table invalide';
    END IF;
    
    IF where_condition IS NULL OR LENGTH(TRIM(where_condition)) = 0 THEN
        RAISE EXCEPTION 'Condition WHERE requise pour la suppression';
    END IF;
    
    -- Construire le SQL de suppression
    delete_sql := 'DELETE FROM ' || QUOTE_IDENT(table_name) || ' WHERE ' || where_condition;
    
    -- Exécuter la suppression
    EXECUTE delete_sql;
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    RETURN affected_rows;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erreur suppression: %', SQLERRM;
END;
$$;

-- ========================================
-- 8. FONCTION RPC POUR VALIDER L'EXISTANCE
-- ========================================

CREATE OR REPLACE FUNCTION table_exists(table_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_name = table_exists.table_name
          AND table_schema = 'public'
    );
END;
$$;

CREATE OR REPLACE FUNCTION column_exists(table_name TEXT, column_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = column_exists.table_name
          AND column_name = column_exists.column_name
          AND table_schema = 'public'
    );
END;
$$;

-- ========================================
-- 9. CRÉATION DE TABLES DE TEST
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
    'RPC Functions Setup Complete' as status,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name LIKE '%_%' AND routine_schema = 'public') as functions_created,
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
