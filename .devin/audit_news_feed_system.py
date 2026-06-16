#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit complet du systeme d'actualites (prep-feed-actuality)."""
import json
import requests
import sys
import pathlib

sys.stdout.reconfigure(encoding='utf-8')

from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def sql(q):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": q.strip()},
        timeout=60
    ).json()
    return r

results = {}

# 1. Sources RSS
print("=== 1. SOURCES RSS ===")
r1 = sql("SELECT name, slug, feed_url, is_active, last_fetched_at, articles_count FROM app.prep_news_sources ORDER BY name")
results["sources"] = r1
if r1.get("rows"):
    for row in r1["rows"]:
        active = "+" if row.get("is_active") else "-"
        print(f"  [{active}] {row['name']} | slug={row['slug']} | last_fetch={row.get('last_fetched_at','JAMAIS')} | articles={row.get('articles_count',0)}")
else:
    print(f"  ERREUR ou VIDE: {json.dumps(r1, ensure_ascii=False)[:300]}")

# 2. Comptages separees
print("\n=== 2. COMPTAGES ===")
for label, query in [
    ("prep_news_sources", "SELECT count(*)::text AS n FROM app.prep_news_sources"),
    ("prep_news_articles", "SELECT count(*)::text AS n FROM app.prep_news_articles"),
    ("prep_doc_chunks (actualite)", "SELECT count(*)::text AS n FROM app.prep_doc_chunks WHERE chunk_type = 'actualite'"),
    ("prep_source_documents (actualite)", "SELECT count(*)::text AS n FROM app.prep_source_documents WHERE doc_type = 'actualite'"),
]:
    r = sql(query)
    n = r.get("rows", [{}])[0].get("n", "ERR") if r.get("rows") else f"ERR: {r.get('error','?')[:80]}"
    print(f"  {label}: {n}")
    results[f"count_{label}"] = n

# 3. Derniers articles injectes
print("\n=== 3. DERNIERS ARTICLES INJECTES ===")
r3 = sql("SELECT title, published_at, injected_at, content_length FROM app.prep_news_articles WHERE is_injected = true ORDER BY injected_at DESC LIMIT 5")
results["recent_articles"] = r3
if r3.get("rows"):
    for row in r3["rows"]:
        title = row.get("title", "?")[:80]
        print(f"  [{row.get('injected_at','?')}] {title} | len={row.get('content_length',0)}")
else:
    print("  AUCUN ARTICLE INJECTE")

# 4. Articles par source
print("\n=== 4. ARTICLES PAR SOURCE ===")
r4s = sql("SELECT s.name, s.slug, count(a.id)::text AS n FROM app.prep_news_sources s LEFT JOIN app.prep_news_articles a ON a.source_id = s.id GROUP BY s.name, s.slug ORDER BY s.name")
results["articles_by_source"] = r4s
if r4s.get("rows"):
    for row in r4s["rows"]:
        print(f"  {row['name']}: {row['n']} articles")

# 5. Cron jobs
print("\n=== 5. CRON JOBS ===")
r5 = sql("SELECT jobid, jobname, schedule, active FROM cron.job ORDER BY jobid")
results["cron_jobs"] = r5
if r5.get("rows"):
    for row in r5["rows"]:
        print(f"  Job #{row['jobid']} | {row['jobname']} | schedule={row['schedule']} | active={row['active']}")
else:
    print(f"  ERREUR ou AUCUN: {json.dumps(r5, ensure_ascii=False)[:300]}")

# 6. Dernieres executions cron (job 6 = prep-feed)
print("\n=== 6. CRON EXECUTIONS (dernieres 10) ===")
r6 = sql("SELECT jobid, start_time, end_time, status, return_message FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10")
results["cron_runs"] = r6
if r6.get("rows"):
    for row in r6["rows"]:
        msg = str(row.get("return_message", ""))[:120]
        print(f"  Job #{row.get('jobid')} | {row.get('start_time')} | status={row.get('status')} | {msg}")
else:
    print("  AUCUNE EXECUTION")

# 7. Chunks actualite recents
print("\n=== 7. CHUNKS ACTUALITE RECENTS ===")
r7 = sql("SELECT LEFT(content, 120) AS preview, created_at FROM app.prep_doc_chunks WHERE chunk_type = 'actualite' ORDER BY created_at DESC LIMIT 3")
results["recent_chunks"] = r7
if r7.get("rows"):
    for row in r7["rows"]:
        print(f"  [{row.get('created_at','?')}] {row.get('preview','')}")
else:
    print("  AUCUN CHUNK ACTUALITE")

# 8. Test Edge Function (appel reel)
print("\n=== 8. TEST EDGE FUNCTION (appel reel) ===")
try:
    ef_url = f"{m.url}/functions/v1/prep-feed-actuality"
    ef_resp = requests.post(ef_url, headers={
        "Authorization": f"Bearer {m.service_key}",
        "apikey": m.service_key,
        "Content-Type": "application/json"
    }, json={}, timeout=120)
    print(f"  HTTP {ef_resp.status_code}")
    try:
        d = ef_resp.json()
        print(f"  Response: {json.dumps(d, ensure_ascii=False)[:600]}")
        results["edge_function"] = {"status": ef_resp.status_code, "body": d}
    except Exception:
        print(f"  Raw: {ef_resp.text[:300]}")
        results["edge_function"] = {"status": ef_resp.status_code, "raw": ef_resp.text[:300]}
except Exception as e:
    print(f"  ERREUR: {e}")
    results["edge_function"] = {"error": str(e)}

# 9. RAG fallback test
print("\n=== 9. CHUNKS RAG ACTUALITES (subject_name) ===")
r9 = sql("SELECT count(*)::text AS n FROM app.prep_doc_chunks WHERE LOWER(subject_name) LIKE '%actualit%'")
n9 = r9.get("rows", [{}])[0].get("n", "ERR") if r9.get("rows") else "ERR"
print(f"  Chunks subject_name='Actualites...': {n9}")
results["rag_actualite_count"] = n9

# 10. Onglets Flutter Concours
print("\n=== 10. RESUME ===")
print("  Voir log JSON pour details complets")

# Save
out = pathlib.Path("logs/audit_news_feed_system.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(results, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
print(f"\n[OK] Log: {out}")
