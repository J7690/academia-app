#!/usr/bin/env python3
"""Audit module Prépa Concours: tables, RPCs, contenu, Edge Functions."""
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
    print("\n🎓 AUDIT MODULE PRÉPA CONCOURS")

    # ── 1. Tables prep_* ─────────────────────────────────────────────
    section("1. TABLES PRÉPA CONCOURS")
    tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name LIKE 'prep%' "
        "ORDER BY table_name")
    for t in tables:
        tn = t.get("table_name")
        count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
        n = count[0].get("n", "?") if count else "?"
        print(f"  app.{tn:45s}  {n} lignes")

    # ── 2. RPCs prep_* ───────────────────────────────────────────────
    section("2. RPCs PRÉPA CONCOURS")
    rpcs = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE (n.nspname='app' OR n.nspname='public') "
        "AND p.proname LIKE '%prep%' "
        "ORDER BY p.proname")
    for r in rpcs:
        print(f"  ✅ {r.get('proname','?'):50s}  ({r.get('args','')[:60]})")

    # ── 3. Sujets existants ──────────────────────────────────────────
    section("3. SUJETS (prep_subjects)")
    subjects = q(m,
        "SELECT id, name, concours_type, is_active "
        "FROM app.prep_subjects "
        "ORDER BY concours_type, name")
    if not subjects:
        print("  ❌ Aucun sujet trouvé")
    for s in subjects:
        active = "✅" if s.get("is_active") else "❌"
        print(f"  {active} [{s.get('concours_type','?'):15s}] {s.get('name','?'):30s}  id={str(s.get('id',''))[:8]}")

    # ── 4. Questions existantes ──────────────────────────────────────
    section("4. QUESTIONS (prep_questions)")
    q_stats = q(m,
        "SELECT "
        "  COUNT(*) AS total, "
        "  COUNT(CASE WHEN is_published THEN 1 END) AS published, "
        "  COUNT(CASE WHEN source='ai_generated' THEN 1 END) AS ai_gen, "
        "  COUNT(CASE WHEN source='import' THEN 1 END) AS imported "
        "FROM app.prep_questions")
    if q_stats:
        s = q_stats[0]
        print(f"  Total       : {s.get('total')}")
        print(f"  Publiées    : {s.get('published')}")
        print(f"  IA générées : {s.get('ai_gen')}")
        print(f"  Importées   : {s.get('imported')}")

    q_by_subj = q(m,
        "SELECT ps.name AS subject_name, pq.concours_type, COUNT(*) AS n "
        "FROM app.prep_questions pq "
        "LEFT JOIN app.prep_subjects ps ON ps.id = pq.subject_id "
        "GROUP BY ps.name, pq.concours_type "
        "ORDER BY n DESC")
    if q_by_subj:
        print("\n  Répartition par matière:")
        for r in q_by_subj:
            print(f"    {str(r.get('subject_name','?')):25s}  {str(r.get('concours_type','?')):15s}  {r.get('n')} questions")

    # ── 5. Choix de réponse ──────────────────────────────────────────
    section("5. CHOIX DE RÉPONSE (prep_question_choices)")
    choices = q(m,
        "SELECT COUNT(*) AS total, "
        "COUNT(CASE WHEN is_correct THEN 1 END) AS correct "
        "FROM app.prep_question_choices")
    if choices:
        c = choices[0]
        print(f"  Total choix  : {c.get('total')}")
        print(f"  Choix correct: {c.get('correct')}")

    # ── 6. Banques de documents / chunks indexés ─────────────────────
    section("6. BANQUES DE DOCUMENTS (prep_banks)")
    banks = q(m,
        "SELECT id, name, concours_type, doc_count, chunk_count, is_active "
        "FROM app.prep_banks "
        "ORDER BY concours_type, name")
    if not banks:
        print("  ❌ Aucune banque de documents trouvée")
    for b in banks:
        active = "✅" if b.get("is_active") else "❌"
        print(f"  {active} [{b.get('concours_type','?'):15s}] {b.get('name','?'):30s}  "
              f"docs={b.get('doc_count','?')} chunks={b.get('chunk_count','?')}")

    # ── 7. Chunks indexés (RAG) ──────────────────────────────────────
    section("7. CHUNKS INDEXÉS (prep_chunks)")
    chunks = q(m,
        "SELECT COUNT(*) AS total, "
        "COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) AS with_emb "
        "FROM app.prep_chunks")
    if chunks:
        c = chunks[0]
        print(f"  Total chunks  : {c.get('total')}")
        print(f"  Avec embedding: {c.get('with_emb')}")

    # ── 8. Générations IA passées ────────────────────────────────────
    section("8. GÉNÉRATIONS IA (prep_ai_generations)")
    gens = q(m,
        "SELECT status, generation_type, COUNT(*) AS n "
        "FROM app.prep_ai_generations "
        "GROUP BY status, generation_type "
        "ORDER BY n DESC")
    if not gens:
        print("  ❌ Aucune génération IA passée")
    for g in gens:
        print(f"  {g.get('status','?'):15s}  {g.get('generation_type','?'):10s}  x{g.get('n')}")

    # ── 9. Edge Functions prep déployées ─────────────────────────────
    section("9. EDGE FUNCTIONS PRÉPA")
    ef_names = ["prep-generate-questions", "prep-tutor-chat", "prep-analyze-trends"]
    for ef in ef_names:
        try:
            r = requests.options(f"{m.url}/functions/v1/{ef}", timeout=5)
            deployed = r.status_code == 200
        except:
            deployed = False
        print(f"  {'✅' if deployed else '❌'} {ef}")

    # ── 10. Échantillon de questions ──────────────────────────────────
    section("10. ÉCHANTILLON QUESTIONS (5 dernières)")
    sample = q(m,
        "SELECT question, subject, source, difficulty, is_published, created_at "
        "FROM app.prep_questions "
        "ORDER BY created_at DESC LIMIT 5")
    for s in sample:
        pub = "✅" if s.get("is_published") else "❌"
        print(f"  {pub} [{s.get('source','?'):12s}] d={s.get('difficulty','?')} {str(s.get('question',''))[:60]}")

    section("VERDICT")
    print()
    print("✅ Audit terminé.\n")

if __name__ == "__main__":
    main()
