#!/usr/bin/env python3
"""Analyser le code des RPCs pour comprendre la logique actuelle."""
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
    print("\n📊 ANALYSE DES RPCs — Logique Adaptative\n")

    # ── 1. Corps de app_prep_get_my_subject_stats ────────────────────
    section("1. RPC app_prep_get_my_subject_stats")
    body1 = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_get_my_subject_stats'")
    if body1:
        code = body1[0].get("prosrc", "")
        print("ANALYSE DU CODE:")
        print("-" * 50)
        # Chercher des mots-clés importants
        keywords = ["quiz_attempts", "score", "avg", "count", "difficulty", "weak", "strong", 
                    "correct", "incorrect", "performance", "progress"]
        for kw in keywords:
            if kw in code.lower():
                print(f"  ✅ Contient '{kw}'")
        
        # Afficher les parties intéressantes du code
        lines = code.split('\n')
        for i, line in enumerate(lines):
            if any(kw in line.lower() for kw in ["select", "from", "where", "group", "order", "json"]):
                print(f"  L{i+1}: {line.strip()[:100]}")

    # ── 2. Corps de app_prep_get_quiz_questions ──────────────────────
    section("2. RPC app_prep_get_quiz_questions")
    body2 = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_get_quiz_questions'")
    if body2:
        code = body2[0].get("prosrc", "")
        print("ANALYSE DU CODE:")
        print("-" * 50)
        # Chercher la logique adaptative
        adaptive_keywords = ["weak", "score", "attempt", "difficulty", "adapt", "weight", 
                            "priority", "performance", "history", "previous", "failed"]
        found_adaptive = False
        for kw in adaptive_keywords:
            if kw in code.lower():
                print(f"  ✅ Contient '{kw}'")
                found_adaptive = True
        
        if not found_adaptive:
            print("  ⚠️  Aucune logique adaptative détectée")
        
        # Afficher comment les questions sont sélectionnées
        lines = code.split('\n')
        for i, line in enumerate(lines):
            if any(kw in line.lower() for kw in ["select", "from prep_questions", "where", "order by", "random", "limit"]):
                print(f"  L{i+1}: {line.strip()[:100]}")

    # ── 3. Vérifier si des données de performance existent ───────────
    section("3. DONNÉES DE PERFORMANCE EXISTANTES")
    
    # Vérifier prep_quiz_attempts
    attempts_data = q(m,
        "SELECT COUNT(*) AS total, COUNT(DISTINCT student_id) AS students "
        "FROM app.prep_quiz_attempts")
    if attempts_data:
        print(f"  Quiz attempts: {attempts_data[0].get('total')} tentatives, "
              f"{attempts_data[0].get('students')} étudiants")
    
    # Vérifier prep_student_progress
    progress_data = q(m,
        "SELECT COUNT(*) AS total, AVG(total_correct) AS avg_correct, "
        "AVG(total_answered) AS avg_answered "
        "FROM app.prep_student_progress")
    if progress_data:
        d = progress_data[0]
        print(f"  Student progress: {d.get('total')} entrées")
        if d.get('avg_correct'):
            print(f"    Moyenne correct: {d.get('avg_correct'):.1f}/{d.get('avg_answered'):.1f}")

    # ── 4. Vérifier la structure prep_attempts (détail par question) ─
    section("4. STRUCTURE prep_attempts (détail par question)")
    attempts_cols = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_attempts' "
        "ORDER BY ordinal_position")
    if not attempts_cols:
        print("  ❌ Table n'existe pas — pas de tracking par question individuelle")
    else:
        for c in attempts_cols:
            print(f"  {c.get('column_name'):30s}  {c.get('udt_name')}")
        
        # Compter les données
        count = q(m, "SELECT COUNT(*) AS n FROM app.prep_attempts")
        print(f"\n  Données: {count[0].get('n','?') if count else '?'} entrées")

    # ── 5. Analyser app_prep_get_student_progress ────────────────────
    section("5. RPC app_prep_get_student_progress")
    body3 = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_get_student_progress'")
    if body3:
        code = body3[0].get("prosrc", "")
        # Vérifier si elle retourne des stats par matière
        if "subject" in code.lower() or "matière" in code.lower():
            print("  ✅ Retourne des stats PAR MATIÈRE")
        else:
            print("  ⚠️  Ne semble pas retourner de stats par matière")
        
        # Chercher si elle calcule des faiblesses
        if any(kw in code.lower() for kw in ["weak", "faible", "difficult", "struggle"]):
            print("  ✅ Détecte des faiblesses")
        else:
            print("  ⚠️  Ne détecte pas de faiblesses spécifiques")

    # ── 6. Vérifier si une table de faiblesses existe ────────────────
    section("6. TABLES DE FAIBLESSES/RECOMMANDATIONS")
    weakness_tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND ("
        "  table_name LIKE '%weak%' OR table_name LIKE '%strength%' "
        "  OR table_name LIKE '%recommend%' OR table_name LIKE '%difficult%' "
        "  OR table_name LIKE '%performance%' OR table_name LIKE '%adaptive%' "
        ") ORDER BY table_name")
    if not weakness_tables:
        print("  ❌ Aucune table de suivi des faiblesses trouvée")
    else:
        for t in weakness_tables:
            tn = t.get("table_name")
            count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
            n = count[0].get("n", "?") if count else "?"
            print(f"  app.{tn:45s}  {n} lignes")

    # ── VERDICT ──────────────────────────────────────────────────────
    section("VERDICT")
    print("""
  D'après l'analyse:
  
  1. Les STRUCTURES existent (tables de progress, attempts, stats)
  2. Les RPCs de statistiques existent (get_my_subject_stats, get_student_progress)
  3. MAIS la sélection des questions semble être ALÉATOIRE (ORDER BY RANDOM)
  4. Aucune table de tracking des faiblesses par matière/question
  5. Pas de pondération basée sur les performances passées
  
  → Le système actuel NE FAIT PAS d'apprentissage adaptatif.
     Il manque la logique pour cibler les faiblesses.
    """)

    print("✅ Analyse terminée.\n")

if __name__ == "__main__":
    main()
