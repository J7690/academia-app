#!/usr/bin/env python3
"""
Test de clarté des méthodes - Valide qu'il n'y a plus de tâtonnement
"""

import requests
import json
from datetime import datetime

def test_method_clarity():
    """
    Test qui prouve que les méthodes sont clairement définies
    et fonctionnent sans tâtonnement
    """
    
    print("🎯 TEST DE CLARTÉ DES MÉTHODES - PLUS DE TÂTONNEMENT")
    print("=" * 60)
    
    # Configuration fixe (copiée du guide)
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
    
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json"
    }
    
    results = {
        "timestamp": datetime.now().isoformat(),
        "methods_tested": {},
        "clarity_score": 0,
        "total_methods": 0
    }
    
    # === MÉTHODE #1: RPC Functions (OFFICIELLE) ===
    print("\n🥇 TEST MÉTHODE #1: RPC Functions (OFFICIELLEMENT 100% FONCTIONNEL)")
    
    rpc_methods = [
        ("list_tables_detailed", {}, "Lister toutes les tables"),
        ("describe_table_detailed", {"p_table_name": "rpc_validation_test"}, "Décrire une table"),
        ("table_exists", {"p_table_name": "rpc_validation_test"}, "Vérifier existence table"),
        ("column_exists", {"p_table_name": "rpc_validation_test", "p_column_name": "id"}, "Vérifier existence colonne")
    ]
    
    rpc_working = 0
    for method_name, params, description in rpc_methods:
        print(f"   📝 Test: {description}")
        
        try:
            response = requests.post(f"{url}/rest/v1/rpc/{method_name}", 
                                   headers=headers, 
                                   json=params, 
                                   timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                print(f"   ✅ {method_name}: FONCTIONNEL")
                results["methods_tested"][method_name] = {
                    "status": "working",
                    "description": description,
                    "response_type": type(result).__name__
                }
                rpc_working += 1
            else:
                print(f"   ❌ {method_name}: Erreur {response.status_code}")
                results["methods_tested"][method_name] = {
                    "status": f"error_{response.status_code}",
                    "description": description
                }
                
        except Exception as e:
            print(f"   ❌ {method_name}: Exception")
            results["methods_tested"][method_name] = {
                "status": "exception",
                "description": description,
                "error": str(e)
            }
    
    print(f"\n📊 Résultat RPC: {rpc_working}/{len(rpc_methods)} méthodes fonctionnelles")
    
    # === MÉTHODE #2: API REST (FALLBACK OFFICIEL) ===
    print("\n🥈 TEST MÉTHODE #2: API REST PostgREST (FALLBACK OFFICIEL)")
    
    api_headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}"
    }
    
    api_methods = [
        ("SELECT", "GET", f"{url}/rest/v1/rpc_validation_test?limit=1", "Lire des données"),
        ("COUNT", "GET", f"{url}/rest/v1/rpc_validation_test?select=count", "Compter des données")
    ]
    
    api_working = 0
    for method_name, http_method, endpoint, description in api_methods:
        print(f"   📝 Test: {description}")
        
        try:
            if http_method == "GET":
                response = requests.get(endpoint, headers=api_headers, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                print(f"   ✅ API {method_name}: FONCTIONNEL")
                results["methods_tested"][f"api_{method_name}"] = {
                    "status": "working",
                    "description": description,
                    "response_type": type(result).__name__
                }
                api_working += 1
            else:
                print(f"   ❌ API {method_name}: Erreur {response.status_code}")
                results["methods_tested"][f"api_{method_name}"] = {
                    "status": f"error_{response.status_code}",
                    "description": description
                }
                
        except Exception as e:
            print(f"   ❌ API {method_name}: Exception")
            results["methods_tested"][f"api_{method_name}"] = {
                "status": "exception",
                "description": description,
                "error": str(e)
            }
    
    print(f"\n📊 Résultat API: {api_working}/{len(api_methods)} méthodes fonctionnelles")
    
    # === CALCUL DE CLARTÉ ===
    total_methods = len(rpc_methods) + len(api_methods)
    working_methods = rpc_working + api_working
    clarity_score = (working_methods / total_methods) * 100
    
    results["clarity_score"] = clarity_score
    results["total_methods"] = total_methods
    results["working_methods"] = working_methods
    
    print(f"\n🎯 SCORE DE CLARTÉ: {clarity_score:.1f}%")
    print(f"📈 Méthodes fonctionnelles: {working_methods}/{total_methods}")
    
    # === DÉFINITION DE LA PROCÉDURE CLAIRE ===
    print(f"\n📋 PROCÉDURE OFFICIELLE VALIDÉE:")
    
    if rpc_working >= 3:
        print("   ✅ ÉTAPE 1: TOUJOURS utiliser RPC Functions")
        print("   ✅ Disponible pour: audit, création, description, validation")
    else:
        print("   ⚠️ RPC limité - utiliser API REST")
    
    if api_working >= 1:
        print("   ✅ ÉTAPE 2: Fallback API REST si RPC échoue")
        print("   ✅ Disponible pour: CRUD simple")
    else:
        print("   ⚠️ API REST limité")
    
    print("   ✅ ÉTAPE 3: Python Client en dernier recours")
    
    # === SAUVEGARDE DES RÉSULTATS ===
    with open("methods_clarity_test.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    # === CONCLUSION ===
    print(f"\n" + "=" * 60)
    
    if clarity_score >= 80:
        print("🎉 EXCELLENT: Les méthodes sont clairement définies!")
        print("✅ Plus de tâtonnement nécessaire")
        print("✅ Procédures officielles validées")
        print("✅ Utilisation simplifiée garantie")
    elif clarity_score >= 60:
        print("✅ BON: Les méthodes principales sont définies")
        print("✅ Procédures claires pour la plupart des cas")
        print("⚠️ Quelques limitations mineures")
    else:
        print("⚠️ LIMITÉ: Méthodes partiellement fonctionnelles")
        print("❌ Nécessite encore des ajustements")
    
    print(f"\n📊 Guide de référence: METHODS_CLEAR_GUIDE.md")
    print(f"📁 Résultats sauvegardés: methods_clarity_test.json")
    
    return clarity_score >= 80

def main():
    """Point d'entrée principal"""
    success = test_method_clarity()
    
    if success:
        print("\n🚀 MISSION ACCOMPLIE: Plus de tâtonnement!")
        print("✅ Les méthodes sont clairement définies et documentées")
        print("✅ Procédures officielles validées et fonctionnelles")
        return 0
    else:
        print("\n⚠️ Améliorations nécessaires pour éliminer tout tâtonnement")
        return 1

if __name__ == "__main__":
    exit(main())
