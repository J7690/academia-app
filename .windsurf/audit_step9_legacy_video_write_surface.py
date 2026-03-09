#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, List

import requests

from supabase_auto_manager import SupabaseAutoManager


LEGACY_COLUMN_NAMES = [
    "video_url",
    "video_renditions",
    "thumbnail_url",
    "submission_url",
    "source_video_url",
    "result_video_url",
]


def run_sql(m: SupabaseAutoManager, label: str, sql: str) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=180)
    data: Any
    try:
        data = resp.json()
    except Exception:
        data = {"_raw": (resp.text or "")[:2000]}
    rows = []
    if isinstance(data, dict) and data.get("ok") and isinstance(data.get("rows"), list):
        rows = data["rows"]
    return {"label": label, "http": resp.status_code, "ok": bool(getattr(data, "get", lambda *_: False)("ok")) if isinstance(data, dict) else None, "rows": rows, "data": data if not rows else None}


def main() -> int:
    m = SupabaseAutoManager()
    col_list = ",".join([f"'{c}'" for c in LEGACY_COLUMN_NAMES])

    q = f"""
    SELECT table_schema, table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND column_name IN ({col_list})
    ORDER BY table_name, column_name
    """.strip()

    out: Dict[str, Any] = {}
    out["LEGACY_COLUMNS_IN_APP_SCHEMA"] = run_sql(m, "LEGACY_COLUMNS_IN_APP_SCHEMA", q)

    out_path = ".windsurf/logs/step9_audit_legacy_write_surface.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    rows: List[Dict[str, Any]] = out["LEGACY_COLUMNS_IN_APP_SCHEMA"].get("rows") or []
    print(f"legacy_columns_found={len(rows)}")
    for r in rows[:60]:
        print(f"{r.get('table_name')}.{r.get('column_name')} ({r.get('data_type')})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
