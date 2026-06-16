#!/usr/bin/env python3
"""
Test d'accès complet PostgreSQL direct à Supabase
Solution immédiate sans limitations RPC
"""

import psycopg2
from psycopg2.extras import RealDictCursor

def test_full_supabase_access():
    """Test l'accès complet à Supabase via PostgreSQL direct"""
    
    print("🔌 Test de connexion PostgreSQL directe...")
    
    # Configuration de connexion directe
    connection_params = {
        "host": "db.thevdfcwlcqzdoybfvgs.supabase.co",
        "port": 5432,
        "database": "postgres",
        "user": "postgres",
        "password": "Azert0Yuiop@",
        "sslmode": "require"
    }
    
    try:
        # Connexion directe
        conn = psycopg2.connect(**connection_params)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        print("✅ Connexion PostgreSQL établie")
        
        # Test 1: Version PostgreSQL
        cursor.execute("SELECT version()")
        result = cursor.fetchone()
        print(f"📊 Version: {result['version'][:60]}...")
        
        # Test 2: Lister les schémas
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog')
            ORDER BY schema_name
        """)
        schemas = cursor.fetchall()
        print(f"📂 Schémas: {[s['schema_name'] for s in schemas]}")
        
        # Test 3: Lister les tables
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        tables = cursor.fetchall()
        print(f"📋 Tables trouvées ({len(tables)}): {[t['table_name'] for t in tables]}")
        
        # Test 4: Créer une table de test
        print("\n🔧 Test des permissions complètes...")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS windsurf_full_access_test (
                id SERIAL PRIMARY KEY,
                test_data TEXT NOT NULL,
                test_number INTEGER,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        print("✅ CREATE TABLE: OK")
        
        # Test 5: Insérer des données
        cursor.execute("""
            INSERT INTO windsurf_full_access_test (test_data, test_number) 
            VALUES (%s, %s)
        """, ("Test accès complet Supabase", 42))
        print("✅ INSERT: OK")
        
        # Test 6: Lire les données
        cursor.execute("""
            SELECT * FROM windsurf_full_access_test 
            ORDER BY id DESC LIMIT 5
        """)
        data = cursor.fetchall()
        print(f"✅ SELECT: {len(data)} enregistrements")
        for record in data:
            print(f"   - ID: {record['id']}, Data: {record['test_data']}, Number: {record['test_number']}")
        
        # Test 7: Mettre à jour
        cursor.execute("""
            UPDATE windsurf_full_access_test 
            SET test_data = %s, test_number = %s 
            WHERE id = %s
        """, ("Données mises à jour", 99, data[0]['id']))
        print("✅ UPDATE: OK")
        
        # Test 8: Vérifier la mise à jour
        cursor.execute("SELECT * FROM windsurf_full_access_test WHERE id = %s", (data[0]['id'],))
        updated = cursor.fetchone()
        print(f"✅ Vérification UPDATE: {updated['test_data']}, {updated['test_number']}")
        
        # Test 9: Supprimer
        cursor.execute("DELETE FROM windsurf_full_access_test WHERE id = %s", (data[0]['id'],))
        print("✅ DELETE: OK")
        
        # Test 10: Créer des fonctions SQL
        cursor.execute("""
            CREATE OR REPLACE FUNCTION test_function()
            RETURNS TEXT
            LANGUAGE plpgsql
            AS $$
            BEGIN
                RETURN 'Fonction créée avec succès';
            END;
            $$;
        """)
        print("✅ CREATE FUNCTION: OK")
        
        # Test 11: Exécuter la fonction
        cursor.execute("SELECT test_function()")
        func_result = cursor.fetchone()
        print(f"✅ EXECUTE FUNCTION: {func_result['test_function']}")
        
        # Test 12: Créer des vues
        cursor.execute("""
            CREATE OR REPLACE VIEW test_view AS
            SELECT 'Test vue' as message, NOW() as created_at;
        """)
        print("✅ CREATE VIEW: OK")
        
        # Test 13: Interroger la vue
        cursor.execute("SELECT * FROM test_view")
        view_result = cursor.fetchone()
        print(f"✅ SELECT FROM VIEW: {view_result['message']}")
        
        # Nettoyer
        print("\n🧹 Nettoyage...")
        cursor.execute("DROP VIEW IF EXISTS test_view")
        cursor.execute("DROP FUNCTION IF EXISTS test_function()")
        cursor.execute("DROP TABLE IF EXISTS windsurf_full_access_test")
        print("✅ Nettoyage terminé")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print("\n" + "="*60)
        print("🎯 RÉSULTAT: ACCÈS COMPLET SUPABASE CONFIRMÉ")
        print("="*60)
        print("✅ PostgreSQL direct: FONCTIONNEL")
        print("✅ CREATE: Tables, fonctions, vues")
        print("✅ READ: Requêtes SELECT complexes")
        print("✅ UPDATE: Modifications de données")
        print("✅ DELETE: Suppressions sécurisées")
        print("✅ ADMIN: DDL complet, fonctions, vues")
        print("✅ PAS DE LIMITATIONS RPC")
        print("="*60)
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur de connexion: {e}")
        return False

def create_enhanced_supabase_manager():
    """Crée un gestionnaire Supabase amélioré avec accès complet"""
    
    manager_code = '''
#!/usr/bin/env python3
"""
Gestionnaire Supabase avec accès PostgreSQL direct
Remplacement du système RPC limité
"""

import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Optional, Any
import json

class EnhancedSupabaseManager:
    """Gestionnaire Supabase avec accès complet PostgreSQL"""
    
    def __init__(self):
        self.connection_params = {
            "host": "db.thevdfcwlcqzdoybfvgs.supabase.co",
            "port": 5432,
            "database": "postgres",
            "user": "postgres",
            "password": "Azert0Yuiop@",
            "sslmode": "require"
        }
        self.connection = None
    
    def connect(self):
        """Établit la connexion PostgreSQL"""
        try:
            self.connection = psycopg2.connect(**self.connection_params)
            return True
        except Exception as e:
            print(f"❌ Erreur connexion: {e}")
            return False
    
    def execute_sql(self, query: str, params: tuple = None) -> Dict[str, Any]:
        """Exécute du SQL avec retour structuré"""
        if not self.connection:
            if not self.connect():
                return {"success": False, "error": "Connexion échouée"}
        
        try:
            cursor = self.connection.cursor(cursor_factory=RealDictCursor)
            
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            
            # Déterminer le type de requête
            query_upper = query.strip().upper()
            
            if query_upper.startswith(('SELECT', 'SHOW', 'DESCRIBE', 'EXPLAIN')):
                results = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                
                cursor.close()
                
                return {
                    "success": True,
                    "type": "select",
                    "columns": columns,
                    "rows": [dict(row) for row in results],
                    "row_count": len(results)
                }
            else:
                # INSERT, UPDATE, DELETE, DDL
                affected_rows = cursor.rowcount
                self.connection.commit()
                cursor.close()
                
                return {
                    "success": True,
                    "type": "modification",
                    "affected_rows": affected_rows
                }
                
        except Exception as e:
            if self.connection:
                self.connection.rollback()
            return {"success": False, "error": str(e)}
    
    def list_tables(self) -> List[str]:
        """Liste toutes les tables"""
        result = self.execute_sql("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        
        if result["success"]:
            return [row["table_name"] for row in result["rows"]]
        return []
    
    def describe_table(self, table_name: str) -> Dict:
        """Décrit une table en détail"""
        result = self.execute_sql("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))
        
        if result["success"]:
            return {
                "table_name": table_name,
                "columns": result["rows"],
                "column_count": len(result["rows"])
            }
        return {"error": "Table non trouvée"}
    
    def create_table(self, table_name: str, columns: Dict[str, str]) -> bool:
        """Crée une table dynamiquement"""
        column_defs = ", ".join([f"{name} {definition}" for name, definition in columns.items()])
        query = f"CREATE TABLE {table_name} ({column_defs})"
        
        result = self.execute_sql(query)
        return result["success"]
    
    def table_exists(self, table_name: str) -> bool:
        """Vérifie si une table existe"""
        result = self.execute_sql("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = %s
            )
        """, (table_name,))
        
        if result["success"] and result["rows"]:
            return result["rows"][0]["exists"]
        return False
    
    def get_row_count(self, table_name: str) -> int:
        """Compte les lignes d'une table"""
        result = self.execute_sql(f"SELECT COUNT(*) as count FROM {table_name}")
        
        if result["success"] and result["rows"]:
            return result["rows"][0]["count"]
        return 0
    
    def close(self):
        """Ferme la connexion"""
        if self.connection:
            self.connection.close()
            self.connection = None

# Point d'entrée global
_enhanced_manager = None

def get_enhanced_supabase_manager() -> EnhancedSupabaseManager:
    """Récupère l'instance du gestionnaire amélioré"""
    global _enhanced_manager
    if _enhanced_manager is None:
        _enhanced_manager = EnhancedSupabaseManager()
    return _enhanced_manager

# Test
if __name__ == "__main__":
    manager = get_enhanced_supabase_manager()
    
    if manager.connect():
        print("✅ Gestionnaire Supabase amélioré connecté")
        
        # Test des fonctionnalités
        tables = manager.list_tables()
        print(f"📋 Tables: {tables}")
        
        if tables:
            first_table = tables[0]
            description = manager.describe_table(first_table)
            print(f"📊 Description {first_table}: {description['column_count']} colonnes")
        
        manager.close()
    else:
        print("❌ Échec de connexion")
'''
    
    # Sauvegarder le gestionnaire amélioré
    manager_path = Path(__file__).parent / "enhanced_supabase_manager.py"
    with open(manager_path, 'w', encoding='utf-8') as f:
        f.write(manager_code)
    
    print(f"✅ Gestionnaire amélioré créé: {manager_path}")
    return manager_path

if __name__ == "__main__":
    # Tester l'accès complet
    if test_full_supabase_access():
        # Créer le gestionnaire amélioré
        manager_path = create_enhanced_supabase_manager()
        print(f"\n🚀 Solution complète prête: {manager_path}")
    else:
        print("\n❌ La connexion PostgreSQL directe a échoué")
        print("Vérifiez:")
        print("- Identifiants corrects")
        print("- Connexion internet active")
        print("- Firewall ne bloquant pas le port 5432")
