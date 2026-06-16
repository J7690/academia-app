#!/usr/bin/env python3
"""Déployer tables + RPCs pour le scan TD étudiant et l'import admin 0 token."""
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
        elif 'already exists' in r.text.lower():
            print(f"   ⚠️  Existe déjà")
            return True
        else:
            print(f"   ❌ {r.text[:150]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🚀 DÉPLOIEMENT TD — Scan + Import sans token\n")

    # 1. Table td_scan_logs
    deploy(m, "Table td_scan_logs", """
CREATE TABLE IF NOT EXISTS app.td_scan_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    extracted_text text,
    solutions text,
    field_name text,
    level text,
    created_at timestamptz DEFAULT now()
)
    """)
    time.sleep(0.2)

    deploy(m, "Index td_scan_logs", 
        "CREATE INDEX IF NOT EXISTS idx_td_scan_logs_student ON app.td_scan_logs(student_id, created_at DESC)")
    deploy(m, "RLS td_scan_logs", "ALTER TABLE app.td_scan_logs ENABLE ROW LEVEL SECURITY")
    time.sleep(0.2)

    # 2. Bucket td-documents
    deploy(m, "Bucket td-documents", """
INSERT INTO storage.buckets (id, name, public) VALUES ('td-documents', 'td-documents', false)
ON CONFLICT (id) DO NOTHING
    """)
    time.sleep(0.2)

    # 3. RPC import JSON sans token pour TD
    deploy(m, "RPC app_td_admin_import_questions_json (public)", """
CREATE OR REPLACE FUNCTION public.app_td_admin_import_questions_json(
    p_questions jsonb,
    p_field_name text DEFAULT NULL,
    p_level text DEFAULT NULL,
    p_subject text DEFAULT NULL,
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
    v_options jsonb;
    v_correct_index integer;
    i integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;

    FOR i IN 0..jsonb_array_length(p_questions) - 1 LOOP
        v_q := p_questions->i;
        v_options := v_q->'options';
        v_correct_index := COALESCE((v_q->>'correct_index')::integer, 0);

        INSERT INTO app.td_questions (
            question, options, correct_index,
            explanation, difficulty, subject,
            field_name, level, source,
            is_published, is_active
        ) VALUES (
            COALESCE(v_q->>'question', ''),
            v_options,
            v_correct_index,
            v_q->>'explanation',
            COALESCE((v_q->>'difficulty')::integer, 2),
            COALESCE(p_subject, v_q->>'subject', 'Général'),
            p_field_name,
            p_level,
            p_source,
            true,
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

    # 4. RPC import texte brut pour TD
    deploy(m, "RPC app_td_admin_import_text_bulk (public)", """
CREATE OR REPLACE FUNCTION public.app_td_admin_import_text_bulk(
    p_text text,
    p_field_name text DEFAULT NULL,
    p_level text DEFAULT NULL,
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
        uploaded_by, doc_type, source_type,
        extracted_text, status, field_name, level
    ) VALUES (
        v_uid, p_doc_type, 'text_paste',
        p_text, 'indexed', p_field_name, p_level
    ) RETURNING id INTO v_doc_id;

    INSERT INTO app.td_doc_chunks (
        source_document_id, chunk_index, content,
        chunk_type, field_name, level, token_count
    ) VALUES (
        v_doc_id, 0, LEFT(p_text, 4000),
        p_doc_type, p_field_name, p_level,
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
                    chunk_type, field_name, level, token_count
                ) VALUES (
                    v_doc_id, v_idx, SUBSTR(p_text, v_offset + 1, 4000),
                    p_doc_type, p_field_name, p_level,
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

    # 5. Permissions
    for rpc in ['app_td_admin_import_questions_json', 'app_td_admin_import_text_bulk']:
        deploy(m, f"GRANT {rpc}", f"GRANT EXECUTE ON FUNCTION public.{rpc} TO authenticated")
        time.sleep(0.1)

    # 6. NOTIFY PostgREST reload
    deploy(m, "NOTIFY pgrst reload", "NOTIFY pgrst, 'reload schema'")
    time.sleep(2)

    # 7. Vérification
    print("\n🔍 Vérification API REST...")
    for rpc in ['app_td_admin_import_questions_json', 'app_td_admin_import_text_bulk']:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json={}, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            print(f"  {icon} {rpc} → {code}")
        except:
            print(f"  ❌ {rpc} → ERREUR")

    print("\n✅ Déploiement TD terminé.\n")

if __name__ == "__main__":
    main()
