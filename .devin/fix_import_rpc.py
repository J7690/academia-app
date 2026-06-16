#!/usr/bin/env python3
"""Diagnostiquer et fixer la RPC import_questions_json."""
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
        return data if isinstance(data, list) else []
    except:
        return []

def deploy(m, name, sql):
    print(f"📦 {name}...")
    try:
        r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
            headers=m.headers, json={"ddl_query": sql}, timeout=30)
        if r.status_code == 200:
            print(f"   ✅ OK")
            return True
        else:
            print(f"   ❌ {r.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🔧 FIX — RPC import_questions_json\n")

    # 1. Vérifier si elle existe
    check = q(m,
        "SELECT n.nspname, p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE p.proname LIKE '%import_questions%' ORDER BY n.nspname")
    print("Existantes:")
    for c in check:
        print(f"  [{c.get('nspname','')}] {c.get('proname','')} ({c.get('args','')[:80]})")

    # 2. Le problème peut être que PostgREST ne reload pas le cache.
    # Forcer un reload en appelant notify
    print("\n📦 Forcer reload PostgREST schema cache...")
    deploy(m, "NOTIFY pgrst", "NOTIFY pgrst, 'reload schema'")
    time.sleep(2)

    # 3. Re-tester
    print("\n🔍 Re-test API...")
    resp = requests.post(f"{m.url}/rest/v1/rpc/app_admin_prep_import_questions_json",
        headers=m.headers, json={"p_questions": "[]"}, timeout=10)
    print(f"  app_admin_prep_import_questions_json → {resp.status_code}")
    if resp.status_code != 200:
        print(f"  Body: {resp.text[:200]}")

    # 4. Tester aussi app_admin_prep_import_text_bulk
    resp2 = requests.post(f"{m.url}/rest/v1/rpc/app_admin_prep_import_text_bulk",
        headers=m.headers, json={"p_text": "test"}, timeout=10)
    print(f"  app_admin_prep_import_text_bulk → {resp2.status_code}")
    if resp2.status_code != 200:
        print(f"  Body: {resp2.text[:200]}")

    print("\n✅ Terminé.\n")

if __name__ == "__main__":
    main()
