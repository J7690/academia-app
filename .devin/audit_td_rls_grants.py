#!/usr/bin/env python3
"""Audit RLS policies and grants for TD ingestion/IA tables via admin_execute_sql.

Tables:
- td_source_documents
- td_doc_chunks
- td_questions
- td_question_banks
"""

from __future__ import annotations

import json
from pathlib import Path
from datetime import datetime
from typing import Any, Dict, List

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

    return {
        "label": label,
        "http": resp.status_code,
        "ok": False,
        "mode": None,
        "rows_count": 0,
        "rows": [],
        "error": "unexpected_json_type",
        "sqlstate": None,
    }


def main() -> int:
    m = SupabaseAutoManager()

    results: Dict[str, Any] = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "policies": {},
        "grants": {},
    }

    # 1) RLS policies
    sql_policies = """
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname='app' AND tablename IN ('td_source_documents','td_doc_chunks','td_questions','td_question_banks')
ORDER BY tablename, policyname
"""
    results["policies"]["rls"] = run_sql(m, "rls_policies", sql_policies)

    # 2) Grants
    sql_grants = """
SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema='app' AND table_name IN ('td_source_documents','td_doc_chunks','td_questions','td_question_banks')
ORDER BY table_name, grantee, privilege_type
"""
    results["grants"]["role_table_grants"] = run_sql(m, "role_table_grants", sql_grants)

    # 3) Sample column structure (for duplication reference)
    sql_cols = """
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name IN ('td_source_documents','td_doc_chunks','td_questions','td_question_banks')
ORDER BY table_name, ordinal_position
"""
    results["columns"] = run_sql(m, "columns", sql_cols)

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_td_rls_grants.json"
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    print("[OK] Saved", out_path.as_posix())
    for section in ["policies", "grants", "columns"]:
        ok = results[section].get("ok")
        cnt = results[section].get("rows_count")
        print(f"- {section}: ok={ok} rows={cnt}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
