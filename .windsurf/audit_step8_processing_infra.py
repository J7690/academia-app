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
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {"label": label, "http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "STORAGE_BUCKETS",
            """
            SELECT id, name, public, created_at, updated_at
            FROM storage.buckets
            ORDER BY id
            """.strip(),
        ),
        (
            "STORAGE_OBJECT_POLICIES",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'storage'
              AND tablename = 'objects'
            ORDER BY policyname
            """.strip(),
        ),
        (
            "VIDEO_ASSETS_STATUS_COUNTS",
            """
            SELECT status, COUNT(*) AS n
            FROM app.video_assets
            GROUP BY status
            ORDER BY status
            """.strip(),
        ),
        (
            "VIDEO_JOBS_STATUS_COUNTS",
            """
            SELECT status, job_type, COUNT(*) AS n
            FROM app.video_processing_jobs
            GROUP BY status, job_type
            ORDER BY status, job_type
            """.strip(),
        ),
        (
            "VIDEO_RENDITIONS_KIND_COUNTS",
            """
            SELECT kind, status, COUNT(*) AS n
            FROM app.video_renditions
            GROUP BY kind, status
            ORDER BY kind, status
            """.strip(),
        ),
        (
            "VIDEO_RPCS_EXISTING",
            """
            SELECT routine_name, routine_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name ILIKE 'app_videoasset%'
            ORDER BY routine_name
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        out[label] = run_sql(m, label, sql, timeout=180)

    out_path = ".windsurf/logs/step8_audit_processing_infra.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    for k, v in out.items():
        rows = v.get("rows") if isinstance(v, dict) else None
        print(f"{k}: ok={v.get('ok')} rows={len(rows) if isinstance(rows, list) else 0}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
