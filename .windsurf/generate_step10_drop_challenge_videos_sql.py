#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

import requests

from supabase_auto_manager import SupabaseAutoManager


OUT_SQL = Path(__file__).parent / "sql_changes" / "change_20251213_step10_drop_challenge_videos.sql"
OUT_JSON = Path(__file__).parent / "logs" / "step10_drop_challenge_videos_plan.json"


def run_sql_rows(m: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    sql_clean = (sql or "").strip()
    if sql_clean.endswith(";"):
        sql_clean = sql_clean[:-1].rstrip()

    resp = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql_clean},
        timeout=240,
    )
    resp.raise_for_status()
    data: Any = resp.json()
    if isinstance(data, dict) and data.get("ok") and isinstance(data.get("rows"), list):
        return data["rows"]
    if isinstance(data, list):
        return data
    raise RuntimeError(f"admin_execute_sql_unexpected: {data}")


def main() -> int:
    m = SupabaseAutoManager()

    routines = run_sql_rows(
        m,
        """
        SELECT DISTINCT
          pn.nspname AS schema_name,
          p.proname AS routine_name,
          pg_get_function_identity_arguments(p.oid) AS identity_args,
          p.prokind AS prokind
        FROM pg_depend d
        JOIN pg_proc p ON p.oid = d.objid
        JOIN pg_namespace pn ON pn.oid = p.pronamespace
        JOIN pg_class c ON c.oid = d.refobjid
        JOIN pg_namespace cn ON cn.oid = c.relnamespace
        WHERE d.classid = 'pg_proc'::regclass
          AND d.refclassid = 'pg_class'::regclass
          AND cn.nspname = 'app'
          AND c.relname = 'challenge_videos'
          AND pn.nspname IN ('public','app')
        ORDER BY pn.nspname, p.proname, pg_get_function_identity_arguments(p.oid)
        """.strip(),
    )

    lines: List[str] = []
    lines.append("-- Étape 10 (Option A) : DROP uniquement app.challenge_videos + routines DB qui référencent app.challenge_videos")
    lines.append("-- Interdictions respectées: aucune purge storage, aucune suppression d'autres tables/colonnes.")
    lines.append("-- Généré automatiquement par .windsurf/generate_step10_drop_challenge_videos_sql.py")
    lines.append("-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step10_drop_challenge_videos.sql")
    lines.append("")

    for r in routines:
        schema = str(r.get("schema_name") or "")
        name = str(r.get("routine_name") or "")
        args = str(r.get("identity_args") or "")
        prokind = str(r.get("prokind") or "")
        if not schema or not name:
            continue
        if prokind == "p":
            lines.append(f"DROP PROCEDURE IF EXISTS {schema}.{name}({args});")
        else:
            lines.append(f"DROP FUNCTION IF EXISTS {schema}.{name}({args});")

    lines.append("")
    lines.append("DROP TABLE IF EXISTS app.challenge_videos;")
    lines.append("")

    OUT_SQL.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)

    OUT_SQL.write_text("\n".join(lines), encoding="utf-8")

    OUT_JSON.write_text(
        json.dumps({"routines_count": len(routines), "routines": routines}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"[OK] wrote {OUT_SQL}")
    print(f"[OK] wrote {OUT_JSON}")
    print(f"routines_to_drop={len(routines)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
