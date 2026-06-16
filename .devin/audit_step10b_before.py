#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

import requests

from supabase_auto_manager import SupabaseAutoManager


LEGACY_COLS = [
    "video_url",
    "video_renditions",
    "thumbnail_url",
    "submission_url",
    "source_video_url",
    "result_video_url",
]


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 240) -> Any:
    sql_clean = (sql or "").strip()
    if sql_clean.endswith(";"):
        sql_clean = sql_clean[:-1].rstrip()
    resp = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql_clean},
        timeout=timeout,
    )
    resp.raise_for_status()
    return resp.json()


def rows(res: Any) -> List[Dict[str, Any]]:
    if isinstance(res, dict) and res.get("ok") and isinstance(res.get("rows"), list):
        return res["rows"]
    if isinstance(res, list):
        return res
    return []


def main() -> int:
    m = SupabaseAutoManager()

    cols_list = ",".join([f"'{c}'" for c in LEGACY_COLS])
    legacy_columns = rows(
        run_sql(
            m,
            f"""
            SELECT table_schema, table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND column_name IN ({cols_list})
            ORDER BY table_name, column_name
            """.strip(),
        )
    )

    routines = rows(
        run_sql(
            m,
            """
            SELECT
              n.nspname AS schema,
              p.proname AS name,
              pg_get_function_identity_arguments(p.oid) AS identity_args,
              pg_get_function_result(p.oid) AS result,
              p.prokind AS prokind,
              pg_get_functiondef(p.oid) AS definition
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname IN ('public','app')
            """.strip(),
            timeout=300,
        )
    )

    matched: List[Dict[str, Any]] = []
    for r in routines:
        d = (r.get("definition") or "")
        dl = d.lower()
        matched_cols = [c for c in LEGACY_COLS if c.lower() in dl]
        if matched_cols:
            matched.append(
                {
                    "schema": r.get("schema"),
                    "name": r.get("name"),
                    "identity_args": r.get("identity_args"),
                    "result": r.get("result"),
                    "prokind": r.get("prokind"),
                    "matched": matched_cols,
                }
            )

    out = {
        "legacy_columns_in_app": legacy_columns,
        "matched_routines": matched,
        "counts": {
            "legacy_columns": len(legacy_columns),
            "matched_routines": len(matched),
        },
    }

    out_path = Path(__file__).parent / "logs" / "step10b_audit_before.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[OK] wrote {out_path}")
    print(json.dumps(out["counts"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
