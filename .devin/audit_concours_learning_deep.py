#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit profond du dispositif d'apprentissage IA du module Concours.
Verifie: topics, predictions, trends, questions, chunks, RAG, adaptive, Edge Functions.
"""
import json, sys, pathlib, requests
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def sql(q, timeout=60):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": q.strip()}, timeout=timeout).json()
    return r

R = {}

# ════════════════════════════════════════════════════════════════
# A. TABLES D'APPRENTISSAGE — structure + donnees
# ════════════════════════════════════════════════════════════════

print("=" * 60)
print("A. TABLES D'APPRENTISSAGE")
print("=" * 60)

# A1. prep_topics
print("\n--- A1. prep_topics (themes/sujets identifies) ---")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_topics' ORDER BY ordinal_position")
R["prep_topics_cols"] = r.get("rows", [])
for row in R["prep_topics_cols"]:
    print(f"  {row['column_name']} ({row['data_type']})")

r = sql("SELECT * FROM app.prep_topics ORDER BY name")
R["prep_topics_data"] = r.get("rows", [])
print(f"  Total: {len(R['prep_topics_data'])} topics")
for row in R["prep_topics_data"]:
    print(f"    [{row.get('category','')}] {row.get('name','')} — {(row.get('description') or '')[:60]}")

# A2. prep_topic_predictions
print("\n--- A2. prep_topic_predictions (predictions de probabilite) ---")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_topic_predictions' ORDER BY ordinal_position")
R["prep_topic_predictions_cols"] = r.get("rows", [])
for row in R["prep_topic_predictions_cols"]:
    print(f"  {row['column_name']} ({row['data_type']})")

r = sql("SELECT count(*)::text AS n FROM app.prep_topic_predictions")
n = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "ERR"
R["prep_topic_predictions_count"] = n
print(f"  Predictions existantes: {n}")

if int(n) > 0:
    r = sql("SELECT t.name AS topic, tp.concours_type, tp.probability_score, tp.frequency_count, tp.last_appeared_year, tp.cycle_years, LEFT(tp.reasoning, 100) AS reasoning FROM app.prep_topic_predictions tp JOIN app.prep_topics t ON t.id = tp.topic_id ORDER BY tp.probability_score DESC LIMIT 10")
    R["top_predictions"] = r.get("rows", [])
    for row in R["top_predictions"]:
        print(f"    [{row.get('probability_score')}%] {row.get('topic')} | last={row.get('last_appeared_year')} | cycle={row.get('cycle_years')}y | {row.get('concours_type')}")

# A3. prep_question_topics (liaison questions <-> topics)
print("\n--- A3. prep_question_topics ---")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_question_topics' ORDER BY ordinal_position")
R["prep_question_topics_cols"] = r.get("rows", [])
if R["prep_question_topics_cols"]:
    for row in R["prep_question_topics_cols"]:
        print(f"  {row['column_name']} ({row['data_type']})")
    r = sql("SELECT count(*)::text AS n FROM app.prep_question_topics")
    R["question_topics_count"] = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "ERR"
    print(f"  Liaisons questions-topics: {R['question_topics_count']}")
else:
    print("  TABLE N'EXISTE PAS")
    R["prep_question_topics_cols"] = "MISSING"

# A4. prep_student_weaknesses (apprentissage adaptatif)
print("\n--- A4. prep_student_weaknesses ---")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_student_weaknesses' ORDER BY ordinal_position")
R["prep_student_weaknesses_cols"] = r.get("rows", [])
if R["prep_student_weaknesses_cols"]:
    for row in R["prep_student_weaknesses_cols"]:
        print(f"  {row['column_name']} ({row['data_type']})")
    r = sql("SELECT count(*)::text AS n FROM app.prep_student_weaknesses")
    R["weaknesses_count"] = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "ERR"
    print(f"  Enregistrements faiblesses: {R['weaknesses_count']}")
else:
    print("  TABLE N'EXISTE PAS")

# A5. prep_ai_corrections
print("\n--- A5. prep_ai_corrections ---")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_ai_corrections' ORDER BY ordinal_position")
R["prep_ai_corrections_cols"] = r.get("rows", [])
if R["prep_ai_corrections_cols"]:
    for row in R["prep_ai_corrections_cols"]:
        print(f"  {row['column_name']} ({row['data_type']})")
    r = sql("SELECT count(*)::text AS n FROM app.prep_ai_corrections")
    print(f"  Corrections IA: {r.get('rows', [{}])[0].get('n', '0') if r.get('rows') else 'ERR'}")
else:
    print("  TABLE N'EXISTE PAS")

# ════════════════════════════════════════════════════════════════
# B. QUESTIONS PASSEES — base de connaissances
# ════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("B. QUESTIONS PASSEES (base d'apprentissage)")
print("=" * 60)

# B1. Volume total
r = sql("SELECT count(*)::text AS n FROM app.prep_questions")
R["total_questions"] = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "0"
print(f"\n  Total questions: {R['total_questions']}")

# B2. Par sujet
print("\n--- B2. Questions par sujet ---")
r = sql("SELECT subject, count(*)::int AS n FROM app.prep_questions GROUP BY subject ORDER BY count(*) DESC")
R["questions_by_subject"] = r.get("rows", [])
for row in R["questions_by_subject"]:
    print(f"  {row.get('subject','NULL')}: {row['n']}")

# B3. Par concours_type
print("\n--- B3. Questions par concours_type ---")
r = sql("SELECT concours_type, count(*)::int AS n FROM app.prep_questions GROUP BY concours_type ORDER BY count(*) DESC")
R["questions_by_concours"] = r.get("rows", [])
for row in R["questions_by_concours"]:
    print(f"  {row.get('concours_type','NULL')}: {row['n']}")

# B4. Par source (comment elles sont arrivees)
print("\n--- B4. Questions par source ---")
r = sql("SELECT source, count(*)::int AS n FROM app.prep_questions GROUP BY source ORDER BY count(*) DESC")
R["questions_by_source"] = r.get("rows", [])
for row in R["questions_by_source"]:
    print(f"  {row.get('source','NULL')}: {row['n']}")

# B5. Par difficulty
print("\n--- B5. Questions par difficulty ---")
r = sql("SELECT difficulty, count(*)::int AS n FROM app.prep_questions GROUP BY difficulty ORDER BY difficulty")
R["questions_by_difficulty"] = r.get("rows", [])
for row in R["questions_by_difficulty"]:
    print(f"  difficulty={row.get('difficulty','NULL')}: {row['n']}")

# B6. Echantillon de contenu (pour voir la qualite)
print("\n--- B6. Echantillon questions (3 par matiere) ---")
for subj in ["Culture Generale", "Droit Constitutionnel", "Actualites BF", "Mathematiques", "Economie Generale"]:
    r = sql(f"SELECT LEFT(content, 120) AS preview, concours_type, difficulty FROM app.prep_questions WHERE subject = '{subj}' ORDER BY created_at DESC LIMIT 2")
    if r.get("rows"):
        print(f"\n  [{subj}]")
        for row in r["rows"]:
            print(f"    [{row.get('concours_type','?')}] d={row.get('difficulty','?')} | {row.get('preview','')}")

# ════════════════════════════════════════════════════════════════
# C. DOCUMENTS SOURCE (RAG)
# ════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("C. DOCUMENTS SOURCE (RAG)")
print("=" * 60)

# C1. prep_source_documents
print("\n--- C1. prep_source_documents par doc_type ---")
r = sql("SELECT doc_type, source_type, count(*)::int AS n FROM app.prep_source_documents GROUP BY doc_type, source_type ORDER BY count(*) DESC")
R["source_docs_by_type"] = r.get("rows", [])
for row in R["source_docs_by_type"]:
    print(f"  {row.get('doc_type','?')}/{row.get('source_type','?')}: {row['n']}")

# C2. prep_doc_chunks
print("\n--- C2. prep_doc_chunks par chunk_type ---")
r = sql("SELECT chunk_type, count(*)::int AS n, round(avg(token_count)::numeric, 0) AS avg_tokens FROM app.prep_doc_chunks GROUP BY chunk_type ORDER BY count(*) DESC")
R["chunks_by_type"] = r.get("rows", [])
for row in R["chunks_by_type"]:
    print(f"  {row.get('chunk_type','?')}: {row['n']} chunks (avg {row.get('avg_tokens','?')} tokens)")

# C3. Embeddings status
print("\n--- C3. Embeddings status ---")
r = sql("SELECT count(*)::text AS total, count(*) FILTER (WHERE embedding IS NOT NULL)::text AS with_emb FROM app.prep_doc_chunks")
R["embeddings_status"] = r.get("rows", [{}])[0] if r.get("rows") else {}
if R["embeddings_status"]:
    print(f"  Total chunks: {R['embeddings_status'].get('total','?')}")
    print(f"  Avec embeddings: {R['embeddings_status'].get('with_emb','?')}")

# ════════════════════════════════════════════════════════════════
# D. RPCs LIEES A L'APPRENTISSAGE
# ════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("D. RPCs APPRENTISSAGE")
print("=" * 60)

r = sql("""
SELECT proname FROM pg_proc
WHERE (proname LIKE '%trend%' OR proname LIKE '%predict%' OR proname LIKE '%adaptive%'
       OR proname LIKE '%weakness%' OR proname LIKE '%semantic%' OR proname LIKE '%score_article%'
       OR proname LIKE '%rag%' OR proname LIKE '%generate%' OR proname LIKE '%analyze%')
  AND pronamespace IN (SELECT oid FROM pg_namespace WHERE nspname IN ('public','app'))
ORDER BY proname
""")
R["learning_rpcs"] = r.get("rows", [])
for row in R["learning_rpcs"]:
    print(f"  {row['proname']}")

# ════════════════════════════════════════════════════════════════
# E. EDGE FUNCTIONS IA
# ════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("E. EDGE FUNCTIONS IA (verification deploiement)")
print("=" * 60)

edge_fns = [
    "prep-analyze-trends",
    "prep-generate-questions",
    "prep-tutor-chat",
    "prep-grade-assignment",
    "prep-ingest-document",
    "prep-feed-actuality",
    "prep-scan-subject",
]
R["edge_functions"] = {}
for fn in edge_fns:
    try:
        url = f"{m.url}/functions/v1/{fn}"
        resp = requests.options(url, headers={
            "Authorization": f"Bearer {m.service_key}",
            "apikey": m.service_key,
        }, timeout=10)
        status = resp.status_code
        # 204 = CORS OK (deployed), 404 = not deployed
        deployed = status in (200, 204, 400, 401, 500)
        R["edge_functions"][fn] = {"status": status, "deployed": deployed}
        print(f"  {fn}: HTTP {status} {'DEPLOYED' if deployed else 'NOT DEPLOYED'}")
    except Exception as e:
        R["edge_functions"][fn] = {"error": str(e)[:100]}
        print(f"  {fn}: ERROR {str(e)[:80]}")

# ════════════════════════════════════════════════════════════════
# F. QUIZ ATTEMPTS (donnees d'usage)
# ════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("F. QUIZ ATTEMPTS (donnees d'usage etudiant)")
print("=" * 60)

r = sql("SELECT count(*)::text AS n FROM app.prep_quiz_attempts")
R["quiz_attempts"] = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "ERR"
print(f"  Total quiz attempts: {R['quiz_attempts']}")

r = sql("SELECT count(DISTINCT user_id)::text AS n FROM app.prep_quiz_attempts")
R["quiz_unique_users"] = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "ERR"
print(f"  Utilisateurs uniques: {R['quiz_unique_users']}")

# F2. Trigger d'apprentissage
print("\n--- F2. Trigger apprentissage (trg_update_student_weaknesses) ---")
r = sql("SELECT tgname, tgrelid::regclass AS on_table, tgenabled FROM pg_trigger WHERE tgname LIKE '%weakness%' OR tgname LIKE '%adaptive%'")
R["learning_triggers"] = r.get("rows", [])
if R["learning_triggers"]:
    for row in R["learning_triggers"]:
        print(f"  {row['tgname']} ON {row.get('on_table','?')} | enabled={row.get('tgenabled','?')}")
else:
    print("  AUCUN TRIGGER D'APPRENTISSAGE TROUVE")

# ════════════════════════════════════════════════════════════════
# G. PREP_SUBJECTS (matieres)
# ════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("G. MATIERE <-> QUESTIONS COUVERTURE")
print("=" * 60)

r = sql("""
SELECT ps.title AS matiere,
       count(pq.id)::int AS nb_questions,
       count(pdc.id)::int AS nb_chunks
FROM app.prep_subjects ps
LEFT JOIN app.prep_questions pq ON pq.subject = ps.title
LEFT JOIN app.prep_doc_chunks pdc ON pdc.subject_name = ps.title
GROUP BY ps.title
ORDER BY ps.title
""")
R["coverage"] = r.get("rows", [])
for row in R["coverage"]:
    print(f"  {row.get('matiere','?')}: {row.get('nb_questions',0)} questions, {row.get('nb_chunks',0)} chunks RAG")

# Save
out = pathlib.Path("logs/audit_concours_learning_deep.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(R, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
print(f"\n[OK] Log: {out}")
