#!/usr/bin/env python3
"""Deep audit of ALL TD + Prep import RPCs: full SQL definitions, parameter types, constraints.

Uses admin_execute_sql to search by function name pattern (no regprocedure guessing).
Saves to .windsurf/logs/audit_td_import_deep.json
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
        return {
            "label": label,
            "http": resp.status_code,
            "ok": bool(data.get("ok")),
            "mode": data.get("mode"),
            "rows_count": len(rows) if isinstance(rows, list) else 0,
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {
            "label": label,
            "http": resp.status_code,
            "ok": True,
            "mode": "select",
            "rows_count": len(data),
            "rows": data,
            "error": None,
            "sqlstate": None,
        }

    return {"label": label, "http": resp.status_code, "ok": False, "rows": [], "rows_count": 0, "error": "unexpected"}


def main() -> int:
    m = SupabaseAutoManager()
    results: Dict[str, Any] = {"timestamp": datetime.utcnow().isoformat() + "Z"}

    # 1) List ALL import-related functions (TD + Prep) with their full signatures
    sql_list = """
SELECT p.proname AS name,
       n.nspname AS schema,
       pg_get_function_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS returns,
       p.prosecdef AS security_definer,
       p.provolatile AS volatility,
       length(pg_get_functiondef(p.oid)) AS def_length
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (   p.proname LIKE '%import%'
       OR p.proname LIKE '%semantic_search%'
       OR p.proname LIKE '%source_document%'
       OR p.proname LIKE '%ingest%'
       OR p.proname LIKE '%prep_import%'
       OR p.proname LIKE '%prep_text%')
ORDER BY p.proname
"""
    results["all_import_functions"] = run_sql(m, "all_import_functions", sql_list)

    # 2) Get FULL definitions for each known RPC by name (no regprocedure)
    target_names = [
        "app_td_admin_import_questions_json",
        "app_td_admin_import_text_bulk",
        "app_td_semantic_search",
        "app_td_admin_list_source_documents",
        "app_td_admin_set_source_document_status",
        "app_admin_prep_import_questions_json",
        "app_admin_prep_import_text_bulk",
    ]

    results["definitions"] = {}
    for name in target_names:
        sql = f"""SELECT pg_get_functiondef(p.oid) AS ddl,
                         pg_get_function_arguments(p.oid) AS args,
                         pg_get_function_result(p.oid) AS returns
                  FROM pg_proc p
                  JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'public' AND p.proname = '{name}'"""
        results["definitions"][name] = run_sql(m, name, sql)

    # 3) Check table constraints (CHECK, NOT NULL, FK) on target tables
    sql_constraints = """
SELECT tc.table_name, tc.constraint_name, tc.constraint_type,
       cc.check_clause,
       kcu.column_name
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc
  ON cc.constraint_name = tc.constraint_name AND cc.constraint_schema = tc.table_schema
LEFT JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
WHERE tc.table_schema = 'app'
  AND tc.table_name IN ('td_questions','td_source_documents','td_doc_chunks','td_question_banks',
                         'prep_questions','prep_source_documents','prep_doc_chunks')
ORDER BY tc.table_name, tc.constraint_name
"""
    results["table_constraints"] = run_sql(m, "table_constraints", sql_constraints)

    # 4) Check triggers on the tables
    sql_triggers = """
SELECT event_object_table AS table_name,
       trigger_name,
       event_manipulation,
       action_timing,
       action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'app'
  AND event_object_table IN ('td_questions','td_source_documents','td_doc_chunks','td_question_banks',
                              'prep_questions','prep_source_documents','prep_doc_chunks')
ORDER BY event_object_table, trigger_name
"""
    results["triggers"] = run_sql(m, "triggers", sql_triggers)

    # 5) Check indexes (especially vector indexes for embeddings)
    sql_indexes = """
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'app'
  AND tablename IN ('td_doc_chunks','td_questions','td_source_documents',
                     'prep_doc_chunks','prep_questions','prep_source_documents')
ORDER BY tablename, indexname
"""
    results["indexes"] = run_sql(m, "indexes", sql_indexes)

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_td_import_deep.json"
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    print("[OK] Saved", out_path.as_posix())
    for section in ["all_import_functions", "table_constraints", "triggers", "indexes"]:
        r = results.get(section, {})
        print(f"  {section}: ok={r.get('ok')} rows={r.get('rows_count')}")
    print("  definitions:")
    for name, r in results.get("definitions", {}).items():
        print(f"    {name}: ok={r.get('ok')} rows={r.get('rows_count')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
