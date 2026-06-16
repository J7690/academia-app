#!/usr/bin/env python3
"""Vérifier que les RPCs sont bien accessibles (400 = accessible mais auth.uid() NULL, 404 = pas exposée)."""
import requests
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    print("\n🔍 VÉRIFICATION ACCESSIBILITÉ RPCs\n")
    
    rpcs_to_check = [
        'app_prep_get_quiz_questions',
        'app_prep_get_adaptive_quiz',
        'app_prep_get_weakness_analysis',
        'app_prep_get_my_subject_stats',
        'app_prep_sync_student_progress',
        'app_prep_list_published_questions',
        'app_prep_list_subjects',
        'app_prep_get_student_progress',
    ]
    
    for rpc in rpcs_to_check:
        try:
            resp = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers,
                json={},
                timeout=10
            )
            code = resp.status_code
            if code == 200:
                print(f"  ✅ {rpc} → 200 OK (fonctionne)")
            elif code == 400:
                # 400 = accessible mais erreur de paramètre ou auth.uid() null
                msg = resp.text[:100]
                print(f"  ✅ {rpc} → 400 ACCESSIBLE (erreur auth attendue: {msg})")
            elif code == 404:
                print(f"  ❌ {rpc} → 404 NON EXPOSÉE")
            else:
                print(f"  ⚠️  {rpc} → {code}")
        except Exception as e:
            print(f"  ❌ {rpc} → {str(e)[:60]}")

    # Vérifier aussi les RPCs app schema qui sont 404
    print("\n📋 RPCs schema 'app' uniquement (non exposées):")
    app_only = requests.post(
        f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers,
        json={"sql_query": 
            "SELECT a.proname FROM pg_proc a "
            "JOIN pg_namespace na ON na.oid = a.pronamespace "
            "WHERE na.nspname = 'app' AND a.proname LIKE 'app_prep%' "
            "AND NOT EXISTS ("
            "  SELECT 1 FROM pg_proc p "
            "  JOIN pg_namespace np ON np.oid = p.pronamespace "
            "  WHERE np.nspname = 'public' AND p.proname = a.proname"
            ") ORDER BY a.proname"
        },
        timeout=30
    )
    if app_only.status_code == 200:
        data = app_only.json()
        if isinstance(data, list):
            for d in data:
                print(f"  ⚠️  {d.get('proname','')} (app only, pas dans public)")
    
    print("\n✅ Vérification terminée.\n")

if __name__ == "__main__":
    main()
