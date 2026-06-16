#!/usr/bin/env python3
"""PHASE 2 - Contrôle PostgREST (list_assignments, list_live_sessions)"""
from supabase_auto_manager import SupabaseAutoManager
import requests

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — CONTRÔLE POSTGREST")
    print("="*60 + "\n")
    
    test_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_list_live_sessions',
    ]
    
    postgrest_results = []
    
    for rpc_name in test_rpcs:
        print(f"{rpc_name}:")
        
        try:
            r = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc_name}",
                headers=m.headers,
                json={},
                timeout=10
            )
            
            print(f"  HTTP Status: {r.status_code}")
            print(f"  Réponse: {r.text[:200]}")
            
            postgrest_results.append({
                'name': rpc_name,
                'status': r.status_code,
                'response': r.text
            })
        except Exception as e:
            print(f"  Exception: {str(e)}")
            postgrest_results.append({
                'name': rpc_name,
                'status': 'ERROR',
                'response': str(e)
            })
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\post_migration_postgrest.json', 'w', encoding='utf-8') as f:
        json.dump(postgrest_results, f, indent=2, ensure_ascii=False)
    
    print("\n✅ PHASE 2 terminée.\n")

if __name__ == "__main__":
    main()
