#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


LEGACY_COLUMNS = [
    "video_url",
    "video_renditions",
    "thumbnail_url",
    "submission_url",
]

LEGACY_TABLE_CANDIDATES = [
    "challenge_videos",  # old model
]

LEGACY_RPC_KEYWORDS = [
    "video_url",
    "video_renditions",
    "thumbnail_url",
    "submission_url",
    "challenge_videos",
]


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 180) -> Any:
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


def extract_rows(res: Any) -> List[Dict[str, Any]]:
    if isinstance(res, dict) and res.get("ok") and isinstance(res.get("rows"), list):
        return res["rows"]
    if isinstance(res, list):
        return res
    return []


def main() -> int:
    m = SupabaseAutoManager()

    col_list = ",".join([f"'{c}'" for c in LEGACY_COLUMNS])

    legacy_cols = extract_rows(
        run_sql(
            m,
            f"""
            SELECT table_schema, table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND column_name IN ({col_list})
            ORDER BY table_name, column_name
            """.strip(),
        )
    )

    legacy_tables = extract_rows(
        run_sql(
            m,
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_type = 'BASE TABLE'
              AND table_name IN ('challenge_videos')
            ORDER BY table_name
            """.strip(),
        )
    )

    # Find routines referencing legacy keywords (best-effort)
    routines = extract_rows(
        run_sql(
            m,
            """
            SELECT n.nspname AS schema,
                   p.proname AS name,
                   pg_get_functiondef(p.oid) AS definition
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname IN ('public','app')
            """.strip(),
            timeout=300,
        )
    )

    matched_routines: List[Dict[str, Any]] = []
    for r in routines:
        definition = (r.get("definition") or "")
        def_l = definition.lower()
        if any(k.lower() in def_l for k in LEGACY_RPC_KEYWORDS):
            matched_routines.append({
                "schema": r.get("schema"),
                "name": r.get("name"),
                "matched": [k for k in LEGACY_RPC_KEYWORDS if k.lower() in def_l],
            })

    # Dependencies: views that reference challenge_videos or legacy cols
    views = extract_rows(
        run_sql(
            m,
            """
            SELECT schemaname AS schema,
                   viewname AS name,
                   definition
            FROM pg_views
            WHERE schemaname IN ('public','app')
            """.strip(),
        )
    )

    matched_views: List[Dict[str, Any]] = []
    for v in views:
        d = (v.get("definition") or "")
        dl = d.lower()
        if any(k.lower() in dl for k in LEGACY_RPC_KEYWORDS):
            matched_views.append({
                "schema": v.get("schema"),
                "name": v.get("name"),
                "matched": [k for k in LEGACY_RPC_KEYWORDS if k.lower() in dl],
            })

    out: Dict[str, Any] = {
        "legacy_columns_in_app": legacy_cols,
        "legacy_tables_present": legacy_tables,
        "matched_routines": matched_routines,
        "matched_views": matched_views,
    }

    out_path = ".windsurf/logs/step10_audit_drop_plan.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    print(f"legacy_cols={len(legacy_cols)} legacy_tables={len(legacy_tables)} matched_routines={len(matched_routines)} matched_views={len(matched_views)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
