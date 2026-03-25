#!/usr/bin/env python3
"""Phase 2: Deploy pgvector enrichment + new tables."""
import json, requests, time
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 2 — pgvector enrichment + new tables")
print("=" * 60)

# ═══════════════════════════════════════════════════════════════
# PART A: Enrich prep_doc_chunks with embedding + metadata
# ═══════════════════════════════════════════════════════════════
print("\n--- A: Enriching prep_doc_chunks ---")

columns_to_add = [
    ("embedding", "vector(1536)"),
    ("chunk_type", "TEXT DEFAULT 'content'"),
    ("concours_type", "TEXT"),
    ("subject_name", "TEXT"),
    ("year", "TEXT"),
    ("question_number", "INTEGER"),
    ("is_correction", "BOOLEAN DEFAULT false"),
    ("token_count", "INTEGER"),
]

for col, dtype in columns_to_add:
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema='app' AND table_name='prep_doc_chunks' AND column_name='{col}')
            THEN ALTER TABLE app.prep_doc_chunks ADD COLUMN {col} {dtype};
            END IF;
        END $$;
    """, f"ADD {col} to prep_doc_chunks")
    time.sleep(0.2)

# Index for vector similarity search
sql("""
    CREATE INDEX IF NOT EXISTS idx_prep_doc_chunks_embedding
    ON app.prep_doc_chunks USING hnsw (embedding vector_cosine_ops)
""", "CREATE embedding index (hnsw)")

# ═══════════════════════════════════════════════════════════════
# PART B: Enrich prep_source_documents with metadata
# ═══════════════════════════════════════════════════════════════
print("\n--- B: Enriching prep_source_documents ---")

src_cols = [
    ("concours_type", "TEXT"),
    ("subject_name", "TEXT"),
    ("original_filename", "TEXT"),
    ("page_count", "INTEGER"),
    ("extraction_method", "TEXT DEFAULT 'pdf-text'"),
    ("has_correction", "BOOLEAN DEFAULT false"),
]

for col, dtype in src_cols:
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema='app' AND table_name='prep_source_documents' AND column_name='{col}')
            THEN ALTER TABLE app.prep_source_documents ADD COLUMN {col} {dtype};
            END IF;
        END $$;
    """, f"ADD {col} to prep_source_documents")
    time.sleep(0.2)

# ═══════════════════════════════════════════════════════════════
# PART C: New tables — Topics, Predictions, AI Corrections
# ═══════════════════════════════════════════════════════════════
print("\n--- C: Creating new tables ---")

sql("""
    CREATE TABLE IF NOT EXISTS app.prep_topics (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL UNIQUE,
        category TEXT,
        description TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
""", "CREATE prep_topics")

sql("""
    CREATE TABLE IF NOT EXISTS app.prep_question_topics (
        question_id UUID NOT NULL REFERENCES app.prep_questions(id) ON DELETE CASCADE,
        topic_id UUID NOT NULL REFERENCES app.prep_topics(id) ON DELETE CASCADE,
        PRIMARY KEY (question_id, topic_id)
    )
""", "CREATE prep_question_topics")

sql("""
    CREATE TABLE IF NOT EXISTS app.prep_topic_predictions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        topic_id UUID NOT NULL REFERENCES app.prep_topics(id) ON DELETE CASCADE,
        concours_type TEXT NOT NULL,
        target_year TEXT NOT NULL,
        probability_score INTEGER,
        frequency_count INTEGER,
        last_appeared_year TEXT,
        cycle_years NUMERIC(3,1),
        reasoning TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE (topic_id, concours_type, target_year)
    )
""", "CREATE prep_topic_predictions")

sql("""
    CREATE TABLE IF NOT EXISTS app.prep_ai_corrections (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        student_id UUID NOT NULL REFERENCES auth.users(id),
        question_id UUID REFERENCES app.prep_questions(id),
        student_answer TEXT NOT NULL,
        is_correct BOOLEAN,
        ai_correction TEXT NOT NULL,
        ai_explanation TEXT,
        source_chunks UUID[],
        confidence_score FLOAT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
""", "CREATE prep_ai_corrections")

# ═══════════════════════════════════════════════════════════════
# PART D: RLS + Enable RLS on new tables
# ═══════════════════════════════════════════════════════════════
print("\n--- D: RLS policies ---")

new_tables_rls = [
    "prep_topics", "prep_question_topics", "prep_topic_predictions", "prep_ai_corrections"
]

for t in new_tables_rls:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

# service_role ALL
for t in new_tables_rls:
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='sr_all_{t}' AND tablename='{t}') THEN
                EXECUTE 'CREATE POLICY sr_all_{t} ON app.{t} FOR ALL TO service_role USING (true) WITH CHECK (true)';
            END IF;
        END $$;
    """, f"service_role ALL {t}")
    time.sleep(0.1)

# Authenticated SELECT on topics + predictions (public knowledge)
for t in ["prep_topics", "prep_topic_predictions"]:
    pname = f"auth_select_{t}"
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{t}') THEN
                EXECUTE 'CREATE POLICY {pname} ON app.{t} FOR SELECT TO public USING (auth.uid() IS NOT NULL)';
            END IF;
        END $$;
    """, f"auth SELECT {t}")
    time.sleep(0.1)

# question_topics — follow question visibility
sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='auth_select_prep_question_topics' AND tablename='prep_question_topics') THEN
            EXECUTE 'CREATE POLICY auth_select_prep_question_topics ON app.prep_question_topics FOR SELECT TO public USING (auth.uid() IS NOT NULL)';
        END IF;
    END $$;
""", "auth SELECT prep_question_topics")

# ai_corrections — own data only
sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='auth_select_own_corrections' AND tablename='prep_ai_corrections') THEN
            EXECUTE 'CREATE POLICY auth_select_own_corrections ON app.prep_ai_corrections FOR SELECT TO public USING (student_id = auth.uid())';
        END IF;
    END $$;
""", "auth SELECT own prep_ai_corrections")

sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='auth_insert_own_corrections' AND tablename='prep_ai_corrections') THEN
            EXECUTE 'CREATE POLICY auth_insert_own_corrections ON app.prep_ai_corrections FOR INSERT TO public WITH CHECK (student_id = auth.uid())';
        END IF;
    END $$;
""", "auth INSERT own prep_ai_corrections")

# Admin ALL on predictions + topics (admin manages content)
for t in ["prep_topics", "prep_topic_predictions"]:
    pname = f"admin_all_{t}"
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{t}') THEN
                EXECUTE 'CREATE POLICY {pname} ON app.{t} FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))';
            END IF;
        END $$;
    """, f"admin ALL {t}")
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# PART E: Semantic search RPC
# ═══════════════════════════════════════════════════════════════
print("\n--- E: Semantic search RPC ---")

sql("""
    CREATE OR REPLACE FUNCTION public.app_prep_semantic_search(
        p_query_embedding vector(1536),
        p_subject_id UUID DEFAULT NULL,
        p_concours_type TEXT DEFAULT NULL,
        p_limit INTEGER DEFAULT 10,
        p_threshold FLOAT DEFAULT 0.3
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE
        v_result JSONB;
    BEGIN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
        END IF;

        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT
                c.id,
                c.content,
                c.chunk_type,
                c.concours_type,
                c.subject_name,
                c.year,
                c.question_number,
                c.is_correction,
                c.metadata,
                d.id AS document_id,
                d.doc_type,
                d.original_filename,
                1 - (c.embedding <=> p_query_embedding) AS similarity
            FROM app.prep_doc_chunks c
            JOIN app.prep_source_documents d ON d.id = c.source_document_id
            WHERE c.embedding IS NOT NULL
              AND d.status IN ('indexed', 'validated', 'published')
              AND (p_subject_id IS NULL OR d.subject_id = p_subject_id)
              AND (p_concours_type IS NULL OR c.concours_type = p_concours_type)
              AND 1 - (c.embedding <=> p_query_embedding) > p_threshold
            ORDER BY c.embedding <=> p_query_embedding
            LIMIT p_limit
        ) t;

        RETURN jsonb_build_object('success', true, 'chunks', COALESCE(v_result, '[]'::jsonb));
    END;
    $fn$;
""", "CREATE app_prep_semantic_search")

# ═══════════════════════════════════════════════════════════════
# PART F: Topic predictions RPC (read)
# ═══════════════════════════════════════════════════════════════
print("\n--- F: Predictions RPC ---")

sql("""
    CREATE OR REPLACE FUNCTION public.app_prep_get_predictions(
        p_concours_type TEXT DEFAULT NULL,
        p_target_year TEXT DEFAULT NULL,
        p_min_score INTEGER DEFAULT 50,
        p_limit INTEGER DEFAULT 20
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE
        v_result JSONB;
    BEGIN
        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.probability_score DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT
                tp.id AS prediction_id,
                t.name AS topic_name,
                t.category AS topic_category,
                tp.concours_type,
                tp.target_year,
                tp.probability_score,
                tp.frequency_count,
                tp.last_appeared_year,
                tp.cycle_years,
                tp.reasoning
            FROM app.prep_topic_predictions tp
            JOIN app.prep_topics t ON t.id = tp.topic_id
            WHERE (p_concours_type IS NULL OR tp.concours_type = p_concours_type)
              AND (p_target_year IS NULL OR tp.target_year = p_target_year)
              AND tp.probability_score >= p_min_score
            LIMIT p_limit
        ) t;

        RETURN jsonb_build_object('success', true, 'predictions', COALESCE(v_result, '[]'::jsonb));
    END;
    $fn$;
""", "CREATE app_prep_get_predictions")

# ═══════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════
print("\n--- VERIFICATION ---")

sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_doc_chunks' ORDER BY ordinal_position", "prep_doc_chunks final columns")
sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_source_documents' ORDER BY ordinal_position", "prep_source_documents final columns")

for t in ["prep_topics", "prep_question_topics", "prep_topic_predictions", "prep_ai_corrections"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t} exists?")

sql("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_prep_semantic_search', 'app_prep_get_predictions') ORDER BY routine_name", "New RPCs exist?")

# Count total RLS policies on new tables
sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('prep_topics','prep_question_topics','prep_topic_predictions','prep_ai_corrections')", "RLS count on new tables")

print("\n✅ Phase 2 deployment complete!")
