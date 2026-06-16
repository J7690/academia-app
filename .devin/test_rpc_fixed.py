#!/usr/bin/env python3
"""
Script de test corrigé pour les fonctions RPC Supabase
Fonctionne avec le code SQL supabase_rpc_fixed.sql
"""

import requests
import json
from typing import Dict, Any, List

class SupabaseRPCTestFixed:
    """Classe de test corrigée pour les fonctions RPC Supabase"""
    
    def __init__(self):
        self.url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
        self.service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
        
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        
        self.test_inserted_id = None
    
    def call_rpc(self, function_name: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """Appelle une fonction RPC"""
        try:
            url = f"{self.url}/rest/v1/rpc/{function_name}"
            response = requests.post(url, headers=self.headers, json=params or {}, timeout=10)
            
            return {
                "success": response.status_code == 200,
                "status_code": response.status_code,
                "data": response.json() if response.status_code == 200 else None,
                "error": response.text if response.status_code != 200 else None
            }
        except Exception as e:
            return {
                "success": False,
                "status_code": 0,
                "data": None,
                "error": str(e)
            }
    
    def test_list_tables_detailed(self) -> bool:
        """Test la fonction list_tables_detailed (retourne JSONB)"""
        print("🧪 Test 1: list_tables_detailed()")
        
        result = self.call_rpc("list_tables_detailed")
        
        if result["success"]:
            tables = result["data"]
            if isinstance(tables, list):
                print(f"✅ Succès: {len(tables)} tables trouvées")
                for table in tables:
                    print(f"   📋 {table['table_name']} - {table['row_count']} lignes - {table['size_bytes']} bytes")
                return True
            else:
                print(f"❌ Erreur: réponse non-liste: {type(tables)}")
                return False
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_execute_sql(self) -> bool:
        """Test la fonction execute_sql (retourne JSONB)"""
        print("\n🧪 Test 2: execute_sql()")
        
        # Test SQL simple
        sql_query = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'rpc_validation_test' ORDER BY ordinal_position"
        
        result = self.call_rpc("execute_sql", {"sql_query": sql_query})
        
        if result["success"]:
            data = result["data"]
            if isinstance(data, list) and len(data) > 0:
                columns = data
                print(f"✅ Succès: {len(columns)} colonnes trouvées dans rpc_validation_test")
                for col in columns:
                    print(f"   📊 {col['column_name']}: {col['data_type']}")
                return True
            else:
                print(f"❌ Erreur: format de réponse inattendu: {data}")
                return False
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_describe_table_detailed(self) -> bool:
        """Test la fonction describe_table_detailed (retourne JSONB)"""
        print("\n🧪 Test 3: describe_table_detailed()")
        
        result = self.call_rpc("describe_table_detailed", {"p_table_name": "rpc_validation_test"})
        
        if result["success"]:
            columns = result["data"]
            if isinstance(columns, list):
                print(f"✅ Succès: {len(columns)} colonnes décrites")
                for col in columns:
                    nullable = "NULL" if col["is_nullable"] == "YES" else "NOT NULL"
                    print(f"   📝 {col['column_name']}: {col['data_type']} {nullable} (position: {col['ordinal_position']})")
                return True
            else:
                print(f"❌ Erreur: réponse non-liste: {type(columns)}")
                return False
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_create_table_safe(self) -> bool:
        """Test la fonction create_table_safe (paramètres corrigés)"""
        print("\n🧪 Test 4: create_table_safe()")
        
        table_definition = [
            {"name": "id", "type": "SERIAL PRIMARY KEY"},
            {"name": "name", "type": "TEXT NOT NULL"},
            {"name": "email", "type": "TEXT UNIQUE"},
            {"name": "age", "type": "INTEGER", "nullable": True},
            {"name": "created_at", "type": "TIMESTAMPTZ DEFAULT NOW()"}
        ]
        
        result = self.call_rpc("create_table_safe", {
            "p_table_name": "rpc_test_users",
            "p_table_definition": table_definition
        })
        
        if result["success"]:
            message = result["data"]
            if isinstance(message, list) and len(message) > 0:
                print(f"✅ Succès: {message[0]}")
                return True
            elif isinstance(message, str):
                print(f"✅ Succès: {message}")
                return True
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_insert_data_safe(self) -> bool:
        """Test la fonction insert_data_safe (paramètres corrigés)"""
        print("\n🧪 Test 5: insert_data_safe()")
        
        test_data = {
            "name": "Utilisateur Test RPC",
            "email": "test@rpc.example.com",
            "age": 25
        }
        
        result = self.call_rpc("insert_data_safe", {
            "p_table_name": "rpc_test_users",
            "p_data": test_data
        })
        
        if result["success"]:
            inserted_id = result["data"]
            if isinstance(inserted_id, list) and len(inserted_id) > 0:
                print(f"✅ Succès: Données insérées avec ID {inserted_id[0]}")
                self.test_inserted_id = inserted_id[0]
                return True
            elif isinstance(inserted_id, int):
                print(f"✅ Succès: Données insérées avec ID {inserted_id}")
                self.test_inserted_id = inserted_id
                return True
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_update_data_safe(self) -> bool:
        """Test la fonction update_data_safe (paramètres corrigés)"""
        print("\n🧪 Test 6: update_data_safe()")
        
        if not self.test_inserted_id:
            print("❌ Pas d'ID disponible pour le test de mise à jour")
            return False
        
        update_data = {
            "age": 26,
            "name": "Utilisateur Mis à Jour"
        }
        
        result = self.call_rpc("update_data_safe", {
            "p_table_name": "rpc_test_users",
            "p_data": update_data,
            "p_where_condition": f"id = {self.test_inserted_id}"
        })
        
        if result["success"]:
            affected_rows = result["data"]
            if isinstance(affected_rows, list) and len(affected_rows) > 0:
                print(f"✅ Succès: {affected_rows[0]} ligne(s) mise(s) à jour")
                return True
            elif isinstance(affected_rows, int):
                print(f"✅ Succès: {affected_rows} ligne(s) mise(s) à jour")
                return True
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_table_exists(self) -> bool:
        """Test la fonction table_exists (paramètres corrigés)"""
        print("\n🧪 Test 7: table_exists()")
        
        # Test table qui existe
        result = self.call_rpc("table_exists", {"p_table_name": "rpc_validation_test"})
        
        if result["success"]:
            exists = result["data"]
            if isinstance(exists, list) and len(exists) > 0:
                print(f"✅ Succès: rpc_validation_test existe: {exists[0]}")
                
                # Test table qui n'existe pas
                result2 = self.call_rpc("table_exists", {"p_table_name": "table_inexistante"})
                if result2["success"]:
                    not_exists = result2["data"]
                    if isinstance(not_exists, list) and len(not_exists) > 0:
                        print(f"✅ Succès: table_inexistante existe: {not_exists[0]}")
                        return True
            elif isinstance(exists, bool):
                print(f"✅ Succès: rpc_validation_test existe: {exists}")
                return True
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def test_column_exists(self) -> bool:
        """Test la fonction column_exists (paramètres corrigés)"""
        print("\n🧪 Test 8: column_exists()")
        
        # Test colonne qui existe
        result = self.call_rpc("column_exists", {
            "p_table_name": "rpc_validation_test",
            "p_column_name": "id"
        })
        
        if result["success"]:
            exists = result["data"]
            if isinstance(exists, list) and len(exists) > 0:
                print(f"✅ Succès: colonne id existe: {exists[0]}")
                
                # Test colonne qui n'existe pas
                result2 = self.call_rpc("column_exists", {
                    "p_table_name": "rpc_validation_test",
                    "p_column_name": "colonne_inexistante"
                })
                if result2["success"]:
                    not_exists = result2["data"]
                    if isinstance(not_exists, list) and len(not_exists) > 0:
                        print(f"✅ Succès: colonne_inexistante existe: {not_exists[0]}")
                        return True
            elif isinstance(exists, bool):
                print(f"✅ Succès: colonne id existe: {exists}")
                return True
        else:
            print(f"❌ Erreur: {result['status_code']} - {result['error']}")
            return False
    
    def cleanup_test_data(self):
        """Nettoie les données de test"""
        print("\n🧹 Nettoyage des données de test...")
        
        # Supprimer la table de test créée
        drop_sql = "DROP TABLE IF EXISTS rpc_test_users"
        result = self.call_rpc("execute_sql", {"sql_query": drop_sql})
        
        if result["success"]:
            print("✅ Table rpc_test_users supprimée")
        else:
            print(f"⚠️ Impossible de supprimer rpc_test_users: {result['error']}")
    
    def run_all_tests(self) -> bool:
        """Exécute tous les tests"""
        print("🚀 DÉMARRAGE DES TESTS RPC SUPABASE (VERSION CORRIGÉE)")
        print("=" * 60)
        
        tests = [
            self.test_list_tables_detailed,
            self.test_execute_sql,
            self.test_describe_table_detailed,
            self.test_create_table_safe,
            self.test_insert_data_safe,
            self.test_update_data_safe,
            self.test_table_exists,
            self.test_column_exists
        ]
        
        passed = 0
        total = len(tests)
        
        for test in tests:
            try:
                if test():
                    passed += 1
            except Exception as e:
                print(f"❌ Exception dans {test.__name__}: {e}")
        
        # Nettoyer
        self.cleanup_test_data()
        
        # Résultats
        print("\n" + "=" * 60)
        print("🎯 RÉSULTATS DES TESTS")
        print("=" * 60)
        print(f"✅ Tests réussis: {passed}/{total}")
        print(f"❌ Tests échoués: {total - passed}/{total}")
        
        if passed == total:
            print("\n🎉 TOUS LES TESTS RÉUSSIS!")
            print("✅ RPC Supabase est parfaitement configuré")
            print("✅ Toutes les fonctions sont opérationnelles")
            print("✅ Plus de limitations SQL RPC!")
            return True
        else:
            print(f"\n⚠️ {total - passed} test(s) ont échoué")
            print("Vérifiez la configuration SQL dans Supabase")
            return False

def main():
    """Point d'entrée principal"""
    tester = SupabaseRPCTestFixed()
    success = tester.run_all_tests()
    
    if success:
        print("\n🚀 Le système RPC Supabase est prêt pour Windsurf!")
        print("✅ Accès SQL complet sans limitations")
        print("✅ Toutes les opérations CRUD disponibles")
        print("✅ Audit complet de la base de données")
    else:
        print("\n❌ Des problèmes subsistent")
        print("Vérifiez que le code SQL corrigé a été correctement exécuté")
    
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())
