#!/usr/bin/env python3
"""Phase S1: Create td_doc_chunks + td_source_documents + RPCs + move 47 questions to td_questions."""
import requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql_raw(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    rows = body.get("rows", []) if ok else []
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok, rows

def sql(q, label=""): return sql_raw(" ".join(q.split()), label)

print("=" * 60)
print("PHASE S1 -- Separation TD: Tables + RPCs + Migration")
print("=" * 60)

# ═══════════════════════════════════════════════════════════════
# A: Create td_source_documents + td_doc_chunks (mirror of prep_*)
# ═══════════════════════════════════════════════════════════════
print("\n--- A: Tables RAG TD ---")

sql("CREATE TABLE IF NOT EXISTS app.td_source_documents (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), created_by UUID REFERENCES auth.users(id), subject TEXT, university TEXT, faculty TEXT, study_year TEXT, year INTEGER, doc_type TEXT, source_type TEXT DEFAULT 'pdf', storage_bucket TEXT DEFAULT 'prep-documents', storage_path TEXT, extracted_text TEXT, status TEXT DEFAULT 'received', concours_type TEXT, subject_name TEXT, original_filename TEXT, page_count INTEGER, extraction_method TEXT DEFAULT 'pdf-text', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_source_documents")

sql("CREATE TABLE IF NOT EXISTS app.td_doc_chunks (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), source_document_id UUID NOT NULL REFERENCES app.td_source_documents(id) ON DELETE CASCADE, chunk_index INTEGER, content TEXT, metadata JSONB, embedding vector(1536), chunk_type TEXT DEFAULT 'content', subject TEXT, university TEXT, study_year TEXT, token_count INTEGER, created_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_doc_chunks")

# Index HNSW for vector search
sql("CREATE INDEX IF NOT EXISTS idx_td_doc_chunks_embedding ON app.td_doc_chunks USING hnsw (embedding vector_cosine_ops)", "CREATE td_doc_chunks embedding index")

# ═══════════════════════════════════════════════════════════════
# B: RLS
# ═══════════════════════════════════════════════════════════════
print("\n--- B: RLS ---")

for t in ["td_source_documents", "td_doc_chunks"]:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

policies = [
    ("sr_all_td_source_documents", "td_source_documents", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_td_doc_chunks", "td_doc_chunks", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("auth_select_td_doc_chunks", "td_doc_chunks", "FOR SELECT TO public USING (auth.uid() IS NOT NULL)"),
    ("auth_select_td_source_documents", "td_source_documents", "FOR SELECT TO public USING (auth.uid() IS NOT NULL)"),
    ("admin_all_td_source_docs", "td_source_documents", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_td_doc_chunks", "td_doc_chunks", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
]

for pname, tname, clause in policies:
    sql(f"DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{tname}') THEN EXECUTE 'CREATE POLICY {pname} ON app.{tname} {clause}'; END IF; END $$;", f"policy {pname}")
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# C: RPCs for TD RAG (semantic search + document management)
# ═══════════════════════════════════════════════════════════════
print("\n--- C: RPCs TD RAG ---")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_semantic_search(
  p_query_embedding vector(1536), p_subject TEXT DEFAULT NULL,
  p_university TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 10, p_threshold FLOAT DEFAULT 0.3
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_result JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'not_authenticated'); END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result
  FROM (
    SELECT c.id, c.content, c.chunk_type, c.subject, c.university, c.study_year, c.metadata,
           d.id AS document_id, d.doc_type, d.original_filename,
           1 - (c.embedding <=> p_query_embedding) AS similarity
    FROM app.td_doc_chunks c JOIN app.td_source_documents d ON d.id = c.source_document_id
    WHERE c.embedding IS NOT NULL AND d.status IN ('indexed','validated','published')
      AND (p_subject IS NULL OR c.subject ILIKE '%' || p_subject || '%')
      AND (p_university IS NULL OR c.university ILIKE '%' || p_university || '%')
      AND 1 - (c.embedding <=> p_query_embedding) > p_threshold
    ORDER BY c.embedding <=> p_query_embedding LIMIT p_limit
  ) t;
  RETURN jsonb_build_object('success', true, 'chunks', COALESCE(v_result, '[]'::jsonb));
END; $$;""", "RPC app_td_semantic_search")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_admin_list_source_documents(p_subject TEXT DEFAULT NULL, p_status TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result
  FROM (SELECT * FROM app.td_source_documents
        WHERE (p_subject IS NULL OR subject ILIKE '%' || p_subject || '%')
          AND (p_status IS NULL OR status = p_status)) t;
  RETURN jsonb_build_object('success', true, 'documents', v_result);
END; $$;""", "RPC app_td_admin_list_source_documents")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_admin_set_source_document_status(p_document_id UUID, p_status TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
BEGIN
  UPDATE app.td_source_documents SET status = p_status, updated_at = now() WHERE id = p_document_id;
  RETURN jsonb_build_object('success', true);
END; $$;""", "RPC app_td_admin_set_source_document_status")

# ═══════════════════════════════════════════════════════════════
# D: Move 47 university questions from prep_questions to td_questions
# ═══════════════════════════════════════════════════════════════
print("\n--- D: Move university questions prep -> td ---")

# Get td_question_banks — create a university bank if needed
sql("INSERT INTO app.td_question_banks (title, description, is_active) SELECT 'Contenu Universitaire BF', 'Questions pedagogiques adaptees aux universites du Burkina Faso', true WHERE NOT EXISTS (SELECT 1 FROM app.td_question_banks WHERE title = 'Contenu Universitaire BF')", "Create td university bank")

ok, rows = sql_raw("SELECT id FROM app.td_question_banks WHERE title = 'Contenu Universitaire BF' LIMIT 1", "Get td bank ID")
td_bank_id = rows[0]["id"] if rows else None
print(f"  TD Bank ID: {td_bank_id}")

if td_bank_id:
    # Copy 47 questions from prep_questions (source='university_bf') to td_questions
    sql_raw(f"""INSERT INTO app.td_questions (bank_id, question_type, content, options, correct_index, explanation, difficulty, subject, tags, points, is_active)
SELECT '{td_bank_id}', question_type, content, options, correct_index, explanation, difficulty, subject, tags, COALESCE(points, 1), COALESCE(is_active, true)
FROM app.prep_questions WHERE source = 'university_bf'
ON CONFLICT DO NOTHING""", "Copy 47 questions to td_questions")

    # Delete from prep_questions
    sql("DELETE FROM app.prep_questions WHERE source = 'university_bf'", "Delete 47 from prep_questions")

# ═══════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════
print("\n--- VERIFICATION ---")
for t in ["td_source_documents", "td_doc_chunks"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")

sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('td_source_documents','td_doc_chunks')", "RLS count")
sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td%semantic%' OR routine_name LIKE 'app_td_admin%source%' ORDER BY routine_name", "TD RAG RPCs")

# Counts
sql("SELECT COUNT(*) AS cnt FROM app.td_questions", "td_questions total")
sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE source = 'university_bf'", "prep university remaining (should be 0)")
sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true", "prep total remaining")

print("\nPhase S1 complete!")
