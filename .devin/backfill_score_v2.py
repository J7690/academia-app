#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Backfill v2 - batch scoring via single DDL call (server-side loop)."""
import sys, json, requests, time
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def run_ddl(label, ddl_query, timeout=300):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers,
        json={"ddl_query": ddl_query.strip()},
        timeout=timeout
    ).json()
    ok = not (isinstance(r, dict) and r.get("code"))
    err = r.get("message") if isinstance(r, dict) else None
    status = "OK" if ok else "FAIL"
    print(f"  [{status}] {label}" + (f" -- {str(err)[:200]}" if err else ""))
    return r

def run_sql(label, sql_query, timeout=60):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql_query.strip()},
        timeout=timeout
    ).json()
    return r

# Create a server-side function that scores all unscored articles in one go
print("=== Step 1: Create batch scoring function ===")
batch_fn = """
CREATE OR REPLACE FUNCTION public.app_admin_backfill_article_scores(p_batch_size integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_art RECORD;
    v_score_result jsonb;
    v_scored integer := 0;
    v_relevant integer := 0;
BEGIN
    FOR v_art IN
        SELECT id, title, content, categories
        FROM app.prep_news_articles
        WHERE scored_at IS NULL
        ORDER BY published_at DESC NULLS LAST
        LIMIT p_batch_size
    LOOP
        v_score_result := public.app_prep_score_article_relevance(
            v_art.title,
            LEFT(v_art.content, 5000),
            v_art.categories
        );

        UPDATE app.prep_news_articles SET
            relevance_score = (v_score_result->>'score')::real,
            is_concours_relevant = (v_score_result->>'is_relevant')::boolean,
            scoring_reason = LEFT(v_score_result->>'reason', 500),
            scored_at = now()
        WHERE id = v_art.id;

        v_scored := v_scored + 1;
        IF (v_score_result->>'is_relevant')::boolean THEN
            v_relevant := v_relevant + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'scored', v_scored,
        'relevant', v_relevant,
        'remaining', (SELECT count(*) FROM app.prep_news_articles WHERE scored_at IS NULL)
    );
END;
$fn$;
"""
run_ddl("create_batch_fn", batch_fn)

# Run in batches of 100
print("\n=== Step 2: Run batch scoring ===")
total_scored = 0
total_relevant = 0

for i in range(10):  # Max 10 iterations = 1000 articles
    print(f"  Batch {i+1}...")
    r = run_sql(f"batch_{i+1}", "SELECT public.app_admin_backfill_article_scores(100) AS result")
    if r.get("rows"):
        result = r["rows"][0].get("result", {})
        if isinstance(result, str):
            result = json.loads(result)
        scored = result.get("scored", 0)
        relevant = result.get("relevant", 0)
        remaining = result.get("remaining", 0)
        total_scored += scored
        total_relevant += relevant
        print(f"    Scored: {scored} | Relevant: {relevant} | Remaining: {remaining}")
        if remaining == 0 or scored == 0:
            break
    else:
        print(f"    Error: {r.get('error','?')[:200]}")
        break
    time.sleep(1)

print(f"\n  Total scored: {total_scored} | Total relevant: {total_relevant}")

# Final stats
print("\n=== Step 3: Final stats ===")
r_stats = run_sql("final_stats", """
    SELECT
        count(*)::int AS total,
        count(*) FILTER (WHERE scored_at IS NOT NULL)::int AS scored,
        count(*) FILTER (WHERE is_concours_relevant = true)::int AS relevant,
        round(avg(relevance_score)::numeric, 3) AS avg_score,
        round(max(relevance_score)::numeric, 3) AS max_score
    FROM app.prep_news_articles
""")
if r_stats.get("rows"):
    s = r_stats["rows"][0]
    print(f"  Total: {s.get('total')} | Scored: {s.get('scored')} | Relevant: {s.get('relevant')}")
    print(f"  Avg score: {s.get('avg_score')} | Max: {s.get('max_score')}")

# Top 5
print("\n=== TOP 5 ===")
r_top = run_sql("top5", "SELECT LEFT(title, 80) AS t, relevance_score AS s FROM app.prep_news_articles WHERE is_concours_relevant = true ORDER BY relevance_score DESC LIMIT 5")
if r_top.get("rows"):
    for row in r_top["rows"]:
        print(f"  [{row.get('s',0)}] {row.get('t','?')}")

print("\n[OK] Done")
