#!/usr/bin/env python3
"""Simplify TD + Prep import RPCs:
- Phase A: Drop broken overloads
- Phase B: Rewrite remaining RPCs to be more tolerant + French error messages
- Phase C: Fix prep import subject_id resolution (auto-create if missing)

Uses admin_execute_sql.
"""

from __future__ import annotations
import json
from pathlib import Path
from datetime import datetime
from typing import Any, Dict
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}
    if isinstance(data, dict):
        rows = data.get("rows")
        return {"label": label, "http": resp.status_code, "ok": bool(data.get("ok")),
                "rows_count": len(rows) if isinstance(rows, list) else 0,
                "rows": rows if isinstance(rows, list) else [],
                "error": data.get("error"), "sqlstate": data.get("sqlstate")}
    if isinstance(data, list):
        return {"label": label, "http": resp.status_code, "ok": True,
                "rows_count": len(data), "rows": data, "error": None, "sqlstate": None}
    return {"label": label, "http": resp.status_code, "ok": False, "rows": [], "rows_count": 0, "error": "unexpected"}


# ── Phase A: Drop broken overloads ──────────────────────────────────

SQL_DROP_BROKEN_TD_IMPORT_JSON = """
DROP FUNCTION IF EXISTS public.app_td_admin_import_questions_json(jsonb, text, text, text, text);
"""

SQL_DROP_BROKEN_TD_IMPORT_TEXT = """
DROP FUNCTION IF EXISTS public.app_td_admin_import_text_bulk(text, text, text, text);
"""

# ── Phase B: Rewrite TD import JSON (more tolerant + FR errors) ─────

SQL_REWRITE_TD_IMPORT_JSON = """
CREATE OR REPLACE FUNCTION public.app_td_admin_import_questions_json(
    p_questions jsonb,
    p_subject text DEFAULT NULL,
    p_bank_id uuid DEFAULT NULL,
    p_source text DEFAULT 'admin_import'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_uid uuid;
    v_count integer := 0;
    v_skipped integer := 0;
    v_errors text[] := '{}';
    v_q jsonb;
    v_content text;
    v_options jsonb;
    v_correct_index integer;
    v_difficulty integer;
    v_explanation text;
    v_subject text;
    v_question_type text;
    i integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Vous devez être connecté pour importer des questions.');
    END IF;

    IF p_questions IS NULL OR jsonb_array_length(p_questions) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Le tableau de questions est vide.');
    END IF;

    FOR i IN 0..jsonb_array_length(p_questions) - 1 LOOP
        BEGIN
            v_q := p_questions->i;

            -- Accepter plusieurs clés pour le contenu de la question
            v_content := COALESCE(
                v_q->>'question',
                v_q->>'content',
                v_q->>'enonce',
                v_q->>'texte',
                ''
            );

            IF v_content = '' OR LENGTH(TRIM(v_content)) < 5 THEN
                v_skipped := v_skipped + 1;
                v_errors := array_append(v_errors,
                    format('Question %s : texte manquant ou trop court (clé "question" ou "content" requise)', i + 1));
                CONTINUE;
            END IF;

            -- Options : accepter tableau ou null
            v_options := v_q->'options';
            IF v_options IS NULL OR jsonb_typeof(v_options) != 'array' THEN
                v_options := '[]'::jsonb;
            END IF;

            -- correct_index : défaut 0
            v_correct_index := COALESCE((v_q->>'correct_index')::integer, (v_q->>'reponse_correcte')::integer, 0);

            -- difficulty : 1-5, défaut 2
            v_difficulty := COALESCE((v_q->>'difficulty')::integer, (v_q->>'difficulte')::integer, 2);
            IF v_difficulty < 1 THEN v_difficulty := 1; END IF;
            IF v_difficulty > 5 THEN v_difficulty := 5; END IF;

            -- explanation
            v_explanation := COALESCE(v_q->>'explanation', v_q->>'explication', v_q->>'correction');

            -- subject
            v_subject := COALESCE(p_subject, v_q->>'subject', v_q->>'matiere', 'Général');

            -- question_type
            v_question_type := COALESCE(v_q->>'question_type', v_q->>'type', 'mcq');
            IF v_question_type NOT IN ('mcq', 'qcm', 'open', 'true_false') THEN
                v_question_type := 'mcq';
            END IF;
            IF v_question_type = 'mcq' THEN v_question_type := 'qcm'; END IF;

            INSERT INTO app.td_questions (
                bank_id, question_type, content, options, correct_index,
                explanation, difficulty, subject, created_by, is_active
            ) VALUES (
                p_bank_id,
                v_question_type,
                TRIM(v_content),
                v_options,
                v_correct_index,
                v_explanation,
                v_difficulty,
                v_subject,
                v_uid,
                true
            );
            v_count := v_count + 1;

        EXCEPTION WHEN OTHERS THEN
            v_skipped := v_skipped + 1;
            v_errors := array_append(v_errors,
                format('Question %s : %s', i + 1, SQLERRM));
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'imported_count', v_count,
        'skipped_count', v_skipped,
        'total', jsonb_array_length(p_questions),
        'source', p_source,
        'errors', to_jsonb(v_errors)
    );
END;
$function$;
"""

# ── Phase B: Rewrite TD import text (simplified + FR errors) ────────

SQL_REWRITE_TD_IMPORT_TEXT = """
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
AS $function$
DECLARE
    v_uid uuid;
    v_doc_id uuid;
    v_chunks_count integer := 0;
    v_offset integer;
    v_idx integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Vous devez être connecté pour indexer du contenu.');
    END IF;

    IF p_text IS NULL OR LENGTH(TRIM(p_text)) < 20 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Le texte est trop court (minimum 20 caractères).');
    END IF;

    -- Créer le document source
    INSERT INTO app.td_source_documents (
        created_by, subject, university, study_year,
        doc_type, source_type, extracted_text, status
    ) VALUES (
        v_uid, p_subject, p_university, p_study_year,
        p_doc_type, 'text_paste', p_text, 'indexed'
    ) RETURNING id INTO v_doc_id;

    -- Premier chunk
    INSERT INTO app.td_doc_chunks (
        source_document_id, chunk_index, content,
        chunk_type, subject, university, study_year, token_count
    ) VALUES (
        v_doc_id, 0, LEFT(p_text, 4000),
        p_doc_type, p_subject, p_university, p_study_year,
        CEIL(LENGTH(p_text) / 4.0)::integer
    );
    v_chunks_count := 1;

    -- Chunks supplémentaires si texte long
    IF LENGTH(p_text) > 4000 THEN
        v_offset := 4000;
        v_idx := 1;
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
            v_chunks_count := v_chunks_count + 1;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'document_id', v_doc_id,
        'text_length', LENGTH(p_text),
        'chunks_count', v_chunks_count,
        'doc_type', p_doc_type,
        'message', format('Texte indexé avec succès : %s caractères en %s partie(s).', LENGTH(p_text), v_chunks_count)
    );
END;
$function$;
"""

# ── Phase C: Rewrite prep import JSON (tolerant + auto subject + FR) ─

SQL_REWRITE_PREP_IMPORT_JSON = """
CREATE OR REPLACE FUNCTION public.app_admin_prep_import_questions_json(
    p_questions jsonb,
    p_concours_type text DEFAULT NULL,
    p_subject_name text DEFAULT NULL,
    p_subject_id uuid DEFAULT NULL,
    p_source text DEFAULT 'admin_import'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_uid uuid;
    v_count integer := 0;
    v_skipped integer := 0;
    v_errors text[] := '{}';
    v_q jsonb;
    v_subject_id uuid;
    v_question_id uuid;
    v_options jsonb;
    v_correct_index integer;
    v_content text;
    v_difficulty integer;
    v_explanation text;
    v_question_type text;
    i integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Vous devez être connecté pour importer des questions.');
    END IF;

    IF p_questions IS NULL OR jsonb_array_length(p_questions) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Le tableau de questions est vide.');
    END IF;

    -- Résoudre le subject_id
    IF p_subject_id IS NOT NULL THEN
        v_subject_id := p_subject_id;
    ELSIF p_subject_name IS NOT NULL THEN
        SELECT id INTO v_subject_id
        FROM app.prep_subjects
        WHERE LOWER(title) = LOWER(p_subject_name)
        LIMIT 1;

        -- Auto-créer le sujet s'il n'existe pas
        IF v_subject_id IS NULL THEN
            INSERT INTO app.prep_subjects (slug, title)
            VALUES (
                LOWER(REPLACE(REPLACE(TRIM(p_subject_name), ' ', '-'), '''', '')),
                TRIM(p_subject_name)
            )
            RETURNING id INTO v_subject_id;
        END IF;
    END IF;

    -- Si toujours NULL, créer un sujet par défaut
    IF v_subject_id IS NULL THEN
        SELECT id INTO v_subject_id
        FROM app.prep_subjects
        WHERE LOWER(title) = 'culture générale'
        LIMIT 1;

        IF v_subject_id IS NULL THEN
            INSERT INTO app.prep_subjects (slug, title)
            VALUES ('culture-generale', 'Culture Générale')
            RETURNING id INTO v_subject_id;
        END IF;
    END IF;

    FOR i IN 0..jsonb_array_length(p_questions) - 1 LOOP
        BEGIN
            v_q := p_questions->i;

            -- Accepter plusieurs clés
            v_content := COALESCE(
                v_q->>'question',
                v_q->>'content',
                v_q->>'enonce',
                v_q->>'texte',
                ''
            );

            IF v_content = '' OR LENGTH(TRIM(v_content)) < 5 THEN
                v_skipped := v_skipped + 1;
                v_errors := array_append(v_errors,
                    format('Question %s : texte manquant ou trop court', i + 1));
                CONTINUE;
            END IF;

            v_options := v_q->'options';
            IF v_options IS NULL OR jsonb_typeof(v_options) != 'array' THEN
                v_options := '[]'::jsonb;
            END IF;

            v_correct_index := COALESCE((v_q->>'correct_index')::integer, (v_q->>'reponse_correcte')::integer, 0);

            v_difficulty := COALESCE((v_q->>'difficulty')::integer, (v_q->>'difficulte')::integer, 2);
            IF v_difficulty < 1 THEN v_difficulty := 1; END IF;
            IF v_difficulty > 5 THEN v_difficulty := 5; END IF;

            v_explanation := COALESCE(v_q->>'explanation', v_q->>'explication', v_q->>'correction');

            v_question_type := COALESCE(v_q->>'question_type', v_q->>'type', 'mcq');

            INSERT INTO app.prep_questions (
                subject_id, question, content, options, correct_index,
                explanation, difficulty, subject, concours_type,
                source, is_published, is_active, question_type
            ) VALUES (
                v_subject_id,
                TRIM(v_content),
                TRIM(v_content),
                v_options,
                v_correct_index,
                v_explanation,
                v_difficulty,
                COALESCE(p_subject_name, v_q->>'subject', v_q->>'matiere', 'Culture Générale'),
                p_concours_type,
                p_source,
                true,
                true,
                v_question_type
            ) RETURNING id INTO v_question_id;

            v_count := v_count + 1;

        EXCEPTION WHEN OTHERS THEN
            v_skipped := v_skipped + 1;
            v_errors := array_append(v_errors,
                format('Question %s : %s', i + 1, SQLERRM));
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'imported_count', v_count,
        'skipped_count', v_skipped,
        'total', jsonb_array_length(p_questions),
        'source', p_source,
        'subject_id', v_subject_id,
        'errors', to_jsonb(v_errors)
    );
END;
$function$;
"""

# ── Phase C: Rewrite prep import text (FR errors) ──────────────────

SQL_REWRITE_PREP_IMPORT_TEXT = """
CREATE OR REPLACE FUNCTION public.app_admin_prep_import_text_bulk(
    p_text text,
    p_concours_type text DEFAULT NULL,
    p_subject_name text DEFAULT NULL,
    p_doc_type text DEFAULT 'sujet'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_uid uuid;
    v_subject_id uuid;
    v_doc_id uuid;
    v_chunks_count integer := 0;
    v_offset integer;
    v_idx integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Vous devez être connecté pour indexer du contenu.');
    END IF;

    IF p_text IS NULL OR LENGTH(TRIM(p_text)) < 20 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Le texte est trop court (minimum 20 caractères).');
    END IF;

    -- Résoudre le subject_id
    IF p_subject_name IS NOT NULL THEN
        SELECT id INTO v_subject_id
        FROM app.prep_subjects
        WHERE LOWER(title) = LOWER(p_subject_name)
        LIMIT 1;
    END IF;

    -- Créer le document source
    INSERT INTO app.prep_source_documents (
        uploaded_by, subject_id, year, doc_type,
        source_type, extracted_text, concours_type, status
    ) VALUES (
        v_uid, v_subject_id, EXTRACT(YEAR FROM now())::integer,
        p_doc_type, 'text_paste', p_text, p_concours_type, 'indexed'
    ) RETURNING id INTO v_doc_id;

    -- Premier chunk
    INSERT INTO app.prep_doc_chunks (
        source_document_id, chunk_index, content,
        chunk_type, concours_type, subject_name, token_count
    ) VALUES (
        v_doc_id, 0, LEFT(p_text, 4000),
        p_doc_type, p_concours_type, p_subject_name,
        CEIL(LENGTH(p_text) / 4.0)::integer
    );
    v_chunks_count := 1;

    IF LENGTH(p_text) > 4000 THEN
        v_offset := 4000;
        v_idx := 1;
        WHILE v_offset < LENGTH(p_text) LOOP
            INSERT INTO app.prep_doc_chunks (
                source_document_id, chunk_index, content,
                chunk_type, concours_type, subject_name, token_count
            ) VALUES (
                v_doc_id, v_idx, SUBSTR(p_text, v_offset + 1, 4000),
                p_doc_type, p_concours_type, p_subject_name,
                LEAST(1000, CEIL((LENGTH(p_text) - v_offset) / 4.0))::integer
            );
            v_offset := v_offset + 4000;
            v_idx := v_idx + 1;
            v_chunks_count := v_chunks_count + 1;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'document_id', v_doc_id,
        'text_length', LENGTH(p_text),
        'chunks_count', v_chunks_count,
        'doc_type', p_doc_type,
        'message', format('Texte indexé avec succès : %s caractères en %s partie(s).', LENGTH(p_text), v_chunks_count)
    );
END;
$function$;
"""


def main() -> int:
    m = SupabaseAutoManager()
    results = {"timestamp": datetime.utcnow().isoformat() + "Z", "steps": {}}

    steps = [
        ("A1_drop_broken_td_import_json", SQL_DROP_BROKEN_TD_IMPORT_JSON),
        ("A2_drop_broken_td_import_text", SQL_DROP_BROKEN_TD_IMPORT_TEXT),
        ("B1_rewrite_td_import_json", SQL_REWRITE_TD_IMPORT_JSON),
        ("B2_rewrite_td_import_text", SQL_REWRITE_TD_IMPORT_TEXT),
        ("C1_rewrite_prep_import_json", SQL_REWRITE_PREP_IMPORT_JSON),
        ("C2_rewrite_prep_import_text", SQL_REWRITE_PREP_IMPORT_TEXT),
    ]

    all_ok = True
    for label, sql in steps:
        r = run_sql(m, label, sql)
        results["steps"][label] = r
        ok = r.get("ok", False)
        err = r.get("error")
        print(f"  {label}: ok={ok}" + (f" error={err}" if err else ""))
        if not ok:
            all_ok = False

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "deploy_simplify_import_rpcs.json"
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n[{'OK' if all_ok else 'PARTIAL'}] Saved {out_path.as_posix()}")

    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
