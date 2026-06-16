#!/usr/bin/env python3
"""Add AIB (Agence d'Information du Burkina) to prep_news_sources."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

def run_sql(sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql", headers=m.headers, json={"p_sql": sql.strip()}, timeout=30).json()
    return r

r = run_sql("""
INSERT INTO app.prep_news_sources (name, slug, feed_url, website_url, source_type, categories_filter)
VALUES (
    'AIB (Agence d''Information du Burkina)',
    'aib',
    'https://www.aib.media/?feed=rss2',
    'https://www.aib.media',
    'rss',
    ARRAY['DEPECHES','SOCIETE','ECONOMIE','POLITIQUE','DEVELOPPEMENT','EDUCATION','SANTE','SECURITE','FLASH INFOS','LA UNE AIB']
)
ON CONFLICT (slug) DO UPDATE SET
    feed_url = EXCLUDED.feed_url,
    website_url = EXCLUDED.website_url,
    categories_filter = EXCLUDED.categories_filter,
    is_active = true,
    updated_at = now()
""")
print(f"Insert AIB: ok={r.get('ok')} error={r.get('error')}")

# Verify
r2 = run_sql("SELECT name, slug, feed_url, is_active FROM app.prep_news_sources ORDER BY name")
for row in r2.get("rows", []):
    print(f"  [{'+' if row.get('is_active') else '-'}] {row['name']} — {row['slug']}")
