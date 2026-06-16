#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

def sql(q):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql", headers=m.headers, json={"p_sql": q.strip()}, timeout=30).json()
    return r.get("rows", [])

print("=== Row counts ===")
rows = sql("SELECT 'prep_doc_chunks' AS t, count(*) AS n FROM app.prep_doc_chunks UNION ALL SELECT 'prep_source_documents', count(*) FROM app.prep_source_documents UNION ALL SELECT 'prep_news_articles', count(*) FROM app.prep_news_articles UNION ALL SELECT 'prep_news_sources', count(*) FROM app.prep_news_sources")
if rows and isinstance(rows[0], dict):
    for row in rows:
        print(f"  {row.get('t')}: {row.get('n')}")
else:
    print(f"  Raw: {rows[:3]}")

print("\n=== Sample chunks (actualité) ===")
for row in sql("SELECT LEFT(content, 120) AS preview, chunk_type, subject_name FROM app.prep_doc_chunks WHERE chunk_type = 'actualite' ORDER BY created_at DESC LIMIT 3"):
    print(f"  [{row.get('chunk_type')}] {row.get('preview')}")

print("\n=== Cron jobs ===")
for row in sql("SELECT jobid, schedule, active FROM cron.job WHERE jobname LIKE '%prep%'"):
    print(f"  Job #{row['jobid']}: schedule={row['schedule']}, active={row['active']}")
