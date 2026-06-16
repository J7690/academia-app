#!/usr/bin/env python3
"""Audit Phase 7 (Hardening + UX Alibaba)

- Vérifie les tables notification_events + user_device_tokens
- Vérifie les RPC marketplace utiles existantes
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
            "NOTIFICATION_EVENTS_COLUMNS",
            """
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'notification_events'
            ORDER BY ordinal_position
            """.strip(),
        ),
        (
            "USER_DEVICE_TOKENS_COLUMNS",
            """
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'user_device_tokens'
            ORDER BY ordinal_position
            """.strip(),
        ),
        (
            "MARKETPLACE_RPCS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_list_marketplace_merchants',
                'app_admin_list_marketplace_merchants',
                'app_admin_update_marketplace_merchant_status',
                'app_admin_set_merchant_verification',
                'app_merchant_list_my_opportunities',
                'app_merchant_list_inquiries',
                'app_merchant_reply_inquiry',
                'app_student_create_opportunity_inquiry',
                'app_student_list_my_opportunity_inquiries',
                'app_list_opportunity_inquiry_messages',
                'app_student_reply_opportunity_inquiry'
              )
            ORDER BY routine_name
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

    out_path = log_dir / 'audit_marketplace_phase7_precheck.json'
    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding='utf-8')
    print('[OK] Résultats sauvegardés dans', out_path.as_posix())
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
