#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, List

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str) -> Any:
    sql_clean = (sql or "").strip()
    if sql_clean.endswith(";"):
        sql_clean = sql_clean[:-1].rstrip()

    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql_clean}, timeout=180)
    resp.raise_for_status()
    return resp.json()


def main() -> int:
    m = SupabaseAutoManager()

    # 1) Select an existing landing_config row id
    cfg_rows_raw = run_sql(
        m,
        """
        SELECT id::text AS id
        FROM app.landing_config
        ORDER BY updated_at DESC
        LIMIT 1
        """.strip(),
    )

    cfg_rows: List[Dict[str, Any]] = []
    if isinstance(cfg_rows_raw, dict) and cfg_rows_raw.get("ok") and isinstance(cfg_rows_raw.get("rows"), list):
        cfg_rows = cfg_rows_raw["rows"]

    if not cfg_rows:
        raise RuntimeError("no_landing_config_row_found")

    cfg_id = str(cfg_rows[0]["id"])

    before = run_sql(
        m,
        f"""
        SELECT id::text AS id, video_url
        FROM app.landing_config
        WHERE id = '{cfg_id}'::uuid
        """.strip(),
    )

    before_rows: List[Dict[str, Any]] = []
    if isinstance(before, dict) and before.get("ok") and isinstance(before.get("rows"), list):
        before_rows = before["rows"]
    before_val = before_rows[0].get("video_url") if before_rows else None

    # 2) Attempt legacy write (should be blocked + logged)
    attempt = run_sql(
        m,
        f"""
        UPDATE app.landing_config
        SET video_url = 'https://example.com/should_be_blocked.mp4'
        WHERE id = '{cfg_id}'::uuid
        """.strip(),
    )

    after = run_sql(
        m,
        f"""
        SELECT id::text AS id, video_url
        FROM app.landing_config
        WHERE id = '{cfg_id}'::uuid
        """.strip(),
    )

    after_rows: List[Dict[str, Any]] = []
    if isinstance(after, dict) and after.get("ok") and isinstance(after.get("rows"), list):
        after_rows = after["rows"]
    after_val = after_rows[0].get("video_url") if after_rows else None

    # Read back latest log
    log_rows = run_sql(
        m,
        """
        SELECT table_name, operation, column_name, actor_role, actor_sub, actor_uid, actor_current_user, created_at
        FROM app.legacy_video_write_attempts
        ORDER BY created_at DESC
        LIMIT 5
        """.strip(),
    )

    rows: List[Dict[str, Any]] = []
    if isinstance(log_rows, dict) and log_rows.get("ok") and isinstance(log_rows.get("rows"), list):
        rows = log_rows["rows"]

    out = {
        "landing_config_id": cfg_id,
        "before_video_url": before_val,
        "attempt": attempt,
        "after_video_url": after_val,
        "latest_logs": rows,
    }

    out_path = ".windsurf/logs/step9_verify_freeze_legacy.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    print(json.dumps(out, ensure_ascii=False, indent=2)[:7000])

    # Success criteria: update executed (ok=true) but value unchanged + log exists
    ok = isinstance(attempt, dict) and (attempt.get("ok") is True)
    ok = ok and (before_val == after_val)
    ok = ok and len(rows) > 0
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
