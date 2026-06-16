#!/usr/bin/env python3
"""Remove Lefaso.net: disable source + delete all injected articles and chunks."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

def run_sql(label, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql", headers=m.headers, json={"p_sql": sql.strip()}, timeout=60).json()
    ok = r.get("ok", False)
    err = r.get("error")
    print(f"  {'✅' if ok else '❌'} {label}" + (f" — {err}" if err else ""))
    return r

# 1. Get lefaso source_id
r = run_sql("get lefaso id", "SELECT id FROM app.prep_news_sources WHERE slug = 'lefaso'")
lefaso_id = r.get("rows", [{}])[0].get("id") if r.get("rows") else None
print(f"  lefaso_id = {lefaso_id}")

if lefaso_id:
    # 2. Get all source_document_ids from lefaso articles
    r2 = run_sql("get doc ids", f"SELECT source_document_id FROM app.prep_news_articles WHERE source_id = '{lefaso_id}' AND source_document_id IS NOT NULL")
    doc_ids = [row["source_document_id"] for row in r2.get("rows", []) if row.get("source_document_id")]
    print(f"  {len(doc_ids)} documents to clean")

    # 3. Delete chunks for those documents
    if doc_ids:
        ids_str = ",".join(f"'{d}'" for d in doc_ids)
        run_sql("delete chunks", f"DELETE FROM app.prep_doc_chunks WHERE source_document_id IN ({ids_str})")
        run_sql("delete source docs", f"DELETE FROM app.prep_source_documents WHERE id IN ({ids_str})")

    # 4. Delete articles
    run_sql("delete articles", f"DELETE FROM app.prep_news_articles WHERE source_id = '{lefaso_id}'")

    # 5. Disable and delete source
    run_sql("delete source", f"DELETE FROM app.prep_news_sources WHERE id = '{lefaso_id}'")

# 6. Verify
print("\n=== Sources restantes ===")
r3 = run_sql("verify sources", "SELECT name, slug, is_active FROM app.prep_news_sources ORDER BY name")
for row in r3.get("rows", []):
    print(f"  [{'+' if row.get('is_active') else '-'}] {row['name']}")

r4 = run_sql("verify counts", """
    SELECT 'prep_doc_chunks' AS t, count(*) AS n FROM app.prep_doc_chunks
    UNION ALL SELECT 'prep_source_documents', count(*) FROM app.prep_source_documents
    UNION ALL SELECT 'prep_news_articles', count(*) FROM app.prep_news_articles
""")
for row in r4.get("rows", []):
    if isinstance(row, dict):
        print(f"  {row.get('t')}: {row.get('n')}")
