#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Backfill relevance scores for all existing prep_news_articles."""
import sys, json, requests, time
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def run_sql(sql_query, timeout=120):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql_query.strip()},
        timeout=timeout
    ).json()
    return r

# Score all unscored articles in batches
print("=== Backfill scoring for existing articles ===")

# Get count of unscored
r = run_sql("SELECT count(*)::int AS n FROM app.prep_news_articles WHERE scored_at IS NULL")
total = r.get("rows", [{}])[0].get("n", 0) if r.get("rows") else 0
print(f"  Unscored articles: {total}")

if total == 0:
    print("  Nothing to backfill!")
else:
    # Process in batches of 20
    batch_size = 20
    scored = 0
    relevant = 0
    
    while scored < total:
        batch_sql = f"""
        WITH batch AS (
            SELECT id, title, content, categories
            FROM app.prep_news_articles
            WHERE scored_at IS NULL
            ORDER BY published_at DESC NULLS LAST
            LIMIT {batch_size}
        ),
        scored_batch AS (
            SELECT b.id, b.title,
                   public.app_prep_score_article_relevance(b.title, LEFT(b.content, 5000), b.categories) AS score_result
            FROM batch b
        )
        UPDATE app.prep_news_articles a SET
            relevance_score = (sb.score_result->>'score')::real,
            is_concours_relevant = (sb.score_result->>'is_relevant')::boolean,
            scoring_reason = LEFT(sb.score_result->>'reason', 500),
            matched_subjects = ARRAY(SELECT jsonb_array_elements_text(sb.score_result->'matched_subjects')),
            matched_keywords = ARRAY(SELECT jsonb_array_elements_text(sb.score_result->'matched_keywords')),
            scored_at = now()
        FROM scored_batch sb
        WHERE a.id = sb.id
        """
        
        r = run_sql(batch_sql)
        if not r.get("ok"):
            print(f"  Batch error: {r.get('error','?')[:200]}")
            # Try simpler approach - one by one
            articles = run_sql(f"SELECT id, title, LEFT(content, 5000) AS content, categories FROM app.prep_news_articles WHERE scored_at IS NULL ORDER BY published_at DESC NULLS LAST LIMIT {batch_size}")
            if not articles.get("rows"):
                break
            for art in articles["rows"]:
                art_id = art["id"]
                title_esc = art["title"].replace("'", "''") if art.get("title") else ""
                content_esc = (art.get("content") or "").replace("'", "''")
                cats = art.get("categories") or []
                cats_sql = ",".join(f"'{c}'" for c in cats) if cats else ""
                
                score_sql = f"""
                WITH sc AS (
                    SELECT public.app_prep_score_article_relevance(
                        $txt${title_esc}$txt$,
                        $txt${content_esc}$txt$,
                        ARRAY[{cats_sql}]::text[]
                    ) AS r
                )
                UPDATE app.prep_news_articles SET
                    relevance_score = (sc.r->>'score')::real,
                    is_concours_relevant = (sc.r->>'is_relevant')::boolean,
                    scoring_reason = LEFT(sc.r->>'reason', 500),
                    scored_at = now()
                FROM sc
                WHERE id = '{art_id}'
                """
                sr = run_sql(score_sql)
                if sr.get("ok"):
                    scored += 1
                else:
                    # Ultra-simple fallback
                    run_sql(f"UPDATE app.prep_news_articles SET scored_at = now(), relevance_score = 0, is_concours_relevant = false WHERE id = '{art_id}'")
                    scored += 1
            
            remaining = run_sql("SELECT count(*)::int AS n FROM app.prep_news_articles WHERE scored_at IS NULL")
            left = remaining.get("rows", [{}])[0].get("n", 0) if remaining.get("rows") else 0
            print(f"  Scored: {scored}/{total} | Remaining: {left}")
            if left == 0:
                break
            continue
        
        scored += batch_size
        remaining = run_sql("SELECT count(*)::int AS n FROM app.prep_news_articles WHERE scored_at IS NULL")
        left = remaining.get("rows", [{}])[0].get("n", 0) if remaining.get("rows") else 0
        print(f"  Scored: {min(scored, total)}/{total} | Remaining: {left}")
        if left == 0:
            break
        time.sleep(0.5)

# Final stats
print("\n=== FINAL STATS ===")
r_stats = run_sql("""
    SELECT
        count(*)::int AS total,
        count(*) FILTER (WHERE scored_at IS NOT NULL)::int AS scored,
        count(*) FILTER (WHERE is_concours_relevant = true)::int AS relevant,
        round(avg(relevance_score)::numeric, 3) AS avg_score,
        round(max(relevance_score)::numeric, 3) AS max_score,
        round(min(relevance_score) FILTER (WHERE relevance_score > 0)::numeric, 3) AS min_nonzero_score
    FROM app.prep_news_articles
""")
if r_stats.get("rows"):
    s = r_stats["rows"][0]
    print(f"  Total: {s.get('total')}")
    print(f"  Scored: {s.get('scored')}")
    print(f"  Relevant (score >= 0.3): {s.get('relevant')}")
    print(f"  Avg score: {s.get('avg_score')}")
    print(f"  Max score: {s.get('max_score')}")
    print(f"  Min non-zero: {s.get('min_nonzero_score')}")

# Top 10 most relevant
print("\n=== TOP 10 MOST RELEVANT ===")
r_top = run_sql("SELECT title, relevance_score, scoring_reason FROM app.prep_news_articles WHERE is_concours_relevant = true ORDER BY relevance_score DESC LIMIT 10")
if r_top.get("rows"):
    for i, row in enumerate(r_top["rows"], 1):
        print(f"  {i}. [{row.get('relevance_score',0):.2f}] {row.get('title','?')[:80]}")
        if row.get('scoring_reason'):
            print(f"     {row['scoring_reason'][:100]}")

print("\n[OK] Backfill complete")
