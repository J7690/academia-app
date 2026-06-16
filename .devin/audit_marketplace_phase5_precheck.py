#!/usr/bin/env python3
"""Audit Phase 5 (Student marketplace UX)

- Vérifie que les RPC nécessaires existent
- Vérifie que app_student_list_opportunities renvoie les colonnes marketplace
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
            "PHASE5_FUNCTION_EXISTS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_student_list_opportunities',
                'app_student_list_bookmarked_opportunities',
                'app_student_create_opportunity_inquiry',
                'app_student_list_my_opportunity_inquiries'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "STUDENT_OPPORTUNITIES_MARKETPLACE_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'opportunities'
              AND column_name IN (
                'merchant_id',
                'review_status',
                'price_from',
                'price_to',
                'currency',
                'min_order_qty',
                'lead_time_days',
                'is_ready_to_ship'
              )
            ORDER BY column_name
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
    out_path = log_dir / 'audit_marketplace_phase5_precheck.json'
    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding='utf-8')
    print('[OK] Résultats sauvegardés dans', out_path.as_posix())
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
