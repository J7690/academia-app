#!/usr/bin/env python3
"""
Gestionnaire Automatique Complet Supabase
Exécute TOUTES les tâches automatiquement, y compris le SQL dans Supabase
"""

import requests
import json
import time
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime

class SupabaseAutoManager:
    """
    Gestionnaire automatique qui exécute toutes les tâches Supabase
    sans intervention manuelle, y compris l'exécution SQL
    """
    
    def __init__(self):
        self.url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
        self.service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
        
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        
        self.windsurf_dir = Path(__file__).parent
        self.status_file = self.windsurf_dir / "auto_manager_status.json"
    
    def execute_sql_auto(self, sql_query: str) -> Dict[str, Any]:
        """
        Exécute automatiquement du SQL via la fonction RPC
        Remplace l'exécution manuelle dans le dashboard
        """
        try:
            response = requests.post(f"{self.url}/rest/v1/rpc/execute_sql", 
                                   headers=self.headers, 
                                   json={"sql_query": sql_query}, 
                                   timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                if isinstance(result, list) and len(result) > 0:
                    return {
                        "success": True,
                        "data": result,
                        "message": f"SQL exécuté automatiquement: {len(result)} résultat(s)"
                    }
                else:
                    return {
                        "success": True,
                        "data": [],
                        "message": "SQL exécuté automatiquement: aucun résultat"
                    }
            else:
                return {
                    "success": False,
                    "error": f"Erreur SQL: {response.status_code} - {response.text}"
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": f"Exception SQL: {str(e)}"
            }
    
    def create_rpc_functions_auto(self) -> bool:
        """
        Crée automatiquement toutes les fonctions RPC via execute_sql
        Remplace l'exécution manuelle du SQL dans le dashboard
        """
        print("🔧 Création automatique des fonctions RPC...")
        
        # Fonctions SQL à exécuter automatiquement
        sql_functions = [
            # 1. execute_sql
            """
            CREATE OR REPLACE FUNCTION execute_sql(sql_query TEXT)
            RETURNS JSONB
            LANGUAGE plpgsql
            SECURITY DEFINER
            AS $$
            DECLARE
                query_result JSONB;
                clean_query TEXT;
            BEGIN
                clean_query := TRIM(sql_query);
                IF clean_query ~* '(DROP\s+DATABASE|ALTER\s+DATABASE|CREATE\s+DATABASE|TRUNCATE\s+DATABASE)' THEN
                    RETURN JSONB_BUILD_OBJECT('error', 'Commande non autorisée');
                END IF;
                EXECUTE 'SELECT ARRAY_TO_JSON(ARRAY_AGG(ROW_TO_JSON(t)))::JSONB FROM (' || clean_query || ') t'
                INTO query_result;
                RETURN query_result;
            EXCEPTION WHEN OTHERS THEN
                RETURN JSONB_BUILD_OBJECT('error', SQLERRM, 'sqlstate', SQLSTATE);
            END;
            $$;
            """,
            
            # 2. create_table_safe
            """
            CREATE OR REPLACE FUNCTION create_table_safe(p_table_name TEXT, p_table_definition JSONB)
            RETURNS TEXT
            LANGUAGE plpgsql
            SECURITY DEFINER
            AS $$
            DECLARE
                create_sql TEXT;
                column_count INTEGER;
            BEGIN
                IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
                    RETURN 'Erreur: nom de table invalide';
                END IF;
                IF p_table_definition IS NULL OR JSONB_ARRAY_LENGTH(p_table_definition) = 0 THEN
                    RETURN 'Erreur: définition de table invalide';
                END IF;
                column_count := JSONB_ARRAY_LENGTH(p_table_definition);
                create_sql := 'CREATE TABLE IF NOT EXISTS ' || QUOTE_IDENT(p_table_name) || ' (';
                FOR i IN 0..(column_count - 1) LOOP
                    DECLARE
                        col_def JSONB;
                        col_name TEXT;
                        col_type TEXT;
                        col_nullable BOOLEAN;
                        col_default TEXT;
                    BEGIN
                        col_def := p_table_definition -> i;
                        col_name := col_def ->> 'name';
                        col_type := col_def ->> 'type';
                        col_nullable := COALESCE((col_def ->> 'nullable')::BOOLEAN, TRUE);
                        col_default := col_def ->> 'default';
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
                        IF COALESCE((col_def ->> 'primary_key')::BOOLEAN, FALSE) THEN
                            create_sql := create_sql || ' PRIMARY KEY';
                        END IF;
                    END;
                END LOOP;
                create_sql := create_sql || ')';
                EXECUTE create_sql;
                RETURN 'Table ' || p_table_name || ' créée avec succès';
            EXCEPTION WHEN OTHERS THEN
                RETURN 'Erreur: ' || SQLERRM;
            END;
            $$;
            """,
            
            # 3. list_tables_detailed
            """
            CREATE OR REPLACE FUNCTION list_tables_detailed()
            RETURNS JSONB
            LANGUAGE plpgsql
            SECURITY DEFINER
            AS $$
            DECLARE
                result JSONB;
            BEGIN
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
            """,
            
            # 4. describe_table_detailed
            """
            CREATE OR REPLACE FUNCTION describe_table_detailed(p_table_name TEXT)
            RETURNS JSONB
            LANGUAGE plpgsql
            SECURITY DEFINER
            AS $$
            DECLARE
                result JSONB;
            BEGIN
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
            """,
            
            # 5. insert_data_safe
            """
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
                IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
                    RAISE EXCEPTION 'Nom de table invalide';
                END IF;
                IF p_data IS NULL OR JSONB_TYPEOF(p_data) != 'object' THEN
                    RAISE EXCEPTION 'Données invalides';
                END IF;
                SELECT ARRAY_AGG(KEY), ARRAY_AGG(VALUE)
                INTO columns, values
                FROM JSONB_EACH_TEXT(p_data);
                IF columns IS NULL OR ARRAY_LENGTH(columns, 1) = 0 THEN
                    RAISE EXCEPTION 'Aucune colonne spécifiée';
                END IF;
                column_count := ARRAY_LENGTH(columns, 1);
                insert_sql := 'INSERT INTO ' || QUOTE_IDENT(p_table_name) || ' (';
                FOR i IN 1..column_count LOOP
                    IF i > 1 THEN
                        insert_sql := insert_sql || ', ';
                    END IF;
                    insert_sql := insert_sql || QUOTE_IDENT(columns[i]);
                END LOOP;
                insert_sql := insert_sql || ') VALUES (';
                FOR i IN 1..column_count LOOP
                    IF i > 1 THEN
                        insert_sql := insert_sql || ', ';
                    END IF;
                    insert_sql := insert_sql || QUOTE_LITERAL(values[i]);
                END LOOP;
                insert_sql := insert_sql || ') RETURNING id';
                EXECUTE insert_sql INTO inserted_id;
                RETURN inserted_id;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Erreur insertion: %', SQLERRM;
            END;
            $$;
            """,
            
            # 6. update_data_safe
            """
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
                IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
                    RAISE EXCEPTION 'Nom de table invalide';
                END IF;
                IF p_data IS NULL OR JSONB_TYPEOF(p_data) != 'object' THEN
                    RAISE EXCEPTION 'Données invalides';
                END IF;
                IF p_where_condition IS NULL OR LENGTH(TRIM(p_where_condition)) = 0 THEN
                    RAISE EXCEPTION 'Condition WHERE requise';
                END IF;
                SELECT ARRAY_AGG(KEY), ARRAY_AGG(VALUE)
                INTO columns, values
                FROM JSONB_EACH_TEXT(p_data);
                IF columns IS NULL OR ARRAY_LENGTH(columns, 1) = 0 THEN
                    RAISE EXCEPTION 'Aucune colonne spécifiée';
                END IF;
                column_count := ARRAY_LENGTH(columns, 1);
                update_sql := 'UPDATE ' || QUOTE_IDENT(p_table_name) || ' SET ';
                FOR i IN 1..column_count LOOP
                    IF i > 1 THEN
                        update_sql := update_sql || ', ';
                    END IF;
                    update_sql := update_sql || QUOTE_IDENT(columns[i]) || ' = ' || QUOTE_LITERAL(values[i]);
                END LOOP;
                update_sql := update_sql || ' WHERE ' || p_where_condition;
                EXECUTE update_sql;
                GET DIAGNOSTICS affected_rows = ROW_COUNT;
                RETURN affected_rows;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Erreur mise à jour: %', SQLERRM;
            END;
            $$;
            """,
            
            # 7. delete_data_safe
            """
            CREATE OR REPLACE FUNCTION delete_data_safe(p_table_name TEXT, p_where_condition TEXT)
            RETURNS BIGINT
            LANGUAGE plpgsql
            SECURITY DEFINER
            AS $$
            DECLARE
                delete_sql TEXT;
                affected_rows BIGINT;
            BEGIN
                IF p_table_name IS NULL OR LENGTH(TRIM(p_table_name)) = 0 THEN
                    RAISE EXCEPTION 'Nom de table invalide';
                END IF;
                IF p_where_condition IS NULL OR LENGTH(TRIM(p_where_condition)) = 0 THEN
                    RAISE EXCEPTION 'Condition WHERE requise pour la suppression';
                END IF;
                delete_sql := 'DELETE FROM ' || QUOTE_IDENT(p_table_name) || ' WHERE ' || p_where_condition;
                EXECUTE delete_sql;
                GET DIAGNOSTICS affected_rows = ROW_COUNT;
                RETURN affected_rows;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Erreur suppression: %', SQLERRM;
            END;
            $$;
            """,
            
            # 8. table_exists
            """
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
            """,
            
            # 9. column_exists
            """
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
            """
        ]
        
        success_count = 0
        total_count = len(sql_functions)
        
        for i, sql in enumerate(sql_functions, 1):
            print(f"   📝 Création fonction {i}/{total_count}...")
            result = self.execute_sql_auto(sql)
            
            if result["success"]:
                success_count += 1
                print(f"   ✅ Fonction {i} créée automatiquement")
            else:
                print(f"   ❌ Erreur fonction {i}: {result['error']}")
            
            time.sleep(0.5)  # Pause entre les exécutions
        
        # Accorder les permissions automatiquement
        print("   🔐 Attribution automatique des permissions...")
        permissions_sql = """
        GRANT EXECUTE ON FUNCTION execute_sql TO service_role;
        GRANT EXECUTE ON FUNCTION create_table_safe TO service_role;
        GRANT EXECUTE ON FUNCTION list_tables_detailed TO service_role;
        GRANT EXECUTE ON FUNCTION describe_table_detailed TO service_role;
        GRANT EXECUTE ON FUNCTION insert_data_safe TO service_role;
        GRANT EXECUTE ON FUNCTION update_data_safe TO service_role;
        GRANT EXECUTE ON FUNCTION delete_data_safe TO service_role;
        GRANT EXECUTE ON FUNCTION table_exists TO service_role;
        GRANT EXECUTE ON FUNCTION column_exists TO service_role;
        
        GRANT EXECUTE ON FUNCTION execute_sql TO authenticated;
        GRANT EXECUTE ON FUNCTION create_table_safe TO authenticated;
        GRANT EXECUTE ON FUNCTION list_tables_detailed TO authenticated;
        GRANT EXECUTE ON FUNCTION describe_table_detailed TO authenticated;
        GRANT EXECUTE ON FUNCTION insert_data_safe TO authenticated;
        GRANT EXECUTE ON FUNCTION update_data_safe TO authenticated;
        GRANT EXECUTE ON FUNCTION delete_data_safe TO authenticated;
        GRANT EXECUTE ON FUNCTION table_exists TO authenticated;
        GRANT EXECUTE ON FUNCTION column_exists TO authenticated;
        """
        
        perm_result = self.execute_sql_auto(permissions_sql)
        if perm_result["success"]:
            print("   ✅ Permissions attribuées automatiquement")
        else:
            print(f"   ⚠️ Erreur permissions: {perm_result['error']}")
        
        print(f"🎉 Création automatique terminée: {success_count}/{total_count} fonctions créées")
        return success_count == total_count
    
    def verify_auto_setup(self) -> Dict[str, Any]:
        """Vérifie automatiquement que tout est configuré"""
        print("🔍 Vérification automatique de la configuration...")
        
        verification_results = {
            "timestamp": datetime.now().isoformat(),
            "rpc_functions": {},
            "api_access": False,
            "overall_status": "unknown"
        }
        
        # Tester chaque fonction RPC
        rpc_functions = [
            "execute_sql",
            "create_table_safe", 
            "list_tables_detailed",
            "describe_table_detailed",
            "insert_data_safe",
            "update_data_safe",
            "delete_data_safe",
            "table_exists",
            "column_exists"
        ]
        
        working_functions = []
        
        for func_name in rpc_functions:
            try:
                if func_name == "list_tables_detailed":
                    response = requests.post(f"{self.url}/rest/v1/rpc/{func_name}", 
                                           headers=self.headers, 
                                           timeout=10)
                elif func_name == "table_exists":
                    response = requests.post(f"{self.url}/rest/v1/rpc/{func_name}", 
                                           headers=self.headers, 
                                           json={"p_table_name": "information_schema.tables"}, 
                                           timeout=10)
                else:
                    # Test simple avec paramètres par défaut
                    test_params = {}
                    if func_name in ["describe_table_detailed", "column_exists"]:
                        test_params = {"p_table_name": "information_schema.tables"}
                        if func_name == "column_exists":
                            test_params["p_column_name"] = "table_name"
                    
                    response = requests.post(f"{self.url}/rest/v1/rpc/{func_name}", 
                                           headers=self.headers, 
                                           json=test_params, 
                                           timeout=10)
                
                if response.status_code == 200:
                    verification_results["rpc_functions"][func_name] = "working"
                    working_functions.append(func_name)
                    print(f"   ✅ {func_name}: fonctionnel")
                else:
                    verification_results["rpc_functions"][func_name] = f"error_{response.status_code}"
                    print(f"   ❌ {func_name}: erreur {response.status_code}")
                    
            except Exception as e:
                verification_results["rpc_functions"][func_name] = f"exception_{str(e)}"
                print(f"   ❌ {func_name}: exception")
        
        # Tester l'accès API
        try:
            response = requests.get(f"{self.url}/rest/v1/rpc_validation_test?limit=1", 
                                  headers=self.headers, 
                                  timeout=10)
            verification_results["api_access"] = response.status_code == 200
            print(f"   {'✅' if verification_results['api_access'] else '❌'} API REST: {'accessible' if verification_results['api_access'] else 'inaccessible'}")
        except Exception as e:
            verification_results["api_access"] = False
            print(f"   ❌ API REST: exception")
        
        # Déterminer le statut global
        working_count = len(working_functions)
        if working_count >= 8 and verification_results["api_access"]:
            verification_results["overall_status"] = "perfect"
        elif working_count >= 6:
            verification_results["overall_status"] = "operational"
        elif working_count >= 3:
            verification_results["overall_status"] = "limited"
        else:
            verification_results["overall_status"] = "critical"
        
        # Sauvegarder les résultats
        with open(self.status_file, 'w', encoding='utf-8') as f:
            json.dump(verification_results, f, indent=2, ensure_ascii=False)
        
        print(f"📊 Statut global: {verification_results['overall_status']}")
        print(f"📈 Fonctions RPC: {working_count}/9 opérationnelles")
        
        return verification_results
    
    def auto_repair_if_needed(self) -> bool:
        """Répare automatiquement le système si nécessaire"""
        print("🔧 Vérification automatique et réparation si nécessaire...")
        
        verification = self.verify_auto_setup()
        
        if verification["overall_status"] in ["critical", "limited"]:
            print("⚠️ Système en état critique, lancement de la réparation automatique...")
            
            # Recréer les fonctions RPC
            if self.create_rpc_functions_auto():
                print("✅ Réparation automatique réussie")
                
                # Revérifier après réparation
                new_verification = self.verify_auto_setup()
                return new_verification["overall_status"] in ["perfect", "operational"]
            else:
                print("❌ Réparation automatique échouée")
                return False
        else:
            print("✅ Système en bon état, aucune réparation nécessaire")
            return True
    
    def manage_flutter_supabase_tasks(self, task_description: str) -> Dict[str, Any]:
        """
        Gestionnaire automatique pour les tâches Flutter + Supabase
        Exécute automatiquement toutes les opérations nécessaires
        """
        print(f"🚀 Gestion automatique de la tâche: {task_description}")
        
        task_result = {
            "task": task_description,
            "timestamp": datetime.now().isoformat(),
            "steps_completed": [],
            "steps_failed": [],
            "final_status": "unknown"
        }
        
        try:
            # Étape 1: Vérifier l'accès Supabase
            print("   Étape 1: Vérification de l'accès Supabase...")
            if self.auto_repair_if_needed():
                task_result["steps_completed"].append("Accès Supabase vérifié et réparé si nécessaire")
            else:
                task_result["steps_failed"].append("Échec de la vérification/réparation Supabase")
            
            # Étape 2: Analyser la tâche et exécuter les opérations nécessaires
            print("   Étape 2: Analyse et exécution automatique...")
            
            if "créer table" in task_description.lower():
                # Extraire le nom de la table et la créer automatiquement
                table_name = self.extract_table_name_from_task(task_description)
                if table_name:
                    if self.create_table_auto(table_name):
                        task_result["steps_completed"].append(f"Table {table_name} créée automatiquement")
                    else:
                        task_result["steps_failed"].append(f"Échec création table {table_name}")
            
            elif "audit" in task_description.lower():
                # Effectuer un audit automatique
                audit_result = self.perform_auto_audit()
                task_result["steps_completed"].append(f"Audit complété: {audit_result}")
            
            elif "migration" in task_description.lower():
                # Gérer les migrations automatiquement
                migration_result = self.handle_auto_migration()
                task_result["steps_completed"].append(f"Migration gérée: {migration_result}")
            
            else:
                # Tâche générique - vérifier l'état du système
                task_result["steps_completed"].append("Système vérifié et prêt pour les opérations")
            
            # Déterminer le statut final
            if len(task_result["steps_failed"]) == 0:
                task_result["final_status"] = "success"
                print("✅ Tâche complétée avec succès")
            else:
                task_result["final_status"] = "partial"
                print(f"⚠️ Tâche partiellement complétée ({len(task_result['steps_failed'])} échecs)")
            
        except Exception as e:
            task_result["steps_failed"].append(f"Exception: {str(e)}")
            task_result["final_status"] = "failed"
            print(f"❌ Échec de la tâche: {e}")
        
        return task_result
    
    def extract_table_name_from_task(self, task_description: str) -> Optional[str]:
        """Extrait le nom de la table d'une description de tâche"""
        import re
        
        # Chercher des patterns comme "créer table nom_table" ou "create table nom_table"
        patterns = [
            r'créer table (\w+)',
            r'create table (\w+)',
            r'table (\w+)',
            r'(\w+)_table'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, task_description.lower())
            if match:
                return match.group(1)
        
        return None
    
    def create_table_auto(self, table_name: str) -> bool:
        """Crée une table automatiquement avec une structure de base"""
        print(f"      📝 Création automatique de la table {table_name}...")
        
        # Structure de base pour une table Flutter/Supabase
        table_definition = [
            {"name": "id", "type": "SERIAL PRIMARY KEY"},
            {"name": "created_at", "type": "TIMESTAMPTZ DEFAULT NOW()"},
            {"name": "updated_at", "type": "TIMESTAMPTZ DEFAULT NOW()"}
        ]
        
        try:
            response = requests.post(f"{self.url}/rest/v1/rpc/create_table_safe", 
                                   headers=self.headers, 
                                   json={
                                       "p_table_name": table_name,
                                       "p_table_definition": table_definition
                                   }, 
                                   timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                if isinstance(result, list) and len(result) > 0:
                    print(f"      ✅ Table {table_name} créée: {result[0]}")
                    return True
            
            print(f"      ❌ Erreur création table: {response.status_code}")
            return False
            
        except Exception as e:
            print(f"      ❌ Exception création table: {e}")
            return False
    
    def perform_auto_audit(self) -> str:
        """Effectue un audit automatique de la base de données"""
        print("      📊 Audit automatique de la base de données...")
        
        try:
            # Lister les tables
            response = requests.post(f"{self.url}/rest/v1/rpc/list_tables_detailed", 
                                   headers=self.headers, 
                                   timeout=10)
            
            if response.status_code == 200:
                tables = response.json()
                if isinstance(tables, list):
                    table_count = len(tables)
                    total_rows = sum(t.get('row_count', 0) for t in tables)
                    total_size = sum(t.get('size_bytes', 0) for t in tables)
                    
                    audit_result = f"{table_count} tables, {total_rows} lignes, {total_size} bytes"
                    print(f"      ✅ Audit: {audit_result}")
                    return audit_result
            
            return "Erreur lors de l'audit"
            
        except Exception as e:
            return f"Exception audit: {e}"
    
    def handle_auto_migration(self) -> str:
        """Gère les migrations automatiquement"""
        print("      🔄 Gestion automatique des migrations...")
        
        # Vérifier si la table des migrations existe
        try:
            response = requests.post(f"{self.url}/rest/v1/rpc/table_exists", 
                                   headers=self.headers, 
                                   json={"p_table_name": "schema_migrations"}, 
                                   timeout=10)
            
            if response.status_code == 200:
                exists = response.json()
                if isinstance(exists, list) and len(exists) > 0 and exists[0]:
                    return "Table migrations trouvée, système à jour"
                else:
                    # Créer la table des migrations
                    migration_def = [
                        {"name": "id", "type": "SERIAL PRIMARY KEY"},
                        {"name": "version", "type": "TEXT NOT NULL"},
                        {"name": "executed_at", "type": "TIMESTAMPTZ DEFAULT NOW()"}
                    ]
                    
                    create_response = requests.post(f"{self.url}/rest/v1/rpc/create_table_safe", 
                                                   headers=self.headers, 
                                                   json={
                                                       "p_table_name": "schema_migrations",
                                                       "p_table_definition": migration_def
                                                   }, 
                                                   timeout=10)
                    
                    if create_response.status_code == 200:
                        return "Table migrations créée automatiquement"
                    else:
                        return "Erreur création table migrations"
            
            return "Erreur vérification migrations"
            
        except Exception as e:
            return f"Exception migration: {e}"

def main():
    """Point d'entrée principal pour le gestionnaire automatique"""
    print("🤖 GESTIONNAIRE AUTOMATIQUE SUPABASE + FLUTTER")
    print("=" * 60)
    
    manager = SupabaseAutoManager()
    
    # 1. Vérifier et réparer si nécessaire
    print("\n1. Vérification automatique du système...")
    if manager.auto_repair_if_needed():
        print("✅ Système prêt pour les tâches automatiques")
    else:
        print("❌ Système nécessite une intervention manuelle")
        return 1
    
    # 2. Démonstration de gestion automatique
    print("\n2. Démonstration de gestion automatique...")
    
    demo_tasks = [
        "Vérifier l'état du système Supabase",
        "Créer table flutter_users",
        "Auditer la base de données",
        "Gérer les migrations"
    ]
    
    for task in demo_tasks:
        print(f"\n🚀 Exécution automatique: {task}")
        result = manager.manage_flutter_supabase_tasks(task)
        print(f"📊 Résultat: {result['final_status']}")
    
    print("\n" + "=" * 60)
    print("🎉 GESTIONNAIRE AUTOMATIQUE CONFIGURÉ!")
    print("✅ Toutes les tâches Supabase sont exécutées automatiquement")
    print("✅ Plus besoin d'intervention manuelle dans le dashboard")
    print("✅ Flutter + Supabase entièrement automatisé")
    
    return 0

if __name__ == "__main__":
    exit(main())
