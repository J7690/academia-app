#!/usr/bin/env python3
from __future__ import annotations

import json
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
            "TABLES_APP_ALL",
            """
            SELECT table_schema, table_name, table_type
            FROM information_schema.tables
            WHERE table_schema = 'app'
            ORDER BY table_name
            """.strip(),
        ),
        (
            "COLUMNS_APP_ALL",
            """
            SELECT table_name, column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
            ORDER BY table_name, ordinal_position
            """.strip(),
        ),
        (
            "ROUTINES_PUBLIC_ALL",
            """
            SELECT routine_schema, routine_name, routine_type, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "FUNCTION_DEFS_PUBLIC_APP_PREFIX",
            """
            SELECT n.nspname AS schema,
                   p.proname AS name,
                   pg_get_functiondef(p.oid) AS def
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.proname ILIKE 'app%'
            ORDER BY p.proname
            """.strip(),
        ),
        (
            "TRIGGERS_APP_STORAGE_PUBLIC",
            """
            SELECT
              n.nspname AS table_schema,
              c.relname AS table_name,
              t.tgname AS trigger_name,
              pg_get_triggerdef(t.oid) AS trigger_def
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE NOT t.tgisinternal
              AND n.nspname IN ('app','storage','public')
            ORDER BY table_schema, table_name, trigger_name
            """.strip(),
        ),
        (
            "POLICIES_APP_ALL",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
            ORDER BY tablename, policyname
            """.strip(),
        ),
        (
            "POLICIES_STORAGE_OBJECTS",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'storage'
              AND tablename = 'objects'
            ORDER BY policyname
            """.strip(),
        ),
        (
            "STORAGE_BUCKETS",
            """
            SELECT id, name, public, created_at, updated_at
            FROM storage.buckets
            ORDER BY id
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

    out_path = ".windsurf/logs/step4_full_inventory_admin_rpc.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    for k, v in results.items():
        print(f"{k}: ok={v.get('ok')} rows={v.get('rows_count')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
