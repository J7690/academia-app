#!/usr/bin/env python3
"""Lister toutes les RPCs prep existantes."""
import requests
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql", headers=m.headers,
        json={"sql_query": "SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND proname LIKE '%prep%' ORDER BY proname"},
        timeout=30)
    data = r.json() if r.status_code == 200 and isinstance(r.json(), list) else []
    print(f"\n📋 RPCs 'prep' dans schema app: {len(data)}\n")
    for d in data:
        print(f"  {d.get('proname','')}")
    
    # Check Flutter code for which RPC is called
    print("\n📱 RPC appelée dans Flutter (prep_quiz_provider.dart):")
    print("  app_prep_get_quiz_questions ← loadQuestionsFromServer()")
    print("  app_prep_get_adaptive_quiz  ← loadAdaptiveQuestionsFromServer()")

if __name__ == "__main__":
    main()
