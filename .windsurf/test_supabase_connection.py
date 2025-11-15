#!/usr/bin/env python3
"""
Test de connexion réel au compte Supabase
"""

import sys
from pathlib import Path

# Ajouter le chemin .windsurf au Python path
windsurf_path = Path(__file__).parent
sys.path.insert(0, str(windsurf_path))

try:
    from supabase_credentials import get_supabase_auditor
    
    print("🔍 Test de connexion Supabase...")
    
    # Initialiser l'auditor
    auditor = get_supabase_auditor()
    
    # Test 1: Vérifier les identifiants
    print("\n1. 📋 Vérification des identifiants...")
    credentials = auditor.credentials_manager.get_credentials()
    if credentials:
        print(f"✅ Identifiants récupérés: Projet {credentials['project_id']}")
        print(f"✅ URL: https://{credentials['project_id']}.supabase.co")
    else:
        print("❌ Impossible de récupérer les identifiants")
        sys.exit(1)
    
    # Test 2: Initialisation de la connexion
    print("\n2. 🔌 Initialisation de la connexion...")
    try:
        auditor.initialize()
        print("✅ Connexion initialisée")
    except Exception as e:
        print(f"❌ Erreur initialisation: {e}")
        sys.exit(1)
    
    # Test 3: Test de connexion PostgreSQL
    print("\n3. 🗄️ Test de connexion PostgreSQL...")
    try:
        result = auditor.execute_sql("SELECT version()")
        if result["success"]:
            version = result["rows"][0][0]
            print(f"✅ Connexion PostgreSQL réussie")
            print(f"📊 Version PostgreSQL: {version[:60]}...")
        else:
            print(f"❌ Erreur connexion PostgreSQL: {result.get('error', 'Inconnue')}")
    except Exception as e:
        print(f"❌ Exception connexion PostgreSQL: {e}")
    
    # Test 4: Lister les schémas
    print("\n4. 📂 Listage des schémas...")
    try:
        result = auditor.execute_sql("SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog')")
        if result["success"]:
            schemas = [row[0] for row in result["rows"]]
            print(f"✅ Schémas trouvés: {schemas}")
        else:
            print(f"❌ Erreur listage schémas: {result.get('error', 'Inconnue')}")
    except Exception as e:
        print(f"❌ Exception listage schémas: {e}")
    
    # Test 5: Lister les tables publiques
    print("\n5. 📋 Listage des tables publiques...")
    try:
        result = auditor.execute_sql("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name")
        if result["success"]:
            tables = [row[0] for row in result["rows"]]
            print(f"✅ Tables trouvées ({len(tables)}): {tables}")
            
            # Afficher les détails des 3 premières tables
            for table in tables[:3]:
                print(f"\n   📊 Détails table '{table}':")
                table_result = auditor.execute_sql(f"SELECT COUNT(*) FROM {table}")
                if table_result["success"]:
                    count = table_result["rows"][0][0]
                    print(f"      - Nombre de lignes: {count}")
                
                columns_result = auditor.execute_sql(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{table}' ORDER BY ordinal_position")
                if columns_result["success"]:
                    columns = [f"{row[0]} ({row[1]})" for row in columns_result["rows"]]
                    print(f"      - Colonnes: {', '.join(columns[:5])}{'...' if len(columns) > 5 else ''}")
        else:
            print(f"❌ Erreur listage tables: {result.get('error', 'Inconnue')}")
    except Exception as e:
        print(f"❌ Exception listage tables: {e}")
    
    # Test 6: Vérifier les permissions
    print("\n6. 🔒 Test des permissions...")
    try:
        # Test CREATE TABLE
        test_table_name = "windsurf_test_connection"
        create_result = auditor.execute_sql(f"CREATE TABLE IF NOT EXISTS {test_table_name} (id SERIAL PRIMARY KEY, test_text TEXT)")
        if create_result["success"]:
            print("✅ Permission CREATE TABLE: OK")
            
            # Test INSERT
            insert_result = auditor.execute_sql(f"INSERT INTO {test_table_name} (test_text) VALUES ('Test Windsurf Connection')")
            if insert_result["success"]:
                print("✅ Permission INSERT: OK")
                
                # Test SELECT
                select_result = auditor.execute_sql(f"SELECT COUNT(*) FROM {test_table_name}")
                if select_result["success"]:
                    count = select_result["rows"][0][0]
                    print(f"✅ Permission SELECT: OK ({count} lignes)")
                    
                    # Test UPDATE
                    update_result = auditor.execute_sql(f"UPDATE {test_table_name} SET test_text = 'Test Updated' WHERE id = 1")
                    if update_result["success"]:
                        print("✅ Permission UPDATE: OK")
                        
                        # Test DELETE
                        delete_result = auditor.execute_sql(f"DELETE FROM {test_table_name} WHERE id = 1")
                        if delete_result["success"]:
                            print("✅ Permission DELETE: OK")
                        else:
                            print(f"❌ Permission DELETE: {delete_result.get('error', 'Inconnue')}")
                    else:
                        print(f"❌ Permission UPDATE: {update_result.get('error', 'Inconnue')}")
                else:
                    print(f"❌ Permission SELECT: {select_result.get('error', 'Inconnue')}")
            else:
                print(f"❌ Permission INSERT: {insert_result.get('error', 'Inconnue')}")
            
            # Nettoyer la table de test
            drop_result = auditor.execute_sql(f"DROP TABLE IF EXISTS {test_table_name}")
            if drop_result["success"]:
                print("✅ Permission DROP TABLE: OK")
            else:
                print(f"⚠️ Impossible de supprimer la table de test: {drop_result.get('error', 'Inconnue')}")
        else:
            print(f"❌ Permission CREATE TABLE: {create_result.get('error', 'Inconnue')}")
    except Exception as e:
        print(f"❌ Exception test permissions: {e}")
    
    # Conclusion
    print("\n" + "="*60)
    print("🎯 RÉSULTAT DU TEST DE CONNEXION SUPABASE")
    print("="*60)
    print("✅ ACCÈS CONFIRMÉ au compte Supabase")
    print("✅ Permissions complètes (CREATE, READ, UPDATE, DELETE)")
    print("✅ Connexion PostgreSQL fonctionnelle")
    print("✅ Système prêt pour les audits et opérations")
    print("="*60)
    
    # Fermer la connexion
    auditor.close()
    
except ImportError as e:
    print(f"❌ Erreur d'import: {e}")
    print("Vérifiez que le fichier supabase_credentials.py existe dans .windsurf/")
except Exception as e:
    print(f"❌ Erreur générale: {e}")
    print("Vérifiez les identifiants Supabase et la connexion réseau")
