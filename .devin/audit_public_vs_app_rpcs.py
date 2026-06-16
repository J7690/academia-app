#!/usr/bin/env python3
"""Audit: comparer RPCs public vs app et vérifier les corps."""
import requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
        return data if isinstance(data, list) else []
    except:
        return []

def section(t): print(f"\n{'='*60}\n  {t}\n{'='*60}")

def main():
    m = SupabaseAutoManager()
    print("\n🔍 AUDIT — Public vs App schema RPCs\n")

    # 1. Corps de app_prep_get_quiz_questions (PUBLIC)
    section("1. app_prep_get_quiz_questions (PUBLIC) — Corps")
    body = q(m,
        "SELECT prosrc, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname='app_prep_get_quiz_questions'")
    if body:
        print(f"  Args: {body[0].get('args','')}")
        print(f"\n  Corps:\n{body[0].get('prosrc','')[:3000]}")
    else:
        print("  ❌ Non trouvée dans public")

    # 2. app_prep_get_adaptive_quiz — vérifier dans quel schema
    section("2. app_prep_get_adaptive_quiz — Quel schema?")
    for schema in ['public', 'app']:
        check = q(m,
            f"SELECT n.nspname, pg_get_function_arguments(p.oid) AS args "
            f"FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
            f"WHERE n.nspname='{schema}' AND p.proname='app_prep_get_adaptive_quiz'")
        if check:
            print(f"  ✅ Trouvée dans '{schema}' — Args: {check[0].get('args','')[:100]}")
        else:
            print(f"  ❌ Absente du schema '{schema}'")

    # 3. app_prep_get_weakness_analysis — vérifier
    section("3. app_prep_get_weakness_analysis — Quel schema?")
    for schema in ['public', 'app']:
        check = q(m,
            f"SELECT n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
            f"WHERE n.nspname='{schema}' AND p.proname='app_prep_get_weakness_analysis'")
        if check:
            print(f"  ✅ Trouvée dans '{schema}'")
        else:
            print(f"  ❌ Absente du schema '{schema}'")

    # 4. app_prep_save_quiz_attempt — vérifier
    section("4. app_prep_save_quiz_attempt — Quel schema?")
    for schema in ['public', 'app']:
        check = q(m,
            f"SELECT n.nspname, pg_get_function_arguments(p.oid) AS args "
            f"FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
            f"WHERE n.nspname='{schema}' AND p.proname='app_prep_save_quiz_attempt'")
        if check:
            print(f"  ✅ Trouvée dans '{schema}' — Args: {check[0].get('args','')[:100]}")
        else:
            print(f"  ❌ Absente du schema '{schema}'")

    # 5. Lister TOUTES les RPCs public qui commencent par app_prep
    section("5. TOUTES les RPCs 'app_prep' dans PUBLIC")
    pub = q(m,
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname LIKE 'app_prep%' ORDER BY p.proname")
    for r in pub:
        print(f"  {r.get('proname','')}")

    # 6. Tester l'accessibilité REST des RPCs cruciales
    section("6. Test API REST des RPCs cruciales")
    critical_rpcs = [
        ('app_prep_get_quiz_questions', {}),
        ('app_prep_get_adaptive_quiz', {'p_count': 5}),
        ('app_prep_get_weakness_analysis', {}),
        ('app_prep_get_my_subject_stats', {}),
        ('app_prep_list_published_questions', {}),
        ('app_prep_create_attempt', {}),
    ]
    for rpc_name, params in critical_rpcs:
        try:
            resp = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc_name}",
                headers=m.headers,
                json=params,
                timeout=10
            )
            status = resp.status_code
            snippet = resp.text[:80] if status != 200 else "OK"
            icon = "✅" if status == 200 else "❌"
            print(f"  {icon} {rpc_name} → {status} {snippet}")
        except Exception as e:
            print(f"  ❌ {rpc_name} → {str(e)[:60]}")

    print("\n✅ Audit terminé.\n")

if __name__ == "__main__":
    main()
