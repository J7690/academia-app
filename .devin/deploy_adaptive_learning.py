#!/usr/bin/env python3
"""Déployer le système d'apprentissage adaptatif."""
from __future__ import annotations
import os
import time
from supabase_auto_manager import SupabaseAutoManager

def split_sql_respecting_dollar_quotes(sql_content):
    """Split SQL en respectant les blocs $$."""
    statements = []
    current = []
    in_dollar = False
    lines = sql_content.split('\n')
    
    for line in lines:
        stripped = line.strip()
        if '$$' in line:
            in_dollar = not in_dollar
        
        current.append(line)
        
        if not in_dollar and stripped.endswith(';') and not stripped.startswith('--'):
            stmt = '\n'.join(current).strip()
            if stmt and not stmt.startswith('--'):
                statements.append(stmt)
            current = []
    
    if current:
        stmt = '\n'.join(current).strip()
        if stmt and not stmt.startswith('--'):
            statements.append(stmt)
    
    return statements

def main():
    m = SupabaseAutoManager()
    print("\n🚀 DÉPLOIEMENT SYSTÈME ADAPTATIF - Prépa Concours\n")
    
    # Lire le fichier SQL
    sql_file = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\sql_changes\20260325_adaptive_learning_system.sql"
    
    if not os.path.exists(sql_file):
        print(f"❌ Fichier SQL non trouvé: {sql_file}")
        return
    
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    # Splitter en statements
    statements = split_sql_respecting_dollar_quotes(sql_content)
    print(f"📋 {len(statements)} statements SQL à exécuter\n")
    
    success_count = 0
    error_count = 0
    
    import requests
    
    for i, stmt in enumerate(statements, 1):
        # Afficher un aperçu du statement
        preview = stmt.split('\n')[0][:80] + '...' if len(stmt) > 80 else stmt.split('\n')[0]
        print(f"[{i}/{len(statements)}] {preview}")
        
        try:
            # Déterminer le type de requête
            if any(kw in stmt.upper() for kw in ['CREATE', 'ALTER', 'DROP', 'GRANT', 'COMMENT']):
                # DDL - utiliser execute_ddl
                response = requests.post(
                    f"{m.url}/rest/v1/rpc/execute_ddl",
                    headers=m.headers,
                    json={"ddl_query": stmt},
                    timeout=30
                )
            else:
                # DML/SELECT - utiliser execute_sql
                response = requests.post(
                    f"{m.url}/rest/v1/rpc/execute_sql",
                    headers=m.headers,
                    json={"sql_query": stmt},
                    timeout=30
                )
            
            if response.status_code == 200:
                print(f"    ✅ Succès")
                success_count += 1
            else:
                error_msg = response.text
                if 'already exists' in error_msg:
                    print(f"    ⚠️  Existe déjà (ignoré)")
                    success_count += 1
                else:
                    print(f"    ❌ Erreur: {error_msg[:100]}")
                    error_count += 1
            
            # Pause courte entre les statements
            time.sleep(0.1)
            
        except Exception as e:
            error_msg = str(e)
            if 'already exists' in error_msg:
                print(f"    ⚠️  Existe déjà (ignoré)")
                success_count += 1
            else:
                print(f"    ❌ Erreur: {error_msg[:100]}")
                error_count += 1
    
    print("\n" + "="*60)
    print(f"RÉSUMÉ: {success_count} succès, {error_count} erreurs")
    print("="*60)
    
    if error_count == 0:
        print("\n✅ Déploiement réussi!")
        print("\n🎯 Système adaptatif déployé avec:")
        print("   - Table prep_student_weaknesses")
        print("   - Trigger automatique de mise à jour")
        print("   - RPC app_prep_get_adaptive_quiz")
        print("   - RPC app_prep_get_weakness_analysis")
    else:
        print("\n⚠️  Déploiement partiel - vérifier les erreurs")

if __name__ == "__main__":
    main()
