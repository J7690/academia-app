#!/usr/bin/env python3
"""Audit complet du module TD (tables app.td_*) via admin_execute_sql.

- Lecture seule (SELECT) sur information_schema et pg_policies.
- Utilise admin_execute_sql directement (comme les autres audits *_admin_rpc.py).
- Produit un JSON détaillé dans .windsurf/logs/td_module_admin_rpc.json.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=120)
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
            "TD_TABLES_APP",
            """
            SELECT table_schema, table_name, table_type
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name LIKE 'td_%'
            ORDER BY table_name
            """.strip(),
        ),
        (
            "TD_COLUMNS_APP",
            """
            SELECT table_schema, table_name, column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name LIKE 'td_%'
            ORDER BY table_name, ordinal_position
            """.strip(),
        ),
        (
            "TD_POLICIES_APP",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename LIKE 'td_%'
            ORDER BY tablename, policyname
            """.strip(),
        ),
        (
            "TD_GRANTS_APP",
            """
            SELECT table_schema, table_name, grantee, privilege_type
            FROM information_schema.role_table_grants
            WHERE table_schema = 'app'
              AND table_name LIKE 'td_%'
            ORDER BY table_name, grantee, privilege_type
            """.strip(),
        ),
        (
            "TD_ROUTINES_PUBLIC_APP",
            """
            SELECT routine_schema, routine_name, routine_type, data_type
            FROM information_schema.routines
            WHERE routine_schema IN ('public', 'app')
              AND routine_name ILIKE 'app_td%'
            ORDER BY routine_schema, routine_name
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    for label, sql in queries:
        res = run_sql(m, label, sql)
        rows = res.get("rows")
        if not isinstance(rows, list):
            rows = []
        results[label] = {
            "http": res.get("http"),
            "ok": res.get("ok"),
            "mode": res.get("mode"),
            "rows_count": res.get("rows_count"),
            "sample_rows": rows[:10],
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }

        print(f"\n=== {label} ===")
        print(
            f"http={results[label]['http']} ok={results[label]['ok']} "
            f"mode={results[label]['mode']} rows={results[label]['rows_count']} "
            f"error={results[label]['error']} sqlstate={results[label]['sqlstate']}"
        )
        if rows:
            print(json.dumps(results[label]["sample_rows"], ensure_ascii=False, indent=2)[:4000])
        else:
            print("[INFO] Aucune ligne retournée pour cette requête.")

    # Pour l'audit actuel, on se contente d'un dump stdout.
    # Si besoin, on pourra réactiver l'écriture dans .windsurf/logs ultérieurement.

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
