#!/usr/bin/env python3
"""Deploy: 
1. RPC app_prep_resolve_subject_id(p_subject_name) → uuid (needed for RAG fallback)
2. RPC app_prep_get_rag_chunks_by_name(p_subject_name) → jsonb (combines resolve + get_rag_chunks)
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
        return {"label": label, "http": resp.status_code, "ok": bool(data.get("ok")),
                "rows": data.get("rows", []), "error": data.get("error"), "sqlstate": data.get("sqlstate")}
    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected response"}


# This RPC takes a subject name text (like the tutor chat sends) and returns
# matching chunks from prep_doc_chunks via prep_source_documents, WITHOUT needing embeddings.
# It resolves subject_name → subject_id internally.
SQL_RAG_BY_NAME = """
CREATE OR REPLACE FUNCTION public.app_prep_get_rag_chunks_by_name(
    p_subject_name text DEFAULT NULL,
    p_concours_type text DEFAULT NULL,
    p_limit integer DEFAULT 8,
    p_max_chars integer DEFAULT 8000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_subject_id uuid;
    v_chunks jsonb;
BEGIN
    -- Resolve subject name → subject_id (fuzzy match)
    IF p_subject_name IS NOT NULL AND LENGTH(TRIM(p_subject_name)) > 0 THEN
        SELECT id INTO v_subject_id
        FROM app.prep_subjects
        WHERE LOWER(title) = LOWER(TRIM(p_subject_name))
           OR LOWER(slug) = LOWER(TRIM(p_subject_name))
           OR title ILIKE '%' || TRIM(p_subject_name) || '%'
        LIMIT 1;
    END IF;

    -- Get chunks from indexed/validated/published documents
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'content', x.content,
                'chunk_type', x.chunk_type,
                'concours_type', x.concours_type,
                'subject_name', x.subject_name,
                'doc_type', x.doc_type,
                'year', x.year
            )
        ),
        '[]'::jsonb
    )
    INTO v_chunks
    FROM (
        SELECT c.content, c.chunk_type, c.concours_type, c.subject_name,
               d.doc_type, d.year
        FROM app.prep_doc_chunks c
        JOIN app.prep_source_documents d ON d.id = c.source_document_id
        WHERE d.status IN ('indexed', 'validated', 'published')
          AND (v_subject_id IS NULL OR d.subject_id = v_subject_id)
          AND (p_concours_type IS NULL OR c.concours_type = p_concours_type
               OR d.concours_type = p_concours_type)
        ORDER BY d.updated_at DESC, c.chunk_index ASC
        LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 8), 20))
    ) x;

    RETURN jsonb_build_object(
        'success', true,
        'subject_id', v_subject_id,
        'chunks', COALESCE(v_chunks, '[]'::jsonb),
        'count', jsonb_array_length(COALESCE(v_chunks, '[]'::jsonb))
    );
END;
$function$;
"""


def main() -> int:
    m = SupabaseAutoManager()
    results = {"timestamp": datetime.utcnow().isoformat() + "Z", "steps": []}

    r = run_sql(m, "create_rag_by_name", SQL_RAG_BY_NAME)
    results["steps"].append(r)
    print(f"create_rag_by_name: ok={r.get('ok')}" + (f" error={r.get('error')}" if r.get('error') else ""))

    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out = log_dir / "deploy_prep_rag_fallback.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[OK] Saved {out.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
