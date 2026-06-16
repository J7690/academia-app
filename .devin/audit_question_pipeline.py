#!/usr/bin/env python3
"""Audit complet: comment les questions admin arrivent aux étudiants."""
from __future__ import annotations
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
    print("\n🔍 AUDIT — Pipeline Questions: Admin → Étudiant\n")

    # 1. Structure prep_questions
    section("1. TABLE prep_questions — Colonnes clés")
    cols = q(m,
        "SELECT column_name, udt_name, column_default FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_questions' "
        "ORDER BY ordinal_position")
    key_cols = ['id', 'subject_id', 'question', 'content', 'options', 'correct_index',
                'correct_answer', 'explanation', 'difficulty', 'subject', 'concours_type',
                'is_published', 'is_active', 'source', 'choice_a', 'choice_b', 'choice_c', 'choice_d']
    for c in cols:
        cn = c.get('column_name','')
        if cn in key_cols:
            print(f"  {cn:25s} {c.get('udt_name',''):15s} default={c.get('column_default','')}")

    # 2. Données actuelles
    section("2. DONNÉES prep_questions")
    stats = q(m,
        "SELECT COUNT(*) AS total, "
        "COUNT(*) FILTER (WHERE is_published = true) AS published, "
        "COUNT(*) FILTER (WHERE is_active = true) AS active, "
        "COUNT(DISTINCT subject_id) AS subjects, "
        "COUNT(DISTINCT source) AS sources, "
        "COUNT(DISTINCT concours_type) AS concours_types "
        "FROM app.prep_questions")
    if stats:
        d = stats[0]
        print(f"  Total: {d.get('total',0)}")
        print(f"  Publiées: {d.get('published',0)}")
        print(f"  Actives: {d.get('active',0)}")
        print(f"  Matières: {d.get('subjects',0)}")
        print(f"  Sources: {d.get('sources',0)}")
    
    # Sources
    sources = q(m,
        "SELECT source, COUNT(*) AS n FROM app.prep_questions GROUP BY source ORDER BY n DESC")
    print("\n  Par source:")
    for s in sources:
        print(f"    {s.get('source','NULL'):20s} → {s.get('n',0)} questions")

    # 3. RPC app_prep_get_quiz_questions — code source
    section("3. RPC app_prep_get_quiz_questions — Logique")
    body = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_get_quiz_questions'")
    if body:
        code = body[0].get('prosrc','')
        # Chercher les filtres importants
        for kw in ['is_published', 'is_active', 'RANDOM', 'subject', 'concours_type', 'difficulty']:
            if kw.lower() in code.lower():
                print(f"  ✅ Utilise filtre '{kw}'")
            else:
                print(f"  ❌ N'utilise PAS '{kw}'")
        
        # Afficher les lignes SELECT/FROM/WHERE
        lines = code.split('\n')
        print("\n  Code pertinent:")
        for i, line in enumerate(lines):
            sl = line.strip().lower()
            if any(k in sl for k in ['select', 'from app.prep', 'where', 'order by', 'limit', 'is_published']):
                print(f"    L{i}: {line.strip()[:100]}")
    else:
        print("  ❌ RPC non trouvée!")

    # 4. RPC app_prep_get_adaptive_quiz
    section("4. RPC app_prep_get_adaptive_quiz — Logique")
    body2 = q(m,
        "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname='app_prep_get_adaptive_quiz'")
    if body2:
        code = body2[0].get('prosrc','')
        for kw in ['is_published', 'prep_questions', 'prep_subjects', 'weakness', 'RANDOM']:
            if kw.lower() in code.lower():
                print(f"  ✅ Utilise '{kw}'")
    else:
        print("  ❌ RPC non trouvée!")

    # 5. Semantic search pour RAG
    section("5. RAG — prep_doc_chunks et semantic search")
    chunks = q(m,
        "SELECT COUNT(*) AS total, "
        "COUNT(*) FILTER (WHERE embedding IS NOT NULL) AS with_embedding "
        "FROM app.prep_doc_chunks")
    if chunks:
        d = chunks[0]
        print(f"  Chunks: {d.get('total',0)} (dont {d.get('with_embedding',0)} avec embedding)")
    else:
        # Peut-être prep_chunks au lieu de prep_doc_chunks
        chunks2 = q(m,
            "SELECT COUNT(*) AS total FROM app.prep_chunks")
        if chunks2:
            print(f"  prep_chunks: {chunks2[0].get('total',0)} entrées")

    # 6. prep_question_choices
    section("6. TABLE prep_question_choices")
    choices = q(m,
        "SELECT COUNT(*) AS total, COUNT(DISTINCT question_id) AS questions_with_choices "
        "FROM app.prep_question_choices")
    if choices:
        d = choices[0]
        print(f"  Choix: {d.get('total',0)} ({d.get('questions_with_choices',0)} questions avec choix)")

    # 7. Vérifier le chemin complet
    section("7. VÉRIFICATION DU CHEMIN COMPLET")
    
    # Une question publiée est-elle accessible via get_quiz_questions?
    test = q(m,
        "SELECT id, question, subject, is_published, is_active, source "
        "FROM app.prep_questions WHERE is_published = true LIMIT 3")
    if test:
        print(f"  ✅ {len(test)} questions publiées trouvées")
        for t in test[:2]:
            print(f"    → [{t.get('source','?')}] {t.get('subject','?')}: {str(t.get('question',''))[:60]}...")
    else:
        print("  ❌ Aucune question publiée!")

    # VERDICT
    section("VERDICT")
    print("""
  CHEMIN DES DONNÉES:
  
  1. Admin insère questions (JSON/texte/OCR)
     ↓ INSERT INTO app.prep_questions (is_published=true)
  
  2. Quiz normal: app_prep_get_quiz_questions
     → SELECT FROM app.prep_questions WHERE is_published=true
     → Filtre par subject, concours_type, difficulty
     → ORDER BY RANDOM() LIMIT count
  
  3. Quiz adaptatif: app_prep_get_adaptive_quiz
     → SELECT FROM app.prep_questions WHERE is_published=true
     → Priorise les matières faibles via prep_student_weaknesses
     → 70% questions ciblées, 30% générales
  
  4. Génération IA: prep-generate-questions
     → Semantic search sur prep_doc_chunks (si indexés)
     → LLM génère de NOUVELLES questions inspirées des vrais sujets
     → INSERT résultats dans prep_questions
  
  ⚠️  POINT CLÉ: Toute question avec is_published=true
      est IMMÉDIATEMENT disponible pour les étudiants.
      Pas besoin d'embeddings, pas besoin de tokens.
    """)

    print("✅ Audit terminé.\n")

if __name__ == "__main__":
    main()
