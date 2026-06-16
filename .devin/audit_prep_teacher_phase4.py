#!/usr/bin/env python3
"""PHASE 4 - Test d'exécution contrôlé (lecture seule)"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 4 — TEST D'EXÉCUTION CONTRÔLÉ")
    print("="*60 + "\n")
    
    # Tester l'exécution via execute_sql (accès direct au schéma app)
    target_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_list_live_sessions',
    ]
    
    print("TEST D'EXÉCUTION VIA SCHÉMA APP (execute_sql):\n")
    print(f"{'RPC':<40} {'Résultat':<20} {'Erreur':<40}")
    print("-" * 100)
    
    for rpc_name in target_rpcs:
        # Essayer d'exécuter la RPC via execute_sql
        sql = f"SELECT app.{rpc_name}() as result"
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success'):
            data = result.get('data', [])
            if data:
                print(f"{rpc_name:<40} {'SUCCÈS':<20} {str(data[0])[:40]}")
            else:
                print(f"{rpc_name:<40} {'VIDE':<20} {'Aucune donnée retournée'}")
        else:
            error = result.get('error', '')[:40]
            print(f"{rpc_name:<40} {'ERREUR':<20} {error}")
    
    print("\n" + "="*60)
    print("  TEST D'EXÉCUTION VIA POSTGREST (REST API)")
    print("="*60 + "\n")
    
    print(f"{'RPC':<40} {'HTTP Status':<15} {'Erreur':<40}")
    print("-" * 95)
    
    import requests
    
    for rpc_name in target_rpcs:
        try:
            r = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc_name}",
                headers=m.headers,
                json={},
                timeout=10
            )
            
            if r.status_code == 200:
                print(f"{rpc_name:<40} {'200 OK':<15} {'-'}")
            elif r.status_code == 404:
                print(f"{rpc_name:<40} {'404 NOT FOUND':<15} {'RPC non trouvée par PostgREST'}")
            elif r.status_code == 401:
                print(f"{rpc_name:<40} {'401 UNAUTHORIZED':<15} {'Authentification requise'}")
            else:
                print(f"{rpc_name:<40} {f'{r.status_code}':<15} {r.text[:40]}")
        except Exception as e:
            print(f"{rpc_name:<40} {'EXCEPTION':<15} {str(e)[:40]}")
    
    print("\n" + "="*60)
    print("  TEST D'EXÉCUTION VIA SCHÉMA PUBLIC (COMPARAISON)")
    print("="*60 + "\n")
    
    # Comparer avec app_td_teacher_get_dashboard (qui fonctionne)
    td_rpc = 'app_td_teacher_get_dashboard'
    
    print(f"Test de {td_rpc} (référence TD):\n")
    
    # Via execute_sql
    sql_td = f"SELECT public.{td_rpc}() as result"
    result_td = m.execute_sql_auto(sql_td)
    
    if result_td.get('success'):
        print(f"  Via execute_sql: SUCCÈS")
    else:
        print(f"  Via execute_sql: ERREUR - {result_td.get('error')}")
    
    # Via PostgREST
    try:
        r_td = requests.post(
            f"{m.url}/rest/v1/rpc/{td_rpc}",
            headers=m.headers,
            json={},
            timeout=10
        )
        print(f"  Via PostgREST: {r_td.status_code} {r_td.reason}")
    except Exception as e:
        print(f"  Via PostgREST: EXCEPTION - {str(e)}")
    
    print("\n✅ PHASE 4 terminée.\n")

if __name__ == "__main__":
    main()
