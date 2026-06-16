#!/usr/bin/env python3
"""Test injecting a single article to diagnose the issue."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

def run_sql(sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    return resp.json()

# 1. Check subject_id
r = run_sql("SELECT id FROM app.prep_subjects WHERE slug = 'actualites_bf' LIMIT 1")
print("Subject:", json.dumps(r, indent=2)[:500])

# 2. Check news sources
r = run_sql("SELECT id, slug, name FROM app.prep_news_sources WHERE is_active LIMIT 5")
print("Sources:", json.dumps(r, indent=2)[:500])

# 3. Try a simple insert into prep_source_documents
r = run_sql("""
INSERT INTO app.prep_source_documents (
    doc_type, source_type, extracted_text,
    concours_type, subject_name, status, original_filename
) VALUES (
    'actualite', 'rss_feed',
    'Test article content for debugging',
    'TOUS', 'Actualités du Burkina Faso', 'indexed',
    'Test Article Title'
) RETURNING id
""")
print("Insert doc:", json.dumps(r, indent=2)[:500])

doc_id = None
if r.get("ok") and r.get("rows"):
    doc_id = r["rows"][0]["id"]
    print(f"  doc_id = {doc_id}")

    # 4. Try a chunk insert
    r2 = run_sql(f"""
    INSERT INTO app.prep_doc_chunks (
        source_document_id, chunk_index, content,
        chunk_type, concours_type, subject_name,
        token_count
    ) VALUES (
        '{doc_id}', 0,
        'Test chunk content for debugging purposes',
        'actualite', 'TOUS', 'Actualités du Burkina Faso',
        10
    ) RETURNING id
    """)
    print("Insert chunk:", json.dumps(r2, indent=2)[:500])

    # 5. Try insert into prep_news_articles with dollar quoting
    source_r = run_sql("SELECT id FROM app.prep_news_sources WHERE slug = 'lefaso' LIMIT 1")
    sid = source_r.get("rows", [{}])[0].get("id")
    if sid:
        r3 = run_sql(f"""
        INSERT INTO app.prep_news_articles (
            source_id, article_url, title, summary,
            categories, is_injected, injected_at,
            source_document_id, content_length
        ) VALUES (
            '{sid}',
            'https://test.example.com/test-article-123',
            'Test Article',
            'Test summary',
            ARRAY['Politique','Société']::text[],
            true, now(),
            '{doc_id}',
            100
        ) ON CONFLICT (article_url) DO NOTHING
        """)
        print("Insert article:", json.dumps(r3, indent=2)[:500])

    # 6. Cleanup test data
    if doc_id:
        run_sql(f"DELETE FROM app.prep_doc_chunks WHERE source_document_id = '{doc_id}'")
        run_sql(f"DELETE FROM app.prep_news_articles WHERE source_document_id = '{doc_id}'")
        run_sql(f"DELETE FROM app.prep_source_documents WHERE id = '{doc_id}'")
        print("Cleanup done.")
