#!/usr/bin/env python3
"""Audit approfondi: toutes les RPCs prep, leurs paramètres, et corps des RPCs quiz/questions."""
import requests
import json
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
    print("\n🔍 AUDIT APPROFONDI — RPCs Prépa Concours\n")

    # ═══════════════════════════════════════════════════════════════
    # 1. TOUTES les RPCs prep dans TOUS les schemas
    # ═══════════════════════════════════════════════════════════════
    section("1. TOUTES les RPCs 'prep' (tous schemas)")
    all_rpcs = q(m,
        "SELECT n.nspname AS schema, p.proname AS name, "
        "pg_get_function_arguments(p.oid) AS args, "
        "pg_get_function_result(p.oid) AS returns "
        "FROM pg_proc p "
        "JOIN pg_namespace n ON n.oid = p.pronamespace "
        "WHERE p.proname LIKE '%prep%' "
        "AND n.nspname NOT IN ('pg_catalog', 'information_schema') "
        "ORDER BY n.nspname, p.proname")
    
    print(f"  Total: {len(all_rpcs)} RPCs\n")
    for r in all_rpcs:
        print(f"  [{r.get('schema','?')}] {r.get('name','?')}")
        print(f"    Args: {r.get('args','')[:80]}")
        print(f"    Returns: {r.get('returns','')[:50]}")

    # ═══════════════════════════════════════════════════════════════
    # 2. RPCs qui contiennent 'quiz' ou 'question' dans le nom
    # ═══════════════════════════════════════════════════════════════
    section("2. RPCs contenant 'quiz' ou 'question'")
    quiz_rpcs = q(m,
        "SELECT n.nspname AS schema, p.proname AS name, "
        "pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p "
        "JOIN pg_namespace n ON n.oid = p.pronamespace "
        "WHERE (p.proname LIKE '%quiz%' OR p.proname LIKE '%question%') "
        "AND n.nspname NOT IN ('pg_catalog', 'information_schema') "
        "ORDER BY p.proname")
    
    for r in quiz_rpcs:
        print(f"  [{r.get('schema','?')}] {r.get('name','?')}")
        print(f"    Args: {r.get('args','')}")

    # ═══════════════════════════════════════════════════════════════
    # 3. Corps de app_prep_list_questions (candidat potentiel)
    # ═══════════════════════════════════════════════════════════════
    section("3. Corps de app_prep_list_questions")
    body = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_list_questions'")
    if body:
        code = body[0].get('prosrc', '')
        print(code[:2000])
    else:
        print("  ❌ Non trouvée")

    # ═══════════════════════════════════════════════════════════════
    # 4. Corps de app_prep_get_subject_stats
    # ═══════════════════════════════════════════════════════════════
    section("4. Corps de app_prep_get_subject_stats")
    body2 = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_get_subject_stats'")
    if body2:
        code = body2[0].get('prosrc', '')
        print(code[:2000])
    else:
        print("  ❌ Non trouvée")

    # ═══════════════════════════════════════════════════════════════
    # 5. Corps de app_prep_save_quiz_attempt
    # ═══════════════════════════════════════════════════════════════
    section("5. Corps de app_prep_save_quiz_attempt")
    body3 = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_save_quiz_attempt'")
    if body3:
        code = body3[0].get('prosrc', '')
        print(code[:2000])
    else:
        print("  ❌ Non trouvée")

    # ═══════════════════════════════════════════════════════════════
    # 6. RPCs admin pour insérer/publier des questions
    # ═══════════════════════════════════════════════════════════════
    section("6. RPCs admin pour insertion de questions")
    admin_rpcs = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' "
        "AND (p.proname LIKE '%admin%prep%' OR p.proname LIKE '%prep%admin%' "
        "     OR p.proname LIKE '%prep%create%' OR p.proname LIKE '%prep%upsert%') "
        "ORDER BY p.proname")
    for r in admin_rpcs:
        print(f"  {r.get('proname','?')}")
        print(f"    Args: {r.get('args','')[:100]}")

    # ═══════════════════════════════════════════════════════════════
    # 7. Structure prep_quiz_attempts (pour les weaknesses)
    # ═══════════════════════════════════════════════════════════════
    section("7. Structure prep_quiz_attempts")
    cols = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_quiz_attempts' "
        "ORDER BY ordinal_position")
    if cols:
        for c in cols:
            print(f"  {c.get('column_name',''):25s} {c.get('udt_name','')}")
    else:
        print("  ❌ Table non trouvée")

    # ═══════════════════════════════════════════════════════════════
    # 8. Vérifier RPCs dans le schema PUBLIC aussi
    # ═══════════════════════════════════════════════════════════════
    section("8. RPCs 'prep' dans schema PUBLIC")
    pub_rpcs = q(m,
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname LIKE '%prep%' ORDER BY p.proname")
    if pub_rpcs:
        for r in pub_rpcs:
            print(f"  {r.get('proname','')}")
    else:
        print("  Aucune RPC prep dans public")

    # ═══════════════════════════════════════════════════════════════
    # 9. Vérifier quels RPCs sont exposées via PostgREST
    # ═══════════════════════════════════════════════════════════════
    section("9. RPCs accessibles via API REST (test direct)")
    test_rpcs = [
        'app_prep_get_quiz_questions',
        'app_prep_list_questions', 
        'app_prep_get_adaptive_quiz',
        'app_prep_save_quiz_attempt',
        'app_prep_get_subject_stats',
        'app_prep_get_student_progress',
    ]
    for rpc_name in test_rpcs:
        try:
            resp = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc_name}",
                headers=m.headers,
                json={},
                timeout=10
            )
            if resp.status_code == 200:
                print(f"  ✅ {rpc_name} → 200 OK")
            elif resp.status_code == 404:
                print(f"  ❌ {rpc_name} → 404 NOT FOUND")
            else:
                print(f"  ⚠️  {rpc_name} → {resp.status_code} ({resp.text[:60]})")
        except Exception as e:
            print(f"  ❌ {rpc_name} → Exception: {str(e)[:50]}")

    print("\n✅ Audit approfondi terminé.\n")

    # Sauvegarder le log
    log_path = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs"
    import os
    os.makedirs(log_path, exist_ok=True)
    with open(os.path.join(log_path, "audit_prep_rpcs_deep.txt"), "w", encoding="utf-8") as f:
        f.write("Audit réalisé via audit_prep_rpcs_deep.py\n")
        f.write(f"RPCs prep totales: {len(all_rpcs)}\n")
        f.write(f"RPCs quiz/question: {len(quiz_rpcs)}\n\n")
        for r in all_rpcs:
            f.write(f"[{r.get('schema','')}] {r.get('name','')}\n")
            f.write(f"  Args: {r.get('args','')}\n")
            f.write(f"  Returns: {r.get('returns','')}\n\n")
    print(f"📄 Log sauvegardé dans {log_path}/audit_prep_rpcs_deep.txt")

if __name__ == "__main__":
    main()
