#!/usr/bin/env python3
"""Deploy tables + RPCs for news feed system (actualités concours).
Creates:
1. app.prep_news_sources — RSS sources config
2. app.prep_news_articles — tracking injected articles (dedup)
3. RPCs: list sources, list articles, admin stats
4. Seed 3 sources: Lefaso.net, Sidwaya, RTB
"""

from __future__ import annotations
import json
from pathlib import Path
from datetime import datetime
from typing import Any, Dict
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 180) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}
    if isinstance(data, dict):
        return {"label": label, "ok": bool(data.get("ok")),
                "rows": data.get("rows", []), "error": data.get("error")}
    return {"label": label, "ok": False, "error": "unexpected"}


SQL_TABLES = """
-- 1. Table des sources RSS
CREATE TABLE IF NOT EXISTS app.prep_news_sources (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    slug text NOT NULL UNIQUE,
    feed_url text NOT NULL,
    website_url text,
    source_type text NOT NULL DEFAULT 'rss',
    is_active boolean NOT NULL DEFAULT true,
    categories_filter text[] DEFAULT '{}',
    last_fetched_at timestamptz,
    articles_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Table des articles injectés (dedup par URL)
CREATE TABLE IF NOT EXISTS app.prep_news_articles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id uuid NOT NULL REFERENCES app.prep_news_sources(id) ON DELETE CASCADE,
    article_url text NOT NULL,
    title text NOT NULL,
    summary text,
    content text,
    categories text[] DEFAULT '{}',
    published_at timestamptz,
    fetched_at timestamptz NOT NULL DEFAULT now(),
    injected_at timestamptz,
    chunk_id uuid,
    source_document_id uuid,
    is_injected boolean NOT NULL DEFAULT false,
    content_length integer DEFAULT 0,
    UNIQUE(article_url)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prep_news_articles_source ON app.prep_news_articles(source_id);
CREATE INDEX IF NOT EXISTS idx_prep_news_articles_injected ON app.prep_news_articles(is_injected);
CREATE INDEX IF NOT EXISTS idx_prep_news_articles_published ON app.prep_news_articles(published_at DESC);

-- RLS
ALTER TABLE app.prep_news_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_news_articles ENABLE ROW LEVEL SECURITY;

-- Service role full access
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='prep_news_sources' AND policyname='service_role_all_news_sources') THEN
        CREATE POLICY service_role_all_news_sources ON app.prep_news_sources FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='prep_news_articles' AND policyname='service_role_all_news_articles') THEN
        CREATE POLICY service_role_all_news_articles ON app.prep_news_articles FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;
"""

SQL_SEED_SOURCES = """
INSERT INTO app.prep_news_sources (name, slug, feed_url, website_url, source_type, categories_filter)
VALUES
    ('Lefaso.net', 'lefaso', 'https://lefaso.net/spip.php?page=backend', 'https://lefaso.net', 'rss', ARRAY['Politique','Société','Economie','Education','Santé']),
    ('Sidwaya', 'sidwaya', 'https://www.sidwaya.info/feed/', 'https://www.sidwaya.info', 'rss', ARRAY['ACTUALITES','POLITIQUE','ÉCONOMIE','SOCIÉTÉ','EDUCATION','SANTE']),
    ('RTB', 'rtb', 'https://www.rtb.bf/feed/', 'https://www.rtb.bf', 'rss', ARRAY['Infos','Politique','Economie','Société'])
ON CONFLICT (slug) DO UPDATE SET
    feed_url = EXCLUDED.feed_url,
    website_url = EXCLUDED.website_url,
    categories_filter = EXCLUDED.categories_filter,
    updated_at = now();
"""

SQL_RPC_LIST_NEWS_SOURCES = """
CREATE OR REPLACE FUNCTION public.app_admin_prep_list_news_sources()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN (
        SELECT COALESCE(jsonb_agg(row_to_json(s)::jsonb ORDER BY s.name), '[]'::jsonb)
        FROM app.prep_news_sources s
    );
END;
$function$;
"""

SQL_RPC_LIST_NEWS_ARTICLES = """
CREATE OR REPLACE FUNCTION public.app_admin_prep_list_news_articles(
    p_source_slug text DEFAULT NULL,
    p_only_injected boolean DEFAULT NULL,
    p_limit integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT a.id, a.title, a.article_url, a.summary,
               a.categories, a.published_at, a.fetched_at,
               a.is_injected, a.content_length,
               s.name AS source_name, s.slug AS source_slug
        FROM app.prep_news_articles a
        JOIN app.prep_news_sources s ON s.id = a.source_id
        WHERE (p_source_slug IS NULL OR s.slug = p_source_slug)
          AND (p_only_injected IS NULL OR a.is_injected = p_only_injected)
        ORDER BY a.published_at DESC NULLS LAST
        LIMIT GREATEST(1, LEAST(p_limit, 200))
    ) t;

    RETURN jsonb_build_object('success', true, 'articles', v_result);
END;
$function$;
"""

SQL_RPC_NEWS_STATS = """
CREATE OR REPLACE FUNCTION public.app_admin_prep_news_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_sources integer;
    v_articles integer;
    v_injected integer;
    v_last_fetch timestamptz;
BEGIN
    SELECT count(*) INTO v_sources FROM app.prep_news_sources WHERE is_active;
    SELECT count(*) INTO v_articles FROM app.prep_news_articles;
    SELECT count(*) INTO v_injected FROM app.prep_news_articles WHERE is_injected;
    SELECT max(last_fetched_at) INTO v_last_fetch FROM app.prep_news_sources;

    RETURN jsonb_build_object(
        'success', true,
        'active_sources', v_sources,
        'total_articles', v_articles,
        'injected_articles', v_injected,
        'last_fetch', v_last_fetch
    );
END;
$function$;
"""


def main() -> int:
    m = SupabaseAutoManager()
    results = {"timestamp": datetime.utcnow().isoformat() + "Z", "steps": []}

    steps = [
        ("create_tables", SQL_TABLES),
        ("seed_sources", SQL_SEED_SOURCES),
        ("rpc_list_sources", SQL_RPC_LIST_NEWS_SOURCES),
        ("rpc_list_articles", SQL_RPC_LIST_NEWS_ARTICLES),
        ("rpc_news_stats", SQL_RPC_NEWS_STATS),
    ]

    for label, sql in steps:
        r = run_sql(m, label, sql)
        results["steps"].append(r)
        status = "✅" if r.get("ok") else "❌"
        err = f" — {r.get('error')}" if r.get("error") else ""
        print(f"  {status} {label}{err}")

    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out = log_dir / "deploy_prep_news_tables.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n[OK] Saved {out.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
