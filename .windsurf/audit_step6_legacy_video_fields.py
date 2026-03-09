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
            "LEGACY_VIDEO_COLUMNS",
            """
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND (
                column_name ILIKE '%video%'
                OR column_name ILIKE '%thumbnail%'
                OR column_name ILIKE '%poster%'
                OR column_name ILIKE '%rendition%'
                OR column_name ILIKE '%mux%'
              )
            ORDER BY table_name, column_name
            """.strip(),
        ),
        (
            "LEGACY_VIDEO_TABLE_COUNTS",
            """
            WITH candidates AS (
              SELECT table_name
              FROM information_schema.columns
              WHERE table_schema = 'app'
                AND (
                  column_name IN ('video_url','submission_url','video_renditions','thumbnail_url')
                  OR column_name ILIKE '%mux%'
                )
              GROUP BY table_name
            )
            SELECT c.table_name
            FROM candidates c
            ORDER BY c.table_name
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        out[label] = run_sql(m, label, sql)

    # For known common tables, also get sample counts if they exist
    sample_tables = [
        "challenge_participations",
        "free_videos",
        "landing_videos",
        "student_home_videos",
        "university_media",
        "course_resources",
    ]

    out_counts: Dict[str, Any] = {}
    for t in sample_tables:
        res = run_sql(
            m,
            f"COUNT_{t}",
            f"""
            SELECT
              '{t}'::text AS table,
              COUNT(*) AS total,
              COUNT(*) FILTER (WHERE COALESCE(NULLIF(TRIM(COALESCE(video_url,'')),''), NULLIF(TRIM(COALESCE(submission_url,'')),'')) IS NOT NULL) AS with_any_video_url
            FROM app.{t}
            """.strip(),
        )
        # If table doesn't exist, admin_execute_sql returns ok=false
        out_counts[t] = res

    out["KNOWN_TABLE_COUNTS"] = out_counts

    out_path = ".windsurf/logs/step6_legacy_video_fields.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    for k, v in out.items():
        if isinstance(v, dict) and "rows" in v:
            print(f"{k}: ok={v.get('ok')} rows={len(v.get('rows') or [])}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
