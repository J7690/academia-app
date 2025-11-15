"""
Intégration Supabase avec le système de règles Windsurf
Connecte l'auditor Supabase au workflow d'audit et validation
"""

from .supabase_credentials import get_supabase_auditor, initialize_supabase_credentials, get_supabase_config
from typing import Dict, List, Optional
import json

class SupabaseIntegration:
    """Intégration Supabase avec le système Windsurf"""
    
    def __init__(self):
        self.auditor = get_supabase_auditor()
        self.initialized = False
        self.project_info = None
    
    def initialize_integration(self):
        """Initialise l'intégration Supabase"""
        try:
            # Initialiser l'auditor
            self.auditor.initialize()
            
            # Récupérer les informations du projet
            config = get_supabase_config()
            if config:
                self.project_info = {
                    "project_id": config["projectId"],
                    "url": config["supabaseUrl"],
                    "environment": "development"
                }
            
            self.initialized = True
            print("✅ Intégration Supabase initialisée avec succès")
            return True
            
        except Exception as e:
            print(f"❌ Erreur initialisation intégration Supabase: {e}")
            return False
    
    def perform_supabase_audit(self) -> Dict:
        """
        Effectue l'audit complet Supabase selon les règles Windsurf
        
        Returns:
            Dict: Résultats complets de l'audit
        """
        if not self.initialized:
            if not self.initialize_integration():
                return {"error": "Impossible d'initialiser l'intégration Supabase"}
        
        audit_results = {
            "project_info": self.project_info,
            "database_structure": {},
            "table_details": {},
            "security_audit": {},
            "performance_indicators": {},
            "recommendations": []
        }
        
        try:
            # 1. Audit de la structure de base
            print("🔍 Audit de la structure de la base de données...")
            audit_results["database_structure"] = self.auditor.audit_database_structure()
            
            # 2. Audit détaillé des tables
            print("🔍 Audit détaillé des tables...")
            tables = [table[0] for table in audit_results["database_structure"]["tables"]]
            for table_name in tables:
                audit_results["table_details"][table_name] = self.auditor.audit_table_structure(table_name)
            
            # 3. Audit de sécurité
            print("🔍 Audit de sécurité...")
            audit_results["security_audit"] = self._perform_security_audit(audit_results["database_structure"])
            
            # 4. Indicateurs de performance
            print("🔍 Analyse des indicateurs de performance...")
            audit_results["performance_indicators"] = self._analyze_performance_indicators(audit_results["table_details"])
            
            # 5. Générer les recommandations
            audit_results["recommendations"] = self._generate_recommendations(audit_results)
            
            print("✅ Audit Supabase complété selon les règles Windsurf")
            
        except Exception as e:
            print(f"❌ Erreur lors de l'audit Supabase: {e}")
            audit_results["error"] = str(e)
        
        return audit_results
    
    def _perform_security_audit(self, db_structure: Dict) -> Dict:
        """Effectue l'audit de sécurité"""
        security_audit = {
            "rls_policies": [],
            "public_tables": [],
            "sensitive_columns": [],
            "security_score": 0
        }
        
        try:
            # Analyser les policies RLS
            policies = db_structure.get("policies", [])
            for policy in policies:
                schema, table, policy_name = policy[0], policy[1], policy[2]
                security_audit["rls_policies"].append({
                    "schema": schema,
                    "table": table,
                    "policy": policy_name
                })
            
            # Identifier les tables publiques (sans RLS)
            tables_with_rls = set([policy[1] for policy in policies])
            all_tables = [table[0] for table in db_structure.get("tables", [])]
            security_audit["public_tables"] = [table for table in all_tables if table not in tables_with_rls]
            
            # Calculer le score de sécurité
            total_tables = len(all_tables)
            protected_tables = len(tables_with_rls)
            if total_tables > 0:
                security_audit["security_score"] = (protected_tables / total_tables) * 100
            
        except Exception as e:
            print(f"⚠️ Erreur audit sécurité: {e}")
        
        return security_audit
    
    def _analyze_performance_indicators(self, table_details: Dict) -> Dict:
        """Analyse les indicateurs de performance"""
        performance = {
            "large_tables": [],
            "tables_without_indexes": [],
            "total_rows": 0,
            "recommendations": []
        }
        
        try:
            total_rows = 0
            
            for table_name, details in table_details.items():
                row_count = details.get("row_count", 0)
                indexes = details.get("indexes", [])
                
                total_rows += row_count
                
                # Identifier les grandes tables (>10k lignes)
                if row_count > 10000:
                    performance["large_tables"].append({
                        "name": table_name,
                        "rows": row_count
                    })
                
                # Identifier les tables sans index (sauf tables très petites)
                if row_count > 1000 and len(indexes) == 0:
                    performance["tables_without_indexes"].append(table_name)
            
            performance["total_rows"] = total_rows
            
            # Recommandations de performance
            if performance["large_tables"]:
                performance["recommendations"].append("Considérer l'optimisation des grandes tables")
            if performance["tables_without_indexes"]:
                performance["recommendations"].append("Ajouter des index sur les tables fréquemment interrogées")
            
        except Exception as e:
            print(f"⚠️ Erreur analyse performance: {e}")
        
        return performance
    
    def _generate_recommendations(self, audit_results: Dict) -> List[str]:
        """Génère les recommandations basées sur l'audit"""
        recommendations = []
        
        try:
            # Recommandations de sécurité
            security = audit_results.get("security_audit", {})
            if security.get("security_score", 0) < 80:
                recommendations.append("🔒 Améliorer la sécurité en activant RLS sur plus de tables")
            
            public_tables = security.get("public_tables", [])
            if public_tables:
                recommendations.append(f"🔒 Protéger les tables publiques: {', '.join(public_tables)}")
            
            # Recommandations de performance
            performance = audit_results.get("performance_indicators", {})
            perf_recs = performance.get("recommendations", [])
            recommendations.extend(perf_recs)
            
            # Recommandations de structure
            db_structure = audit_results.get("database_structure", {})
            if len(db_structure.get("functions", [])) == 0:
                recommendations.append("⚡ Considérer l'ajout de fonctions SQL pour la logique métier")
            
        except Exception as e:
            print(f"⚠️ Erreur génération recommandations: {e}")
        
        return recommendations
    
    def validate_table_exists(self, table_name: str) -> bool:
        """
        Valide l'existence d'une table (règle: pas de déduction)
        
        Args:
            table_name: Nom de la table à vérifier
            
        Returns:
            bool: True si la table existe
        """
        if not self.initialized:
            self.initialize_integration()
        
        try:
            result = self.auditor.execute_sql(
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = %s)",
                (table_name,)
            )
            
            if result["success"] and result["rows"]:
                exists = result["rows"][0][0]
                print(f"🔍 Table '{table_name}': {'✅ existe' if exists else '❌ n\'existe pas'}")
                return exists
            else:
                print(f"❌ Erreur vérification table '{table_name}'")
                return False
                
        except Exception as e:
            print(f"❌ Erreur validation table '{table_name}': {e}")
            return False
    
    def validate_function_exists(self, function_name: str) -> bool:
        """
        Valide l'existence d'une fonction
        
        Args:
            function_name: Nom de la fonction à vérifier
            
        Returns:
            bool: True si la fonction existe
        """
        if not self.initialized:
            self.initialize_integration()
        
        try:
            result = self.auditor.execute_sql(
                "SELECT EXISTS (SELECT FROM pg_proc WHERE proname = %s)",
                (function_name,)
            )
            
            if result["success"] and result["rows"]:
                exists = result["rows"][0][0]
                print(f"🔍 Fonction '{function_name}': {'✅ existe' if exists else '❌ n\'existe pas'}")
                return exists
            else:
                print(f"❌ Erreur vérification fonction '{function_name}'")
                return False
                
        except Exception as e:
            print(f"❌ Erreur validation fonction '{function_name}': {e}")
            return False
    
    def validate_column_exists(self, table_name: str, column_name: str) -> bool:
        """
        Valide l'existence d'une colonne dans une table
        
        Args:
            table_name: Nom de la table
            column_name: Nom de la colonne
            
        Returns:
            bool: True si la colonne existe
        """
        if not self.initialized:
            self.initialize_integration()
        
        try:
            result = self.auditor.execute_sql(
                """
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = %s AND column_name = %s
                )
                """,
                (table_name, column_name)
            )
            
            if result["success"] and result["rows"]:
                exists = result["rows"][0][0]
                print(f"🔍 Colonne '{column_name}' dans table '{table_name}': {'✅ existe' if exists else '❌ n\'existe pas'}")
                return exists
            else:
                print(f"❌ Erreur vérification colonne '{column_name}' dans '{table_name}'")
                return False
                
        except Exception as e:
            print(f"❌ Erreur validation colonne '{column_name}': {e}")
            return False
    
    def create_table_if_not_exists(self, table_name: str, columns: Dict[str, str], constraints: List[str] = None) -> Dict:
        """
        Crée une table si elle n'existe pas (avec validation)
        
        Args:
            table_name: Nom de la table
            columns: Dictionnaire {nom_colonne: type_colonne}
            constraints: Liste des contraintes
            
        Returns:
            Dict: Résultat de l'opération
        """
        # Validation d'abord (règle: pas de déduction)
        if self.validate_table_exists(table_name):
            return {
                "success": False,
                "message": f"La table '{table_name}' existe déjà",
                "action": "none"
            }
        
        # Créer la table
        success = self.auditor.create_table(table_name, columns, constraints)
        
        return {
            "success": success,
            "message": f"Table '{table_name}' {'créée avec succès' if success else 'échec de création'}",
            "action": "created" if success else "failed"
        }
    
    def get_table_schema(self, table_name: str) -> Optional[Dict]:
        """
        Récupère le schéma complet d'une table
        
        Args:
            table_name: Nom de la table
            
        Returns:
            Dict: Schéma de la table ou None si erreur
        """
        if not self.validate_table_exists(table_name):
            return None
        
        return self.auditor.audit_table_structure(table_name)
    
    def close_integration(self):
        """Ferme l'intégration Supabase"""
        if self.auditor:
            self.auditor.close()
        self.initialized = False


# Instance globale pour l'intégration
_supabase_integration = None

def get_supabase_integration() -> SupabaseIntegration:
    """Récupère l'instance globale de l'intégration Supabase"""
    global _supabase_integration
    if _supabase_integration is None:
        _supabase_integration = SupabaseIntegration()
    return _supabase_integration

# Point d'entrée pour l'initialisation automatique
def initialize_supabase_integration():
    """Initialise l'intégration Supabase avec les identifiants stockés"""
    integration = get_supabase_integration()
    return integration.initialize_integration()

if __name__ == "__main__":
    # Test de l'intégration
    print("🚀 Test de l'intégration Supabase...")
    
    if initialize_supabase_integration():
        integration = get_supabase_integration()
        
        # Test d'audit
        audit_results = integration.perform_supabase_audit()
        print(f"✅ Audit terminé: {len(audit_results.get('table_details', {}))} tables analysées")
        
        # Test de validation
        test_table = "users"
        exists = integration.validate_table_exists(test_table)
        print(f"🔍 Validation table '{test_table}': {exists}")
        
        integration.close_integration()
    else:
        print("❌ Échec de l'initialisation de l'intégration")
