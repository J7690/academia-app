#!/usr/bin/env python3
"""PHASE 1 - Extraire définition SQL complète et dépendances des 8 RPCs"""
from supabase_auto_manager import SupabaseAutoManager
import re

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — EXTRACTION DÉFINITION SQL ET DÉPENDANCES")
    print("="*60 + "\n")
    
    target_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_upsert_assignment',
        'app_prep_teacher_list_submissions',
        'app_prep_teacher_grade_submission',
        'app_prep_teacher_list_live_sessions',
        'app_prep_teacher_upsert_live_session',
        'app_prep_teacher_start_live_session',
        'app_prep_teacher_end_live_session',
    ]
    
    results = []
    
    for rpc_name in target_rpcs:
        print(f"\n{'='*60}")
        print(f"  {rpc_name}")
        print(f"{'='*60}\n")
        
        # Récupérer la définition SQL complète
        sql = f"""
        SELECT pg_get_functiondef(p.oid) AS function_def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            function_def = result['data'][0].get('function_def', '')
            
            print("Définition SQL:")
            print(function_def)
            print()
            
            # Extraire les tables utilisées (pattern: app.table_name)
            tables = re.findall(r'app\.(\w+)', function_def)
            tables = list(set(tables))  # Unique
            
            print(f"Tables utilisées: {', '.join(tables) if tables else 'Aucune'}")
            
            # Extraire les vues utilisées (pattern: app.view_name)
            # Pour l'instant, on considère que tout ce qui n'est pas une table peut être une vue
            # On vérifiera plus tard
            
            # Extraire les fonctions appelées (pattern: app.function_name()
            functions = re.findall(r'app\.(\w+)\s*\(', function_def)
            functions = list(set(functions))  # Unique
            
            print(f"Fonctions appelées: {', '.join(functions) if functions else 'Aucune'}")
            
            # Extraire les schémas utilisés
            schemas = re.findall(r'(\w+)\.\w+', function_def)
            schemas = list(set(schemas))  # Unique
            
            print(f"Schémas utilisés: {', '.join(schemas) if schemas else 'Aucun'}")
            
            results.append({
                'name': rpc_name,
                'function_def': function_def,
                'tables': tables,
                'functions': functions,
                'schemas': schemas
            })
        else:
            print(f"Erreur: {result.get('error')}")
            results.append({
                'name': rpc_name,
                'function_def': None,
                'tables': [],
                'functions': [],
                'schemas': []
            })
    
    # Sauvegarder les résultats pour les phases suivantes
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\prep_teacher_dependencies.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print("\n✅ PHASE 1 terminée. Résultats sauvegardés.\n")

if __name__ == "__main__":
    main()
