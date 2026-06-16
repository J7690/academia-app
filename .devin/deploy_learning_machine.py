#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Deploy the complete learning machine for Concours module.
Steps:
1. Cron job hebdo for prep-analyze-trends
2. Auto-tagger RPC (questions -> topics)
3. Embeddings batch generator RPC
4. UNIQUE constraint on prep_topic_predictions
5. Trigger first analysis run
"""
import json, sys, pathlib, requests, time
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def run_ddl(label, ddl_query, timeout=180):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers, json={"ddl_query": ddl_query.strip()}, timeout=timeout).json()
    ok = not (isinstance(r, dict) and r.get("code"))
    err = r.get("message") if isinstance(r, dict) else None
    print(f"  [{'OK' if ok else 'FAIL'}] {label}" + (f" -- {str(err)[:200]}" if err else ""))
    return r

def run_sql(label, sql_query, timeout=120):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": sql_query.strip()}, timeout=timeout).json()
    ok = r.get("ok", False)
    err = r.get("error")
    print(f"  [{'OK' if ok else 'FAIL'}] {label}" + (f" -- {err}" if err else ""))
    return r

results = []

# ═══════════════════════════════════════════════════════════════
# STEP 1: Add UNIQUE constraint on prep_topic_predictions
# ═══════════════════════════════════════════════════════════════
print("=== STEP 1: UNIQUE constraint ===")
r = run_ddl("unique_predictions", """
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'prep_topic_predictions_topic_concours_year_uq'
    ) THEN
        ALTER TABLE app.prep_topic_predictions
            ADD CONSTRAINT prep_topic_predictions_topic_concours_year_uq
            UNIQUE (topic_id, concours_type, target_year);
    END IF;
END $$;
""")
results.append(("unique_constraint", r))

# Add name UNIQUE on prep_topics if missing
r = run_ddl("unique_topic_name", """
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'prep_topics_name_key'
    ) THEN
        ALTER TABLE app.prep_topics ADD CONSTRAINT prep_topics_name_key UNIQUE (name);
    END IF;
END $$;
""")
results.append(("unique_topic_name", r))

# ═══════════════════════════════════════════════════════════════
# STEP 2: Auto-tagger RPC — link questions to topics
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 2: Auto-tagger RPC ===")
r = run_ddl("auto_tagger_rpc", """
CREATE OR REPLACE FUNCTION public.app_admin_auto_tag_questions_to_topics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_topic RECORD;
    v_question RECORD;
    v_tagged integer := 0;
    v_content_lower text;
BEGIN
    -- For each topic, find matching questions by content keyword matching
    FOR v_topic IN SELECT id, name, category FROM app.prep_topics LOOP
        FOR v_question IN
            SELECT id, content, subject FROM app.prep_questions
            WHERE is_published = true
              AND NOT EXISTS (
                  SELECT 1 FROM app.prep_question_topics qt
                  WHERE qt.question_id = app.prep_questions.id
                    AND qt.topic_id = v_topic.id
              )
        LOOP
            v_content_lower := LOWER(COALESCE(v_question.content, ''));

            -- Match if question content contains topic name (case-insensitive)
            IF v_content_lower LIKE '%' || LOWER(v_topic.name) || '%'
               OR LOWER(v_question.subject) LIKE '%' || LOWER(v_topic.name) || '%'
               OR (v_topic.category = 'culture_gen' AND v_question.subject = 'Culture Generale')
               OR (v_topic.category = 'droit' AND v_question.subject LIKE 'Droit%')
               OR (v_topic.category = 'economie' AND v_question.subject IN ('Economie Generale', 'Finances Publiques'))
               OR (v_topic.category = 'fiscalite' AND v_question.subject IN ('Fiscalite', 'Comptabilite'))
               OR (v_topic.category = 'mathematiques' AND v_question.subject = 'Mathematiques')
               OR (v_topic.category = 'admin' AND v_question.subject = 'GRH et Management')
            THEN
                INSERT INTO app.prep_question_topics (question_id, topic_id)
                VALUES (v_question.id, v_topic.id)
                ON CONFLICT DO NOTHING;
                v_tagged := v_tagged + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'tagged', v_tagged);
END;
$fn$;
""")
results.append(("auto_tagger_rpc", r))

# ═══════════════════════════════════════════════════════════════
# STEP 3: Cron job for prep-analyze-trends (weekly)
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 3: Cron job weekly analyze-trends ===")
service_key = m.service_key
supabase_url = m.url

# Remove old if exists
run_sql("remove_old_cron", "SELECT cron.unschedule('prep-analyze-trends-weekly')")

cron_sql = f"""
SELECT cron.schedule(
    'prep-analyze-trends-weekly',
    '0 6 * * 0',
    $$
    SELECT net.http_post(
        url := '{supabase_url}/functions/v1/prep-analyze-trends',
        headers := jsonb_build_object(
            'Authorization', 'Bearer {service_key}',
            'apikey', '{service_key}',
            'Content-Type', 'application/json'
        ),
        body := '{{"target_year": "2027", "concours_type": ""}}'::jsonb
    ) AS request_id
    $$
)
"""
r = run_sql("create_cron_trends", cron_sql)
results.append(("cron_trends", r))

# ═══════════════════════════════════════════════════════════════
# STEP 4: Cron job for auto-tagging (daily after feed)
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 4: Cron job daily auto-tag ===")
run_sql("remove_old_tag_cron", "SELECT cron.unschedule('prep-auto-tag-questions-daily')")

tag_cron = f"""
SELECT cron.schedule(
    'prep-auto-tag-questions-daily',
    '30 5 * * *',
    $$
    SELECT public.app_admin_auto_tag_questions_to_topics()
    $$
)
"""
r = run_sql("create_cron_autotag", tag_cron)
results.append(("cron_autotag", r))

# ═══════════════════════════════════════════════════════════════
# STEP 5: Run auto-tagging NOW
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 5: Run auto-tagging now ===")
r = run_sql("run_autotag", "SELECT public.app_admin_auto_tag_questions_to_topics() AS result")
if r.get("rows"):
    print(f"  Result: {r['rows'][0]}")
results.append(("run_autotag", r))

# ═══════════════════════════════════════════════════════════════
# STEP 6: Trigger prep-analyze-trends NOW
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 6: Trigger prep-analyze-trends NOW ===")
try:
    ef_url = f"{m.url}/functions/v1/prep-analyze-trends"
    ef_resp = requests.post(ef_url, headers={
        "Authorization": f"Bearer {m.service_key}",
        "apikey": m.service_key,
        "Content-Type": "application/json"
    }, json={"target_year": "2027", "concours_type": ""}, timeout=120)
    print(f"  HTTP {ef_resp.status_code}")
    try:
        d = ef_resp.json()
        print(f"  Response: {json.dumps(d, ensure_ascii=False)[:600]}")
        results.append(("analyze_trends", {"status": ef_resp.status_code, "body": d}))
    except Exception:
        print(f"  Raw: {ef_resp.text[:300]}")
        results.append(("analyze_trends", {"status": ef_resp.status_code, "raw": ef_resp.text[:300]}))
except Exception as e:
    print(f"  ERROR: {e}")
    results.append(("analyze_trends", {"error": str(e)[:200]}))

# ═══════════════════════════════════════════════════════════════
# STEP 7: Verify predictions generated
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 7: Verify predictions ===")
time.sleep(3)
r = run_sql("verify_predictions", "SELECT count(*)::text AS n FROM app.prep_topic_predictions")
n = r.get("rows", [{}])[0].get("n", "0") if r.get("rows") else "ERR"
print(f"  Predictions in DB: {n}")

if int(n) > 0:
    r2 = run_sql("top_predictions", """
        SELECT t.name AS topic, tp.probability_score, tp.concours_type,
               tp.last_appeared_year, LEFT(tp.reasoning, 100) AS reasoning
        FROM app.prep_topic_predictions tp
        JOIN app.prep_topics t ON t.id = tp.topic_id
        ORDER BY tp.probability_score DESC
        LIMIT 10
    """)
    if r2.get("rows"):
        print("  Top predictions:")
        for row in r2["rows"]:
            print(f"    [{row.get('probability_score','?')}%] {row.get('topic','?')} ({row.get('concours_type','?')}) — {row.get('reasoning','')[:80]}")

# Verify cron jobs
print("\n=== STEP 8: Verify cron jobs ===")
r = run_sql("verify_crons", "SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname LIKE '%prep%' ORDER BY jobid")
if r.get("rows"):
    for row in r["rows"]:
        print(f"  Job #{row['jobid']} | {row['jobname']} | {row['schedule']} | active={row['active']}")

# Verify question-topic links
print("\n=== STEP 9: Verify question-topic links ===")
r = run_sql("verify_tags", "SELECT count(*)::text AS n FROM app.prep_question_topics")
print(f"  Question-topic links: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else 'ERR'}")

# Save
out = pathlib.Path("logs/deploy_learning_machine.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(results, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
print(f"\n[OK] Log: {out}")
