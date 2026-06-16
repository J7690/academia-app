#!/usr/bin/env python3
"""Déployer le trigger de mise à jour automatique des faiblesses."""
from __future__ import annotations
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    print("\n🔧 DÉPLOIEMENT TRIGGER ADAPTATIF\n")
    
    # Créer le trigger
    trigger_sql = """
DROP TRIGGER IF EXISTS trg_update_student_weaknesses ON app.prep_quiz_attempts;

CREATE TRIGGER trg_update_student_weaknesses
    AFTER INSERT OR UPDATE ON app.prep_quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION app.update_student_weaknesses_from_attempt();
    """
    
    print("📦 Création du trigger trg_update_student_weaknesses...")
    
    try:
        response = requests.post(
            f"{m.url}/rest/v1/rpc/execute_ddl",
            headers=m.headers,
            json={"ddl_query": trigger_sql},
            timeout=30
        )
        
        if response.status_code == 200:
            print("   ✅ Trigger créé avec succès!")
            
            # Vérifier que le trigger existe
            check_sql = """
            SELECT EXISTS(
                SELECT 1 FROM pg_trigger t 
                JOIN pg_class c ON c.oid=t.tgrelid 
                JOIN pg_namespace n ON n.oid=c.relnamespace 
                WHERE n.nspname='app' 
                AND c.relname='prep_quiz_attempts' 
                AND t.tgname='trg_update_student_weaknesses'
            ) AS trigger_exists
            """
            
            print("\n🔍 Vérification du trigger...")
            check_response = requests.post(
                f"{m.url}/rest/v1/rpc/execute_sql",
                headers=m.headers,
                json={"sql_query": check_sql},
                timeout=30
            )
            
            if check_response.status_code == 200:
                result = check_response.json()
                if result and result[0].get('trigger_exists'):
                    print("   ✅ Trigger vérifié et actif!")
                else:
                    print("   ⚠️  Trigger créé mais non trouvé dans pg_trigger")
            
        else:
            print(f"   ❌ Erreur: {response.text[:200]}")
            
    except Exception as e:
        print(f"   ❌ Exception: {str(e)[:200]}")
    
    print("\n✅ Déploiement trigger terminé.\n")

if __name__ == "__main__":
    main()
