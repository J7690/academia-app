#!/usr/bin/env python3
"""Migration cache sémantique Bobodo — statements séparés explicitement."""
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

def exec_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=60)
    if r.status_code != 200:
        print(f"  ❌ [{label}] HTTP {r.status_code}: {r.text[:300]}")
        return False
    data = r.json()
    if isinstance(data, dict) and "error" in data:
        print(f"  ❌ [{label}] {data['error'][:200]}")
        return False
    print(f"  ✅ [{label}]")
    return True

def main():
    m = SupabaseAutoManager()
    print("\n🚀 MIGRATION CACHE SÉMANTIQUE BOBODO v2\n")

    # ── 1. Table ─────────────────────────────────────────────────────────
    exec_sql(m, "CREATE TABLE bobodo_answer_cache", """
CREATE TABLE IF NOT EXISTS app.bobodo_answer_cache (
  id                 uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text      text         NOT NULL,
  question_embedding vector(1536) NULL,
  answer_text        text         NOT NULL,
  category           text         NULL,
  hit_count          integer      NOT NULL DEFAULT 1,
  created_at         timestamptz  NOT NULL DEFAULT now(),
  last_hit_at        timestamptz  NOT NULL DEFAULT now(),
  expires_at         timestamptz  NOT NULL DEFAULT (now() + interval '60 days')
)
""")

    # ── 2. Index vectoriel ───────────────────────────────────────────────
    exec_sql(m, "CREATE INDEX ivfflat embedding", """
CREATE INDEX IF NOT EXISTS idx_bobodo_answer_cache_embedding
  ON app.bobodo_answer_cache
  USING ivfflat (question_embedding vector_cosine_ops)
  WITH (lists = 10)
""")

    exec_sql(m, "CREATE INDEX expires_at", """
CREATE INDEX IF NOT EXISTS idx_bobodo_answer_cache_expires
  ON app.bobodo_answer_cache (expires_at)
""")

    # ── 3. RLS ───────────────────────────────────────────────────────────
    exec_sql(m, "ENABLE ROW LEVEL SECURITY", """
ALTER TABLE app.bobodo_answer_cache ENABLE ROW LEVEL SECURITY
""")

    exec_sql(m, "RLS policy read", """
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename  = 'bobodo_answer_cache'
      AND policyname = 'cache_select_authenticated'
  ) THEN
    EXECUTE 'CREATE POLICY cache_select_authenticated
      ON app.bobodo_answer_cache FOR SELECT
      TO authenticated USING (true)';
  END IF;
END
$do$
""")

    # ── 4. RPC search ────────────────────────────────────────────────────
    exec_sql(m, "RPC app_search_bobodo_answer_cache", """
CREATE OR REPLACE FUNCTION app.app_search_bobodo_answer_cache(
  p_query_embedding vector(1536),
  p_threshold       float DEFAULT 0.92
)
RETURNS TABLE (
  cache_id   uuid,
  answer     text,
  category   text,
  hit_count  integer,
  similarity float
)
LANGUAGE sql
SECURITY DEFINER
AS $func$
  SELECT
    c.id,
    c.answer_text,
    c.category,
    c.hit_count,
    (1 - (c.question_embedding <=> p_query_embedding))::float
  FROM app.bobodo_answer_cache c
  WHERE
    c.expires_at > now()
    AND c.question_embedding IS NOT NULL
    AND (1 - (c.question_embedding <=> p_query_embedding)) >= p_threshold
  ORDER BY c.question_embedding <=> p_query_embedding
  LIMIT 1
$func$
""")

    # ── 5. RPC cache hit ─────────────────────────────────────────────────
    exec_sql(m, "RPC app_bobodo_cache_hit", """
CREATE OR REPLACE FUNCTION app.app_bobodo_cache_hit(p_cache_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $func$
  UPDATE app.bobodo_answer_cache
  SET hit_count   = hit_count + 1,
      last_hit_at = now(),
      expires_at  = GREATEST(expires_at, now() + interval '30 days')
  WHERE id = p_cache_id
$func$
""")

    # ── 6. RPC insert ────────────────────────────────────────────────────
    exec_sql(m, "RPC app_insert_bobodo_answer_cache", """
CREATE OR REPLACE FUNCTION app.app_insert_bobodo_answer_cache(
  p_question_text      text,
  p_question_embedding vector(1536),
  p_answer_text        text,
  p_category           text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $func$
  INSERT INTO app.bobodo_answer_cache
    (question_text, question_embedding, answer_text, category)
  VALUES
    (p_question_text, p_question_embedding, p_answer_text, p_category)
$func$
""")

    # ── 7. RPC stats admin ───────────────────────────────────────────────
    exec_sql(m, "RPC app_admin_bobodo_cache_stats", """
CREATE OR REPLACE FUNCTION app.app_admin_bobodo_cache_stats()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
AS $func$
  SELECT jsonb_build_object(
    'total_entries',   COUNT(*),
    'total_hits',      COALESCE(SUM(hit_count), 0),
    'active_entries',  COUNT(*) FILTER (WHERE expires_at > now()),
    'expired_entries', COUNT(*) FILTER (WHERE expires_at <= now()),
    'top_questions', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'question', question_text,
          'hits',     hit_count,
          'category', category
        ) ORDER BY hit_count DESC
      )
      FROM (
        SELECT question_text, hit_count, category
        FROM app.bobodo_answer_cache
        ORDER BY hit_count DESC LIMIT 10
      ) top
    )
  )
  FROM app.bobodo_answer_cache
$func$
""")

    # ── Vérification ─────────────────────────────────────────────────────
    print("\n📋 VÉRIFICATION")
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    checks = [
        ("Table bobodo_answer_cache",
         "SELECT COUNT(*) AS n FROM information_schema.tables "
         "WHERE table_schema='app' AND table_name='bobodo_answer_cache'"),
        ("RPC app_search_bobodo_answer_cache",
         "SELECT 1 FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_search_bobodo_answer_cache'"),
        ("RPC app_bobodo_cache_hit",
         "SELECT 1 FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_bobodo_cache_hit'"),
        ("RPC app_insert_bobodo_answer_cache",
         "SELECT 1 FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_insert_bobodo_answer_cache'"),
        ("RPC app_admin_bobodo_cache_stats",
         "SELECT 1 FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_admin_bobodo_cache_stats'"),
    ]
    for label, sql in checks:
        r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=30)
        data = r.json() if r.status_code == 200 else []
        ok = bool(data and data[0] and (data[0].get('n', 0) or data[0].get('?column?') or list(data[0].values())[0]))
        print(f"  {'✅' if ok else '❌'} {label}")

    print("\n✅ Migration terminée.\n")

if __name__ == "__main__":
    main()
