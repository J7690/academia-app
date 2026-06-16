#!/usr/bin/env python3
"""Audit complet Supabase pour aligner le système d'injection concours.
Interroge:
1. Toutes les RPCs prep/concours dans public schema (signatures + corps)
2. Colonnes réelles de toutes les tables prep_*
3. Contraintes FK, NOT NULL, defaults
4. Edge Functions prep existantes
5. Données existantes (counts) dans chaque table
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


def main() -> int:
    m = SupabaseAutoManager()
    results: Dict[str, Any] = {"timestamp": datetime.utcnow().isoformat() + "Z"}

    # 1. All prep RPCs in public schema — names, args, return types, full bodies
    sql_rpcs = """
SELECT p.proname AS function_name,
       pg_get_function_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS return_type,
       length(pg_get_functiondef(p.oid)) AS def_length,
       pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname LIKE '%prep%'
ORDER BY p.proname
"""
    results["prep_rpcs_public"] = run_sql(m, "prep_rpcs_public", sql_rpcs)

    # 2. All prep tables in app schema — full column definitions
    sql_tables = """
SELECT c.table_name, c.column_name, c.ordinal_position,
       c.data_type, c.udt_name, c.is_nullable,
       c.column_default, c.character_maximum_length
FROM information_schema.columns c
WHERE c.table_schema = 'app'
  AND c.table_name LIKE 'prep_%'
ORDER BY c.table_name, c.ordinal_position
"""
    results["prep_tables_columns"] = run_sql(m, "prep_tables_columns", sql_tables)

    # 3. FK constraints on prep tables
    sql_fk = """
SELECT tc.table_name, tc.constraint_name,
       kcu.column_name,
       ccu.table_name AS foreign_table_name,
       ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'app'
  AND tc.table_name LIKE 'prep_%'
ORDER BY tc.table_name, tc.constraint_name
"""
    results["prep_fk_constraints"] = run_sql(m, "prep_fk_constraints", sql_fk)

    # 4. Row counts for each prep table
    sql_counts = """
SELECT 'prep_subjects' AS tbl, count(*) AS cnt FROM app.prep_subjects
UNION ALL SELECT 'prep_questions', count(*) FROM app.prep_questions
UNION ALL SELECT 'prep_source_documents', count(*) FROM app.prep_source_documents
UNION ALL SELECT 'prep_doc_chunks', count(*) FROM app.prep_doc_chunks
"""
    results["prep_row_counts"] = run_sql(m, "prep_row_counts", sql_counts)

    # 5. Existing prep_subjects data
    sql_subjects = """
SELECT id, slug, title, is_active FROM app.prep_subjects ORDER BY title LIMIT 50
"""
    results["prep_subjects_data"] = run_sql(m, "prep_subjects_data", sql_subjects)

    # 6. Sample prep_questions to understand current data shape
    sql_sample_q = """
SELECT id, subject_id, question_type, level, source,
       LEFT(question, 80) AS question_preview,
       LEFT(content, 80) AS content_preview,
       options IS NOT NULL AS has_options,
       correct_index, difficulty, subject, concours_type,
       is_published, is_active, created_at
FROM app.prep_questions
ORDER BY created_at DESC
LIMIT 10
"""
    results["prep_questions_sample"] = run_sql(m, "prep_questions_sample", sql_sample_q)

    # 7. Check if prep_source_documents has uploaded_by or created_by
    sql_src_doc_cols = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'prep_source_documents'
ORDER BY ordinal_position
"""
    results["prep_source_documents_cols"] = run_sql(m, "prep_source_documents_cols", sql_src_doc_cols)

    # 8. Check which Edge Functions exist for prep
    sql_edge = """
SELECT proname AS function_name,
       pg_get_function_arguments(oid) AS args
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname LIKE 'app_admin_prep%'
ORDER BY proname
"""
    results["prep_admin_rpcs"] = run_sql(m, "prep_admin_rpcs", sql_edge)

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_prep_align.json"
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"[OK] Saved {out_path.as_posix()}")
    for k, v in results.items():
        if k == "timestamp":
            continue
        print(f"  {k}: ok={v.get('ok')} rows={v.get('rows_count')}" +
              (f" error={v.get('error')}" if v.get('error') else ""))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
