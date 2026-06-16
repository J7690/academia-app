#!/usr/bin/env python3
"""PHASE 3 - Exécuter les commandes SQL de migration"""
from supabase_auto_manager import SupabaseAutoManager
import requests

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — EXÉCUTION DE LA MIGRATION SQL")
    print("="*60 + "\n")
    
    # Lire le fichier SQL
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\sql_changes\\change_20260606_move_prep_teacher_rpcs_to_public.sql', 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    print("Contenu du fichier SQL à exécuter:\n")
    print(sql_content)
    print("\n" + "="*60 + "\n")
    
    # Diviser le SQL en commandes individuelles
    commands = []
    for line in sql_content.split('\n'):
        line = line.strip()
        if line and not line.startswith('--'):
            commands.append(line)
    
    print(f"Commandes à exécuter: {len(commands)}\n")
    
    # Essayer d'exécuter via execute_any_sql
    results = []
    
    for i, cmd in enumerate(commands, 1):
        print(f"Commande {i}/{len(commands)}: {cmd[:80]}...")
        
        try:
            r = requests.post(
                f"{m.url}/rest/v1/rpc/execute_any_sql",
                headers=m.headers,
                json={"sql_query": cmd},
                timeout=10
            )
            
            if r.status_code == 200:
                result = r.json()
                if isinstance(result, list) and len(result) > 0:
                    if result[0].get('success'):
                        print(f"  ✓ Succès")
                        results.append({'cmd': cmd, 'status': 'success', 'error': None})
                    else:
                        print(f"  ✗ Erreur: {result[0].get('error')}")
                        results.append({'cmd': cmd, 'status': 'error', 'error': result[0].get('error')})
                else:
                    print(f"  ✗ Réponse vide")
                    results.append({'cmd': cmd, 'status': 'error', 'error': 'Réponse vide'})
            else:
                print(f"  ✗ Erreur HTTP: {r.status_code}")
                print(f"  {r.text}")
                results.append({'cmd': cmd, 'status': 'error', 'error': f"HTTP {r.status_code}: {r.text}"})
        except Exception as e:
            print(f"  ✗ Exception: {str(e)}")
            results.append({'cmd': cmd, 'status': 'error', 'error': str(e)})
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\migration_execution_results.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print("\n" + "="*60)
    print("  RÉSUMÉ")
    print("="*60 + "\n")
    
    success_count = sum(1 for r in results if r['status'] == 'success')
    error_count = sum(1 for r in results if r['status'] == 'error')
    
    print(f"Succès: {success_count}/{len(results)}")
    print(f"Erreurs: {error_count}/{len(results)}")
    
    if error_count > 0:
        print("\nErreurs détaillées:")
        for r in results:
            if r['status'] == 'error':
                print(f"  - {r['cmd'][:60]}... : {r['error']}")
    
    print("\n✅ PHASE 3 terminée.\n")

if __name__ == "__main__":
    main()
