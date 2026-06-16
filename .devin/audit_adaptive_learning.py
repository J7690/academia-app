#!/usr/bin/env python3
"""Audit: le système de prépa concours a-t-il un apprentissage adaptatif?
Vérifie: suivi des résultats par matière, détection des faiblesses, génération ciblée."""
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    data = r.json()
    return data if isinstance(data, list) else []

def section(t): print(f"\n{'='*60}\n  {t}\n{'='*60}")

def main():
    m = SupabaseAutoManager()
    print("\n🧠 AUDIT APPRENTISSAGE ADAPTATIF — Prépa Concours")

    # ── 1. Tables de suivi des résultats ─────────────────────────────
    section("1. TABLES DE SUIVI DES RÉSULTATS")
    tracking_tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND ("
        "  table_name LIKE 'prep%attempt%' OR table_name LIKE 'prep%result%' "
        "  OR table_name LIKE 'prep%progress%' OR table_name LIKE 'prep%score%' "
        "  OR table_name LIKE 'prep%history%' OR table_name LIKE 'prep%answer%' "
        "  OR table_name LIKE 'prep%performance%' OR table_name LIKE 'prep%stat%' "
        "  OR table_name LIKE 'prep%quiz_attempt%' OR table_name LIKE 'prep%weak%' "
        "  OR table_name LIKE 'prep%strength%' OR table_name LIKE 'prep%student%' "
        ") ORDER BY table_name")
    for t in tracking_tables:
        tn = t.get("table_name")
        count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
        n = count[0].get("n", "?") if count else "?"
        print(f"  app.{tn:45s}  {n} lignes")

    # ── 2. Structure des tables clés ─────────────────────────────────
    section("2. STRUCTURE prep_quiz_attempts")
    cols = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_quiz_attempts' "
        "ORDER BY ordinal_position")
    if not cols:
        print("  ❌ Table prep_quiz_attempts n'existe pas")
    for c in cols:
        print(f"  {c.get('column_name'):30s}  {c.get('udt_name')}")

    # ── 3. Données existantes dans les attempts ──────────────────────
    section("3. DONNÉES DE TENTATIVES")
    attempts = q(m,
        "SELECT COUNT(*) AS total FROM app.prep_quiz_attempts")
    if attempts:
        print(f"  Total tentatives: {attempts[0].get('total','?')}")
    
    sample = q(m,
        "SELECT id, score, total_questions, subject_id, created_at "
        "FROM app.prep_quiz_attempts "
        "ORDER BY created_at DESC LIMIT 5")
    for s in sample:
        print(f"  [{str(s.get('created_at',''))[:19]}] score={s.get('score')}/{s.get('total_questions')} subj={str(s.get('subject_id',''))[:8]}")

    # ── 4. RPCs liées à la progression/stats ─────────────────────────
    section("4. RPCs PROGRESSION / STATISTIQUES")
    rpcs = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE (n.nspname='app' OR n.nspname='public') "
        "AND (p.proname LIKE '%prep%progress%' OR p.proname LIKE '%prep%stat%' "
        "  OR p.proname LIKE '%prep%weak%' OR p.proname LIKE '%prep%strength%' "
        "  OR p.proname LIKE '%prep%recommend%' OR p.proname LIKE '%prep%adaptive%' "
        "  OR p.proname LIKE '%prep%performance%' OR p.proname LIKE '%prep%score%' "
        "  OR p.proname LIKE '%prep%my%' OR p.proname LIKE '%prep%predict%' "
        "  OR p.proname LIKE '%prep%psycho%' OR p.proname LIKE '%prep%quiz%' "
        ") ORDER BY p.proname")
    for r in rpcs:
        print(f"  ✅ {r.get('proname','?'):50s}")

    # ── 5. Vérifier si la progression par matière existe ─────────────
    section("5. PROGRESSION PAR MATIÈRE")
    # Tester app_prep_get_my_subject_stats
    subj_stats_rpc = q(m,
        "SELECT p.proname, pg_get_function_result(p.oid) AS result_type, "
        "pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE p.proname='app_prep_get_my_subject_stats'")
    if subj_stats_rpc:
        r = subj_stats_rpc[0]
        print(f"  ✅ app_prep_get_my_subject_stats existe")
        print(f"     Args: {r.get('args','')}")
        print(f"     Returns: {r.get('result_type','')}")
    else:
        print("  ❌ app_prep_get_my_subject_stats n'existe pas")

    # ── 6. Vérifier si un système de recommandation existe ───────────
    section("6. SYSTÈME DE RECOMMANDATION ADAPTATIF")
    adaptive_rpcs = q(m,
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE (n.nspname='app' OR n.nspname='public') "
        "AND (p.proname LIKE '%recommend%' OR p.proname LIKE '%adaptive%' "
        "  OR p.proname LIKE '%weak%' OR p.proname LIKE '%suggest%' "
        "  OR p.proname LIKE '%personali%') "
        "ORDER BY p.proname")
    if not adaptive_rpcs:
        print("  ❌ Aucune RPC de recommandation adaptative trouvée")
    for r in adaptive_rpcs:
        print(f"  ✅ {r.get('proname','?')}")

    # ── 7. Vérifier le quiz questions RPC ────────────────────────────
    section("7. RPC DE QUIZ (app_prep_get_quiz_questions)")
    quiz_rpc = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args, "
        "pg_get_function_result(p.oid) AS result_type "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE p.proname='app_prep_get_quiz_questions'")
    if quiz_rpc:
        r = quiz_rpc[0]
        print(f"  ✅ Existe")
        print(f"     Args: {r.get('args','')}")
    else:
        print("  ❌ N'existe pas")

    # Lire le corps de la fonction pour voir si elle a une logique adaptative
    quiz_body = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE p.proname='app_prep_get_quiz_questions'")
    if quiz_body:
        body = quiz_body[0].get("prosrc", "")
        has_adaptive = any(kw in body.lower() for kw in [
            "weak", "strength", "score", "attempt", "difficulty", "adapt",
            "recommend", "weight", "priority", "performance"
        ])
        print(f"  Logique adaptative dans le corps: {'✅ OUI' if has_adaptive else '❌ NON'}")
        # Extraire les mots-clés pertinents
        for kw in ["weak", "score", "attempt", "difficulty", "adapt", "weight", "performance"]:
            if kw in body.lower():
                print(f"    → contient '{kw}'")

    # ── 8. Structure prep_student_progress ───────────────────────────
    section("8. STRUCTURE prep_student_progress")
    prog_cols = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_student_progress' "
        "ORDER BY ordinal_position")
    if not prog_cols:
        print("  ❌ Table n'existe pas")
    for c in prog_cols:
        print(f"  {c.get('column_name'):30s}  {c.get('udt_name')}")

    # ── VERDICT ──────────────────────────────────────────────────────
    section("VERDICT")
    print()

    print("✅ Audit terminé.\n")

if __name__ == "__main__":
    main()
