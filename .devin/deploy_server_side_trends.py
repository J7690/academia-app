#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Run trend analysis server-side via OpenRouter API directly from Python.
Since we can't redeploy the Edge Function right now, we replicate the logic here:
1. Gather questions + chunks
2. Call OpenRouter LLM for analysis
3. Upsert topics + predictions into DB
"""
import json, sys, pathlib, requests, os, time
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

# OpenRouter config - read from .env or use the same key as Edge Functions
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")

# Try to get from Supabase secrets if not in env
if not OPENROUTER_API_KEY:
    # Read from the Edge Function env - we'll use the key from secrets
    # For now, let's check if there's a local config
    for p in [".windsurf/.env", ".env", "academia_app/.env"]:
        if pathlib.Path(p).exists():
            for line in pathlib.Path(p).read_text(encoding="utf-8", errors="ignore").splitlines():
                if line.startswith("OPENROUTER_API_KEY="):
                    OPENROUTER_API_KEY = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
        if OPENROUTER_API_KEY:
            break

def run_sql(label, sql_query, timeout=120):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": sql_query.strip()}, timeout=timeout).json()
    ok = r.get("ok", False)
    err = r.get("error")
    if label:
        print(f"  [{'OK' if ok else 'FAIL'}] {label}" + (f" -- {err}" if err else ""))
    return r

def run_ddl(label, ddl_query, timeout=180):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers, json={"ddl_query": ddl_query.strip()}, timeout=timeout).json()
    ok = not (isinstance(r, dict) and r.get("code"))
    err = r.get("message") if isinstance(r, dict) else None
    print(f"  [{'OK' if ok else 'FAIL'}] {label}" + (f" -- {str(err)[:200]}" if err else ""))
    return r

# ════════════════════════════════════════════════════════════════
# STEP 1: Gather data for analysis
# ════════════════════════════════════════════════════════════════
print("=== STEP 1: Gather questions for analysis ===")

# Get all questions grouped by subject
r_questions = run_sql("fetch_questions", """
    SELECT subject, concours_type, difficulty,
           LEFT(content, 300) AS content_preview,
           count(*) OVER (PARTITION BY subject) AS subject_count
    FROM app.prep_questions
    WHERE is_published = true
    ORDER BY subject, concours_type
    LIMIT 150
""")
questions = r_questions.get("rows", [])
print(f"  Questions fetched: {len(questions)}")

# Get recent actuality titles
r_actus = run_sql("fetch_actus", """
    SELECT LEFT(title, 150) AS title, relevance_score, matched_subjects
    FROM app.prep_news_articles
    WHERE is_concours_relevant = true AND relevance_score >= 0.5
    ORDER BY relevance_score DESC, published_at DESC
    LIMIT 20
""")
actus = r_actus.get("rows", [])
print(f"  Relevant actualities: {len(actus)}")

# Get existing topics
r_topics = run_sql("fetch_topics", "SELECT name, category FROM app.prep_topics ORDER BY name")
topics = r_topics.get("rows", [])
print(f"  Existing topics: {len(topics)}")

# ════════════════════════════════════════════════════════════════
# STEP 2: Build analysis prompt and call LLM
# ════════════════════════════════════════════════════════════════
print("\n=== STEP 2: Call LLM for trend analysis ===")

if not OPENROUTER_API_KEY:
    print("  WARNING: No OPENROUTER_API_KEY found. Using SQL-based analysis instead.")
    # Fallback: SQL-based statistical analysis without LLM
    print("\n=== FALLBACK: SQL-based statistical trend analysis ===")

    # Create predictions based on subject frequency analysis
    analysis_sql = """
    -- Analyze question distribution and create predictions
    WITH subject_stats AS (
        SELECT
            subject,
            count(*) AS question_count,
            count(DISTINCT concours_type) AS concours_coverage,
            round(avg(difficulty)::numeric, 1) AS avg_difficulty,
            array_agg(DISTINCT concours_type) AS concours_types
        FROM app.prep_questions
        WHERE is_published = true
        GROUP BY subject
    ),
    topic_mapping AS (
        SELECT
            t.id AS topic_id,
            t.name AS topic_name,
            t.category,
            COALESCE(ss.question_count, 0) AS question_count,
            COALESCE(ss.concours_coverage, 0) AS concours_coverage,
            COALESCE(ss.avg_difficulty, 2) AS avg_difficulty
        FROM app.prep_topics t
        LEFT JOIN subject_stats ss ON LOWER(ss.subject) LIKE '%' || LOWER(t.name) || '%'
            OR LOWER(t.name) LIKE '%' || LOWER(ss.subject) || '%'
            OR (t.category = 'culture_gen' AND ss.subject = 'Culture Generale')
            OR (t.category = 'droit' AND ss.subject LIKE 'Droit%')
            OR (t.category = 'economie' AND ss.subject IN ('Economie Generale', 'Finances Publiques'))
            OR (t.category = 'fiscalite' AND ss.subject IN ('Fiscalite', 'Comptabilite'))
    )
    SELECT topic_id, topic_name, category, question_count, concours_coverage, avg_difficulty,
           -- Calculate probability score based on frequency + coverage
           LEAST(95, GREATEST(30,
               (question_count * 3) +     -- More questions = higher probability
               (concours_coverage * 10) + -- More concours types = more universal
               CASE category
                   WHEN 'culture_gen' THEN 25  -- Culture gen is ALWAYS in concours
                   WHEN 'droit' THEN 20
                   WHEN 'economie' THEN 18
                   WHEN 'fiscalite' THEN 15
                   WHEN 'actualites' THEN 20
                   WHEN 'admin' THEN 12
                   WHEN 'mathematiques' THEN 15
                   ELSE 10
               END
           ))::integer AS probability_score,
           CASE category
               WHEN 'culture_gen' THEN 'Matiere systematique dans tous les concours BF'
               WHEN 'droit' THEN 'Matiere fondamentale, presente dans la majorite des concours'
               WHEN 'economie' THEN 'Matiere cle pour ENAREF, Douane, Admin civile'
               WHEN 'fiscalite' THEN 'Specifique ENAREF et Douane, forte probabilite'
               WHEN 'actualites' THEN 'Actualites BF toujours presentes en culture generale'
               WHEN 'mathematiques' THEN 'Calculs et raisonnement, variable selon concours'
               WHEN 'admin' THEN 'GRH specifique a certains concours'
               ELSE 'Theme transversal'
           END AS reasoning
    FROM topic_mapping
    """

    r_analysis = run_sql("sql_analysis", analysis_sql)
    if r_analysis.get("rows"):
        print(f"  Topics analyzed: {len(r_analysis['rows'])}")
        for row in r_analysis["rows"]:
            topic_id = row.get("topic_id")
            prob = row.get("probability_score", 50)
            name = row.get("topic_name", "?")
            reasoning = row.get("reasoning", "")

            if not topic_id:
                continue

            # Insert predictions for TOUS + specific concours types
            for ct in ["TOUS", "ENAREF", "ADMIN_CIVIL", "PARAMILITAIRE", "DOUANE", "GREFFIERS"]:
                # Adjust score per concours type
                adj = prob
                if ct == "ENAREF" and row.get("category") in ("fiscalite", "economie", "droit"):
                    adj = min(95, prob + 10)
                elif ct == "PARAMILITAIRE" and row.get("category") == "culture_gen":
                    adj = min(95, prob + 5)
                elif ct == "DOUANE" and row.get("category") in ("fiscalite", "economie"):
                    adj = min(95, prob + 10)

                insert_sql = f"""
                INSERT INTO app.prep_topic_predictions (
                    topic_id, concours_type, target_year,
                    probability_score, frequency_count, reasoning
                ) VALUES (
                    '{topic_id}', '{ct}', '2027',
                    {adj}, {row.get('question_count', 0)},
                    '{reasoning}'
                ) ON CONFLICT (topic_id, concours_type, target_year) DO UPDATE SET
                    probability_score = {adj},
                    frequency_count = {row.get('question_count', 0)},
                    reasoning = '{reasoning}',
                    updated_at = now()
                """
                run_sql(None, insert_sql)

            print(f"    [{prob}%] {name} ({row.get('category','?')})")
else:
    # Full LLM analysis
    system_prompt = """Tu es un analyste expert en concours de la fonction publique du Burkina Faso.
Tu analyses les sujets d'examen des annees precedentes pour identifier les themes recurrents et predire les sujets probables pour 2027.

REGLES:
1. Identifie les themes principaux
2. Pour chaque theme, evalue la frequence d'apparition
3. Detecte les cycles
4. Prends en compte l'actualite du Burkina Faso
5. Attribue un score de probabilite (0-100)
6. Reponds UNIQUEMENT en JSON valide

FORMAT:
{"topics":[{"name":"Nom","category":"droit|economie|culture_gen|actualites|finances|fiscalite|admin|autre","description":"Description","predictions":[{"concours_type":"TOUS","probability_score":85,"frequency_count":4,"last_appeared_year":"2024","cycle_years":2.0,"reasoning":"Explication"}]}]}"""

    user_prompt = "Analyse les contenus suivants issus de vrais sujets de concours du BF:\n\n"

    # Add questions
    subj_groups = {}
    for q in questions:
        key = f"{q.get('subject','Autre')}/{q.get('concours_type','TOUS')}"
        if key not in subj_groups:
            subj_groups[key] = []
        subj_groups[key].append(q.get("content_preview", ""))

    for key, texts in subj_groups.items():
        user_prompt += f"--- {key} ({len(texts)} questions) ---\n"
        for t in texts[:3]:
            user_prompt += f"  {t[:200]}\n"
        user_prompt += "\n"

    # Add actualities
    if actus:
        user_prompt += "\n=== ACTUALITES RECENTES BF ===\n"
        for a in actus[:10]:
            user_prompt += f"  [{a.get('relevance_score',0)}] {a.get('title','')}\n"

    user_prompt += "\nGenere les predictions pour 2027. Identifie au moins 10 themes."

    print(f"  Prompt length: {len(user_prompt)} chars")

    resp = requests.post("https://openrouter.ai/api/v1/chat/completions", headers={
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }, json={
        "model": "google/gemini-2.0-flash-001",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.3,
        "max_tokens": 6000,
    }, timeout=120)

    if resp.status_code == 200:
        data = resp.json()
        content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        print(f"  LLM response: {len(content)} chars")

        # Parse JSON
        import re
        json_match = re.search(r'\{[\s\S]*"topics"[\s\S]*\}', content)
        if json_match:
            parsed = json.loads(json_match.group(0))
            topics_list = parsed.get("topics", [])
            print(f"  Topics parsed: {len(topics_list)}")

            for topic in topics_list:
                name = (topic.get("name") or "").strip()
                if not name:
                    continue
                category = (topic.get("category") or "autre").strip()
                description = (topic.get("description") or "").strip()

                # Upsert topic
                r_topic = run_sql(None, f"""
                    INSERT INTO app.prep_topics (name, category, description)
                    VALUES ('{name.replace("'", "''")}', '{category.replace("'", "''")}', '{description.replace("'", "''")[:200]}')
                    ON CONFLICT (name) DO UPDATE SET category = '{category.replace("'", "''")}', description = '{description.replace("'", "''")[:200]}'
                    RETURNING id
                """)
                topic_id = r_topic.get("rows", [{}])[0].get("id") if r_topic.get("rows") else None
                if not topic_id:
                    continue

                for pred in topic.get("predictions", []):
                    ct = (pred.get("concours_type") or "TOUS").strip()
                    score = min(100, max(0, pred.get("probability_score", 50)))
                    freq = pred.get("frequency_count", 0)
                    last_year = (pred.get("last_appeared_year") or "").strip()
                    cycle = pred.get("cycle_years", 0)
                    reasoning = (pred.get("reasoning") or "").strip()

                    run_sql(None, f"""
                        INSERT INTO app.prep_topic_predictions (
                            topic_id, concours_type, target_year,
                            probability_score, frequency_count, last_appeared_year, cycle_years, reasoning
                        ) VALUES (
                            '{topic_id}', '{ct.replace("'", "''")}', '2027',
                            {score}, {freq}, '{last_year.replace("'", "''")}', {cycle}, '{reasoning.replace("'", "''")[:300]}'
                        ) ON CONFLICT (topic_id, concours_type, target_year) DO UPDATE SET
                            probability_score = {score}, frequency_count = {freq},
                            last_appeared_year = '{last_year.replace("'", "''")}',
                            cycle_years = {cycle}, reasoning = '{reasoning.replace("'", "''")[:300]}',
                            updated_at = now()
                    """)

                print(f"    {name} ({category}): {len(topic.get('predictions',[]))} predictions")
        else:
            print(f"  ERROR: Could not parse JSON from LLM response")
            print(f"  Raw: {content[:500]}")
    else:
        print(f"  LLM call failed: HTTP {resp.status_code}")
        print(f"  {resp.text[:300]}")

# ════════════════════════════════════════════════════════════════
# STEP 3: Verify results
# ════════════════════════════════════════════════════════════════
print("\n=== STEP 3: Verify results ===")
time.sleep(1)

r = run_sql("count_topics", "SELECT count(*)::text AS n FROM app.prep_topics")
print(f"  Topics: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else 'ERR'}")

r = run_sql("count_predictions", "SELECT count(*)::text AS n FROM app.prep_topic_predictions")
print(f"  Predictions: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else 'ERR'}")

r = run_sql("count_tags", "SELECT count(*)::text AS n FROM app.prep_question_topics")
print(f"  Question-topic links: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else 'ERR'}")

print("\n=== TOP PREDICTIONS ===")
r = run_sql("top_preds", """
    SELECT t.name, tp.concours_type, tp.probability_score, LEFT(tp.reasoning, 80) AS reason
    FROM app.prep_topic_predictions tp
    JOIN app.prep_topics t ON t.id = tp.topic_id
    WHERE tp.concours_type = 'TOUS'
    ORDER BY tp.probability_score DESC
    LIMIT 10
""")
if r.get("rows"):
    for row in r["rows"]:
        print(f"  [{row.get('probability_score','?')}%] {row.get('name','?')} — {row.get('reason','')}")

print("\n[OK] Done")
