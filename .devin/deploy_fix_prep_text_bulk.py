#!/usr/bin/env python3
"""Fix app_admin_prep_import_text_bulk: uploaded_by → created_by
Also adds a success message field in the response."""

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
        return {"label": label, "http": resp.status_code, "ok": bool(data.get("ok")),
                "rows": data.get("rows", []), "error": data.get("error"), "sqlstate": data.get("sqlstate")}
    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected response"}


SQL_FIX_TEXT_BULK = """
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

    -- Créer le document source (colonne = created_by, PAS uploaded_by)
    INSERT INTO app.prep_source_documents (
        created_by, subject_id, year, doc_type,
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
        'message', 'Texte indexé avec succès (' || v_chunks_count || ' chunk(s), ' || LENGTH(p_text) || ' caractères).'
    );
END;
$function$;
"""


def main() -> int:
    m = SupabaseAutoManager()
    results = {"timestamp": datetime.utcnow().isoformat() + "Z", "steps": []}

    # Fix the RPC
    r = run_sql(m, "fix_prep_import_text_bulk", SQL_FIX_TEXT_BULK)
    results["steps"].append(r)
    print(f"fix_prep_import_text_bulk: ok={r.get('ok')}" + (f" error={r.get('error')}" if r.get('error') else ""))

    # Verify by checking the function definition
    verify_sql = """
    SELECT pg_get_functiondef(p.oid) AS def
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'app_admin_prep_import_text_bulk'
    """
    r2 = run_sql(m, "verify_fix", verify_sql)
    results["steps"].append(r2)
    if r2.get("ok") and r2.get("rows"):
        body = r2["rows"][0].get("def", "")
        has_created_by = "created_by" in body
        has_uploaded_by = "uploaded_by" in body
        results["verification"] = {
            "has_created_by": has_created_by,
            "has_uploaded_by": has_uploaded_by,
            "fix_applied": has_created_by and not has_uploaded_by
        }
        print(f"verify: created_by={has_created_by}, uploaded_by={has_uploaded_by}, fix_applied={has_created_by and not has_uploaded_by}")

    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out = log_dir / "deploy_fix_prep_text_bulk.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[OK] Saved {out.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
