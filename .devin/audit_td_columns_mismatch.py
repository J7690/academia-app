#!/usr/bin/env python3
"""Audit column structures of td_questions vs prep_questions, and td_doc_chunks vs prep_doc_chunks.
Also check which columns are NOT NULL without defaults (= mandatory for insert).
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

    # Full column details for ALL relevant tables
    tables = [
        'td_questions', 'td_doc_chunks', 'td_source_documents', 'td_question_banks',
        'prep_questions', 'prep_doc_chunks', 'prep_source_documents', 'prep_subjects',
    ]
    table_list = ",".join(f"'{t}'" for t in tables)

    sql_cols = f"""
SELECT c.table_name, c.column_name, c.data_type, c.udt_name,
       c.is_nullable, c.column_default, c.ordinal_position,
       c.character_maximum_length
FROM information_schema.columns c
WHERE c.table_schema = 'app' AND c.table_name IN ({table_list})
ORDER BY c.table_name, c.ordinal_position
"""
    results["columns"] = run_sql(m, "columns", sql_cols)

    # Mandatory columns (NOT NULL without auto-default)
    sql_mandatory = f"""
SELECT c.table_name, c.column_name, c.data_type, c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'app' AND c.table_name IN ({table_list})
  AND c.is_nullable = 'NO'
  AND (c.column_default IS NULL OR c.column_default NOT LIKE 'gen_random_uuid%%'
       AND c.column_default NOT LIKE 'now%%'
       AND c.column_default NOT LIKE 'true%%'
       AND c.column_default NOT LIKE 'false%%')
ORDER BY c.table_name, c.ordinal_position
"""
    results["mandatory_no_default"] = run_sql(m, "mandatory_no_default", sql_mandatory)

    # Specifically get prep_subjects structure (used by prep import RPCs)
    sql_prep_subjects = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'prep_subjects'
ORDER BY ordinal_position
"""
    results["prep_subjects_structure"] = run_sql(m, "prep_subjects_structure", sql_prep_subjects)

    # Check actual data in prep_subjects (to see what concours/matière values exist)
    sql_prep_subjects_data = """
SELECT id, title, concours_type, slug, is_active
FROM app.prep_subjects
ORDER BY concours_type, title
LIMIT 50
"""
    results["prep_subjects_data"] = run_sql(m, "prep_subjects_data", sql_prep_subjects_data)

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_td_columns_mismatch.json"
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    print("[OK] Saved", out_path.as_posix())
    for k, v in results.items():
        if k == "timestamp":
            continue
        print(f"  {k}: ok={v.get('ok')} rows={v.get('rows_count')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
