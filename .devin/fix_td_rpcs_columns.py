#!/usr/bin/env python3
"""Recréer les RPCs TD avec les VRAIS noms de colonnes des tables."""
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def deploy(m, name, sql):
    print(f"📦 {name}...")
    try:
        r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
            headers=m.headers, json={"ddl_query": sql}, timeout=30)
        if r.status_code == 200:
            print(f"   ✅ OK")
            return True
        else:
            print(f"   ❌ {r.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🔧 FIX RPCs TD — Colonnes corrigées\n")

    # td_questions colonnes réelles:
    #   id, bank_id, question_type, content, options, correct_index,
    #   explanation, difficulty, subject, tags, points, time_limit_seconds,
    #   image_url, created_by, is_active, created_at, updated_at
    # NOTE: pas de 'question', 'is_published', 'field_name', 'level', 'source'

    deploy(m, "FIX app_td_admin_import_questions_json", """
CREATE OR REPLACE FUNCTION public.app_td_admin_import_questions_json(
    p_questions jsonb,
    p_subject text DEFAULT NULL,
    p_bank_id uuid DEFAULT NULL,
    p_source text DEFAULT 'admin_import'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_count integer := 0;
    v_q jsonb;
    i integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;

    FOR i IN 0..jsonb_array_length(p_questions) - 1 LOOP
        v_q := p_questions->i;

        INSERT INTO app.td_questions (
            bank_id, question_type, content, options, correct_index,
            explanation, difficulty, subject, created_by, is_active
        ) VALUES (
            p_bank_id,
            COALESCE(v_q->>'question_type', 'mcq'),
            COALESCE(v_q->>'question', v_q->>'content', ''),
            v_q->'options',
            COALESCE((v_q->>'correct_index')::integer, 0),
            v_q->>'explanation',
            COALESCE((v_q->>'difficulty')::integer, 2),
            COALESCE(p_subject, v_q->>'subject', 'Général'),
            v_uid,
            true
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'imported_count', v_count,
        'source', p_source
    );
END;
$$
    """)
    time.sleep(0.2)

    # td_source_documents colonnes réelles:
    #   id, created_by, subject, university, faculty, study_year, year, doc_type,
    #   source_type, storage_bucket, storage_path, extracted_text, status,
    #   concours_type, subject_name, original_filename, page_count, extraction_method
    # td_doc_chunks colonnes réelles:
    #   id, source_document_id, chunk_index, content, metadata, embedding,
    #   chunk_type, subject, university, study_year, token_count

    deploy(m, "FIX app_td_admin_import_text_bulk", """
CREATE OR REPLACE FUNCTION public.app_td_admin_import_text_bulk(
    p_text text,
    p_subject text DEFAULT NULL,
    p_university text DEFAULT NULL,
    p_study_year text DEFAULT NULL,
    p_doc_type text DEFAULT 'exercice'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_doc_id uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;

    INSERT INTO app.td_source_documents (
        created_by, subject, university, study_year,
        doc_type, source_type, extracted_text, status
    ) VALUES (
        v_uid, p_subject, p_university, p_study_year,
        p_doc_type, 'text_paste', p_text, 'indexed'
    ) RETURNING id INTO v_doc_id;

    INSERT INTO app.td_doc_chunks (
        source_document_id, chunk_index, content,
        chunk_type, subject, university, study_year, token_count
    ) VALUES (
        v_doc_id, 0, LEFT(p_text, 4000),
        p_doc_type, p_subject, p_university, p_study_year,
        CEIL(LENGTH(p_text) / 4.0)::integer
    );

    IF LENGTH(p_text) > 4000 THEN
        DECLARE
            v_offset integer := 4000;
            v_idx integer := 1;
        BEGIN
            WHILE v_offset < LENGTH(p_text) LOOP
                INSERT INTO app.td_doc_chunks (
                    source_document_id, chunk_index, content,
                    chunk_type, subject, university, study_year, token_count
                ) VALUES (
                    v_doc_id, v_idx, SUBSTR(p_text, v_offset + 1, 4000),
                    p_doc_type, p_subject, p_university, p_study_year,
                    LEAST(1000, CEIL((LENGTH(p_text) - v_offset) / 4.0))::integer
                );
                v_offset := v_offset + 4000;
                v_idx := v_idx + 1;
            END LOOP;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'document_id', v_doc_id,
        'text_length', LENGTH(p_text),
        'doc_type', p_doc_type
    );
END;
$$
    """)
    time.sleep(0.2)

    # Permissions
    for rpc in ['app_td_admin_import_questions_json', 'app_td_admin_import_text_bulk']:
        deploy(m, f"GRANT {rpc}", f"GRANT EXECUTE ON FUNCTION public.{rpc} TO authenticated")

    deploy(m, "NOTIFY pgrst", "NOTIFY pgrst, 'reload schema'")
    time.sleep(2)

    print("\n✅ RPCs TD corrigées.\n")

if __name__ == "__main__":
    main()
