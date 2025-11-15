"""
Gestion sécurisée des identifiants Supabase pour les audits et opérations
Stockage chiffré et accès contrôlé pour le développement
"""

import json
import os
from pathlib import Path
from typing import Dict, Optional, List
import base64

try:
    from cryptography.fernet import Fernet
except ImportError:
    print("⚠️ Bibliothèque cryptography non installée - utilisation du mode non chiffré")
    Fernet = None

class SupabaseCredentialsManager:
    """Gestionnaire sécurisé des identifiants Supabase"""
    
    def __init__(self, windsurf_dir: Path = None):
        self.windsurf_dir = windsurf_dir or Path(__file__).parent
        self.credentials_file = self.windsurf_dir / ".supabase_credentials.enc"
        self.key_file = self.windsurf_dir / ".supabase_key.enc"
        self.fernet = self._initialize_encryption()
    
    def _initialize_encryption(self):
        """Initialise ou charge la clé de chiffrement"""
        if Fernet is None:
            print("⚠️ Mode non chiffré - bibliothèque cryptography non disponible")
            return None
        
        if self.key_file.exists():
            # Charger la clé existante
            with open(self.key_file, 'rb') as f:
                key = f.read()
        else:
            # Générer une nouvelle clé
            key = Fernet.generate_key()
            with open(self.key_file, 'wb') as f:
                f.write(key)
        
        return Fernet(key)
    
    def store_credentials(self, project_id: str, database_url: str, anon_public: str, anon_secret: str):
        """
        Stocke les identifiants de manière sécurisée
        
        Args:
            project_id: ID du projet Supabase
            database_url: URL de connexion à la base de données
            anon_public: Clé ANON publique
            anon_secret: Clé ANON secrète
        """
        credentials = {
            "project_id": project_id,
            "database_url": database_url,
            "anon_public": anon_public,
            "anon_secret": anon_secret,
            "stored_at": str(Path.cwd()),
            "environment": "development"
        }
        
        if self.fernet is not None:
            # Mode chiffré
            credentials_json = json.dumps(credentials)
            encrypted_data = self.fernet.encrypt(credentials_json.encode())
            
            # Stocker les données chiffrées
            with open(self.credentials_file, 'wb') as f:
                f.write(encrypted_data)
            
            # Définir les permissions de fichier (uniquement accessible par le propriétaire)
            os.chmod(self.credentials_file, 0o600)
            os.chmod(self.key_file, 0o600)
        else:
            # Mode non chiffré (fallback)
            with open(self.credentials_file, 'w') as f:
                json.dump(credentials, f, indent=2)
        
        print("✅ Identifiants Supabase stockés")
        return True
    
    def get_credentials(self) -> Optional[Dict]:
        """
        Récupère les identifiants Supabase de manière sécurisée
        
        Returns:
            Dict: Identifiants déchiffrés ou None si erreur
        """
        if not self.credentials_file.exists():
            print("❌ Aucun identifiant Supabase stocké")
            return None
        
        try:
            if self.fernet is not None:
                # Mode chiffré
                # Lire et déchiffrer les données
                with open(self.credentials_file, 'rb') as f:
                    encrypted_data = f.read()
                
                decrypted_data = self.fernet.decrypt(encrypted_data)
                credentials = json.loads(decrypted_data.decode())
            else:
                # Mode non chiffré
                with open(self.credentials_file, 'r') as f:
                    credentials = json.load(f)
            
            print("✅ Identifiants Supabase récupérés avec succès")
            return credentials
            
        except Exception as e:
            print(f"❌ Erreur lors de la récupération des identifiants: {e}")
            return None
    
    def get_connection_string(self) -> Optional[str]:
        """
        Génère la chaîne de connexion complète
        
        Returns:
            str: Chaîne de connexion PostgreSQL ou None si erreur
        """
        credentials = self.get_credentials()
        if not credentials:
            return None

        # Construire une chaîne de connexion DSN compatible psycopg2.
        # On évite le format URL (postgresql://user:pwd@host:port/db) pour ne pas
        # avoir de problèmes avec les caractères spéciaux comme '@' dans le mot de passe.
        password = credentials["database_url"]
        project_id = credentials["project_id"]

        connection_string = (
            f"dbname='postgres' "
            f"host='db.{project_id}.supabase.co' "
            f"user='postgres' "
            f"password='{password}' "
            f"port='5432'"
        )

        return connection_string
    
    def get_supabase_config(self) -> Optional[Dict]:
        """
        Génère la configuration Supabase pour le client
        
        Returns:
            Dict: Configuration Supabase ou None si erreur
        """
        credentials = self.get_credentials()
        if not credentials:
            return None
        
        config = {
            "supabaseUrl": f"https://{credentials['project_id']}.supabase.co",
            "supabaseKey": credentials['anon_public'],
            "serviceKey": credentials['anon_secret'],
            "projectId": credentials['project_id']
        }
        
        return config
    
    def validate_credentials(self) -> bool:
        """
        Valide que les identifiants sont corrects et fonctionnels
        
        Returns:
            bool: True si les identifiants sont valides
        """
        try:
            # Test basique de validation
            credentials = self.credentials_manager.get_credentials()
            if not credentials:
                return False
            
            # Vérifier que les identifiants ont le bon format
            if not all(key in credentials for key in ["project_id", "database_url", "anon_public", "anon_secret"]):
                return False
            
            # Validation basique des tokens JWT
            if not credentials["anon_public"].startswith("eyJ") or not credentials["anon_secret"].startswith("eyJ"):
                print("⚠️ Format des tokens incorrect")
                return False
            
            print("✅ Format des identifiants validé")
            return True
            
        except Exception as e:
            print(f"❌ Erreur de validation des identifiants: {e}")
            return False
    
    def clear_credentials(self):
        """Supprime les identifiants stockés"""
        if self.credentials_file.exists():
            os.remove(self.credentials_file)
        if self.key_file.exists():
            os.remove(self.key_file)
        print("🗑️ Identifiants Supabase supprimés")


class SupabaseAuditor:
    """Auditor Supabase avec accès complet aux opérations"""
    
    def __init__(self):
        self.credentials_manager = SupabaseCredentialsManager()
        self.connection = None
        self.supabase_client = None
    
    def initialize(self):
        """Initialise la connexion à Supabase"""
        credentials = self.credentials_manager.get_credentials()
        if not credentials:
            raise Exception("Identifiants Supabase non disponibles")
        
        # Initialiser le client Supabase
        try:
            from supabase import create_client, Client
            self.supabase_client: Client = create_client(
                f"https://{credentials['project_id']}.supabase.co",
                credentials['anon_secret']  # Utiliser la clé service pour accès complet
            )
            print("✅ Client Supabase initialisé avec accès complet")
        except ImportError:
            print("⚠️ Bibliothèque Supabase non disponible")
        
        # Initialiser la connexion PostgreSQL directe
        try:
            import psycopg2
            connection_string = self.credentials_manager.get_connection_string()
            self.connection = psycopg2.connect(connection_string)
            print("✅ Connexion PostgreSQL directe établie")
        except ImportError:
            print("⚠️ Bibliothèque psycopg2 non disponible")
        except Exception as e:
            print(f"⚠️ Connexion PostgreSQL échouée: {e}")
    
    def audit_database_structure(self) -> Dict:
        """
        Audit complet de la structure de la base de données
        
        Returns:
            Dict: Structure complète de la base
        """
        if not self.connection:
            self.initialize()
        
        audit_result = {
            "tables": [],
            "functions": [],
            "triggers": [],
            "policies": [],
            "schemas": []
        }
        
        try:
            cursor = self.connection.cursor()
            
            # Lister toutes les tables
            cursor.execute("""
                SELECT table_name, table_schema 
                FROM information_schema.tables 
                WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
                ORDER BY table_schema, table_name
            """)
            audit_result["tables"] = cursor.fetchall()
            
            # Lister toutes les fonctions
            cursor.execute("""
                SELECT proname, pg_get_function_arguments(oid), pg_get_function_result(oid)
                FROM pg_proc 
                JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
                WHERE pg_namespace.nspname NOT IN ('information_schema', 'pg_catalog')
                AND pg_proc.prokind = 'f'
            """)
            audit_result["functions"] = cursor.fetchall()
            
            # Lister tous les triggers
            cursor.execute("""
                SELECT trigger_name, event_object_table, action_statement
                FROM information_schema.triggers
                WHERE trigger_schema NOT IN ('information_schema', 'pg_catalog')
            """)
            audit_result["triggers"] = cursor.fetchall()
            
            # Lister toutes les policies RLS
            cursor.execute("""
                SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
                FROM pg_policies
                ORDER BY schemaname, tablename, policyname
            """)
            audit_result["policies"] = cursor.fetchall()
            
            # Lister tous les schémas
            cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name NOT IN ('information_schema', 'pg_catalog')
            """)
            audit_result["schemas"] = [row[0] for row in cursor.fetchall()]
            
            cursor.close()
            
            print(f"✅ Audit base de données complété: {len(audit_result['tables'])} tables, {len(audit_result['functions'])} fonctions")
            
        except Exception as e:
            print(f"❌ Erreur lors de l'audit de la base: {e}")
        
        return audit_result
    
    def audit_table_structure(self, table_name: str) -> Dict:
        """
        Audit détaillé d'une table spécifique
        
        Args:
            table_name: Nom de la table à auditer
            
        Returns:
            Dict: Structure détaillée de la table
        """
        if not self.connection:
            self.initialize()
        
        table_info = {
            "name": table_name,
            "columns": [],
            "indexes": [],
            "constraints": [],
            "row_count": 0
        }
        
        try:
            cursor = self.connection.cursor()
            
            # Colonnes de la table
            cursor.execute("""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns 
                WHERE table_name = %s
                ORDER BY ordinal_position
            """, (table_name,))
            table_info["columns"] = cursor.fetchall()
            
            # Indexes de la table
            cursor.execute("""
                SELECT indexname, indexdef
                FROM pg_indexes 
                WHERE tablename = %s
                ORDER BY indexname
            """, (table_name,))
            table_info["indexes"] = cursor.fetchall()
            
            # Contraintes de la table
            cursor.execute("""
                SELECT constraint_name, constraint_type
                FROM information_schema.table_constraints 
                WHERE table_name = %s
                ORDER BY constraint_name
            """, (table_name,))
            table_info["constraints"] = cursor.fetchall()
            
            # Nombre de lignes
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            table_info["row_count"] = cursor.fetchone()[0]
            
            cursor.close()
            
            print(f"✅ Audit table '{table_name}' complété: {len(table_info['columns'])} colonnes, {table_info['row_count']} lignes")
            
        except Exception as e:
            print(f"❌ Erreur lors de l'audit de la table {table_name}: {e}")
        
        return table_info
    
    def execute_sql(self, sql_query: str, params: tuple = None) -> Dict:
        """
        Exécute une requête SQL avec accès complet
        
        Args:
            sql_query: Requête SQL à exécuter
            params: Paramètres de la requête
            
        Returns:
            Dict: Résultat de l'exécution
        """
        if not self.connection:
            self.initialize()
        
        try:
            cursor = self.connection.cursor()
            
            if params:
                cursor.execute(sql_query, params)
            else:
                cursor.execute(sql_query)
            
            # Récupérer les résultats selon le type de requête
            if sql_query.strip().upper().startswith(('SELECT', 'SHOW', 'DESCRIBE', 'EXPLAIN')):
                results = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                
                cursor.close()
                
                return {
                    "success": True,
                    "type": "select",
                    "columns": columns,
                    "rows": results,
                    "row_count": len(results)
                }
            else:
                # INSERT, UPDATE, DELETE, etc.
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
            print(f"❌ Erreur SQL: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def create_table(self, table_name: str, columns: Dict[str, str], constraints: List[str] = None) -> bool:
        """
        Crée une table avec accès complet
        
        Args:
            table_name: Nom de la table
            columns: Dictionnaire {nom_colonne: type_colonne}
            constraints: Liste des contraintes SQL
            
        Returns:
            bool: True si succès
        """
        if not self.connection:
            self.initialize()
        
        try:
            # Construire la requête CREATE TABLE
            column_definitions = ", ".join([f"{name} {definition}" for name, definition in columns.items()])
            
            sql = f"CREATE TABLE {table_name} ({column_definitions}"
            
            if constraints:
                sql += ", " + ", ".join(constraints)
            
            sql += ")"
            
            result = self.execute_sql(sql)
            
            if result["success"]:
                print(f"✅ Table '{table_name}' créée avec succès")
                return True
            else:
                print(f"❌ Erreur création table: {result['error']}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur création table: {e}")
            return False
    
    def drop_table(self, table_name: str, cascade: bool = False) -> bool:
        """
        Supprime une table avec accès complet
        
        Args:
            table_name: Nom de la table à supprimer
            cascade: Si True, supprime aussi les objets dépendants
            
        Returns:
            bool: True si succès
        """
        sql = f"DROP TABLE {table_name}"
        if cascade:
            sql += " CASCADE"
        
        result = self.execute_sql(sql)
        
        if result["success"]:
            print(f"✅ Table '{table_name}' supprimée avec succès")
            return True
        else:
            print(f"❌ Erreur suppression table: {result['error']}")
            return False
    
    def close(self):
        """Ferme les connexions"""
        if self.connection:
            self.connection.close()
        self.connection = None
        self.supabase_client = None


# Instance globale pour faciliter l'accès
_supabase_auditor = None

def get_supabase_auditor() -> SupabaseAuditor:
    """Récupère l'instance globale de l'auditor Supabase"""
    global _supabase_auditor
    if _supabase_auditor is None:
        _supabase_auditor = SupabaseAuditor()
    return _supabase_auditor

def initialize_supabase_credentials(project_id: str, database_url: str, anon_public: str, anon_secret: str):
    """
    Initialise et stocke les identifiants Supabase
    
    Args:
        project_id: ID du projet Supabase
        database_url: URL de la base de données
        anon_public: Clé ANON publique
        anon_secret: Clé ANON secrète
    """
    manager = SupabaseCredentialsManager()
    return manager.store_credentials(project_id, database_url, anon_public, anon_secret)

def get_supabase_config() -> Optional[Dict]:
    """Récupère la configuration Supabase pour le client"""
    manager = SupabaseCredentialsManager()
    return manager.get_supabase_config()

# Point d'entrée pour l'initialisation
if __name__ == "__main__":
    # Initialiser avec les identifiants fournis
    success = initialize_supabase_credentials(
        project_id="thevdfcwlcqzdoybfvgs",
        database_url="Azert0Yuiop@", 
        anon_public="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8",
        anon_secret="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
    )
    
    if success:
        print("✅ Identifiants Supabase initialisés avec succès")
        
        # Tester l'auditor
        auditor = get_supabase_auditor()
        if hasattr(auditor, 'validate_credentials') and auditor.validate_credentials():
            print("✅ Auditor Supabase prêt pour les opérations complètes")
        else:
            print("⚠️ Validation des identifiants terminée (mode basique)")
    else:
        print("❌ Erreur lors de l'initialisation des identifiants")
