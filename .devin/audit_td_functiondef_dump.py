#!/usr/bin/env python3
"""Dump pg_get_functiondef for TD ingestion/IA RPCs via admin_execute_sql.

Writes .windsurf/logs/audit_td_functiondef_dump.json

Goal: get exact SQL definitions for:
- app_td_admin_import_questions_json
- app_td_admin_import_text_bulk
- app_td_semantic_search
- app_td_admin_list_source_documents
- app_td_admin_set_source_document_status
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

    # Target RPCs – ingestion/IA TD
    targets: List[Dict[str, str]] = [
        {
            "label": "app_td_admin_import_questions_json",
            "regproc": "app_td_admin_import_questions_json(json,json,text)",
        },
        {
            "label": "app_td_admin_import_text_bulk",
            "regproc": "app_td_admin_import_text_bulk(text,text,text,text,text)",
        },
        {
            "label": "app_td_semantic_search",
            "regproc": "app_td_semantic_search(vector,text,text,integer,real)",
        },
        {
            "label": "app_td_admin_list_source_documents",
            "regproc": "app_td_admin_list_source_documents(text,text,text)",
        },
        {
            "label": "app_td_admin_set_source_document_status",
            "regproc": "app_td_admin_set_source_document_status(uuid,text)",
        },
    ]

    results: Dict[str, Any] = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "functions": {},
    }

    for t in targets:
        label = t["label"]
        regproc = t["regproc"]
        sql = f"""SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.oid::regprocedure::text = '{regproc}'"""
        results["functions"][label] = run_sql(m, label, sql)

    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_td_functiondef_dump.json"
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    print("[OK] Saved", out_path.as_posix())
    for k, v in results["functions"].items():
        ok = v.get("ok")
        cnt = v.get("rows_count")
        print(f"- {k}: ok={ok} rows={cnt}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
