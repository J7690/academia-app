#!/usr/bin/env python3
"""Vérifier les colonnes des tables TD et fixer les RPCs si nécessaire."""
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
    print("\n🔍 DIAGNOSTIC — Colonnes tables TD + fix RPCs\n")

    # 1. Colonnes td_questions
    print("═══ td_questions ═══")
    cols = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='td_questions' ORDER BY ordinal_position")
    for c in cols:
        print(f"  {c.get('column_name',''):25s} {c.get('udt_name','')}")

    # 2. Colonnes td_source_documents
    print("\n═══ td_source_documents ═══")
    cols2 = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='td_source_documents' ORDER BY ordinal_position")
    for c in cols2:
        print(f"  {c.get('column_name',''):25s} {c.get('udt_name','')}")

    # 3. Colonnes td_doc_chunks
    print("\n═══ td_doc_chunks ═══")
    cols3 = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='td_doc_chunks' ORDER BY ordinal_position")
    for c in cols3:
        print(f"  {c.get('column_name',''):25s} {c.get('udt_name','')}")

    # 4. Vérifier si les RPCs existent dans pg_proc
    print("\n═══ Vérification pg_proc ═══")
    for rpc in ['app_td_admin_import_questions_json', 'app_td_admin_import_text_bulk']:
        check = q(m,
            f"SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
            f"WHERE p.proname='{rpc}'")
        if check:
            print(f"  ✅ {rpc} dans schema '{check[0].get('nspname','?')}'")
        else:
            print(f"  ❌ {rpc} NON TROUVÉE dans pg_proc")

    # 5. Force reload
    print("\n📦 Force NOTIFY pgrst...")
    deploy(m, "NOTIFY", "NOTIFY pgrst, 'reload schema'")
    time.sleep(3)

    # 6. Re-test API
    print("\n🔍 Re-test API après reload...")
    for rpc in ['app_td_admin_import_questions_json', 'app_td_admin_import_text_bulk']:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json={"p_questions": "[]"} if 'json' in rpc else {"p_text": "test"},
                timeout=10)
            print(f"  {rpc} → {resp.status_code} {resp.text[:100]}")
        except Exception as e:
            print(f"  {rpc} → {str(e)[:60]}")

    print("\n✅ Terminé.\n")

if __name__ == "__main__":
    main()
