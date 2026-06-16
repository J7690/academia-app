#!/usr/bin/env python3
"""Audit Phase 6 (Polish marketplace)

- Vérifie l'existence des RPC inquiry chat
- Consigne dans .windsurf/logs/
"""

import json
from pathlib import Path
from datetime import datetime
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
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

    queries: List[Tuple[str, str]] = [
        (
            "PHASE6_FUNCTION_EXISTS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_list_opportunity_inquiry_messages',
                'app_student_reply_opportunity_inquiry'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "INQUIRY_MESSAGE_POLICIES",
            """
            SELECT schemaname, tablename, policyname, roles, cmd
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename = 'opportunity_inquiry_messages'
            ORDER BY policyname
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}
    for label, sql in queries:
        results[label] = run_sql(m, label, sql)

    log_dir = Path('.windsurf/logs')
    log_dir.mkdir(parents=True, exist_ok=True)
    out = {
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "results": results,
    }
    out_path = log_dir / 'audit_marketplace_phase6_precheck.json'
    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding='utf-8')
    print('[OK] Résultats sauvegardés dans', out_path.as_posix())
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
