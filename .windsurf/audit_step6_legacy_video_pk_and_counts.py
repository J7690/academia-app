#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, List, Set

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

    tables = [
        "challenge_participations",
        "challenge_participation_videos",
        "challenge_videos",
        "challenge_video_render_jobs",
        "free_videos",
        "free_video_render_jobs",
        "landing_config",
        "landing_videos",
        "student_home_videos",
        "university_media",
        "hero_playlist",
        "hero_renders",
        "hero_renders_tv",
        "video_playback_errors",
        "online_course_live_sessions",
    ]

    out: Dict[str, Any] = {}

    # columns per table
    out["columns"] = run_sql(
        m,
        "COLUMNS",
        """
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app'
          AND table_name = ANY(ARRAY[
            'challenge_participations','challenge_participation_videos','challenge_videos','challenge_video_render_jobs',
            'free_videos','free_video_render_jobs','landing_config','landing_videos','student_home_videos','university_media',
            'hero_playlist','hero_renders','hero_renders_tv','video_playback_errors','online_course_live_sessions'
          ])
        ORDER BY table_name, ordinal_position
        """.strip(),
    )

    # primary keys
    out["primary_keys"] = run_sql(
        m,
        "PRIMARY_KEYS",
        """
        SELECT
          n.nspname AS schema,
          c.relname AS table_name,
          a.attname AS column_name
        FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN unnest(con.conkey) AS ck(attnum) ON TRUE
        JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ck.attnum
        WHERE con.contype = 'p'
          AND n.nspname = 'app'
          AND c.relname = ANY(ARRAY[
            'challenge_participations','challenge_participation_videos','challenge_videos','challenge_video_render_jobs',
            'free_videos','free_video_render_jobs','landing_config','landing_videos','student_home_videos','university_media',
            'hero_playlist','hero_renders','hero_renders_tv','video_playback_errors','online_course_live_sessions'
          ])
        ORDER BY c.relname, a.attname
        """.strip(),
    )

    # Build dynamic count queries per table based on existing columns.
    columns_rows = out.get("columns", {}).get("rows")
    cols_by_table: Dict[str, Set[str]] = {}
    if isinstance(columns_rows, list):
        for r in columns_rows:
            tn = (r.get("table_name") or "").strip()
            cn = (r.get("column_name") or "").strip()
            if not tn or not cn:
                continue
            cols_by_table.setdefault(tn, set()).add(cn)

    def has_col(table: str, col: str) -> bool:
        return col in cols_by_table.get(table, set())

    def count_filter_text(col: str) -> str:
        return f"COUNT(*) FILTER (WHERE COALESCE(NULLIF(TRIM(t.{col}),''), NULL) IS NOT NULL) AS with_{col}"

    def count_filter_jsonb_not_null(col: str) -> str:
        return f"COUNT(*) FILTER (WHERE t.{col} IS NOT NULL) AS with_{col}"

    counts: Dict[str, Any] = {}
    for t in tables:
        select_parts: List[str] = [
            f"'{t}'::text AS table",
            "COUNT(*) AS total",
        ]

        for c in [
            "video_url",
            "submission_url",
            "base_video_url",
            "replay_video_url",
            "result_video_url",
            "source_video_url",
            "thumbnail_url",
            "render_url",
        ]:
            if has_col(t, c):
                select_parts.append(count_filter_text(c))

        if has_col(t, "video_renditions"):
            select_parts.append(count_filter_jsonb_not_null("video_renditions"))

        sql = (
            "SELECT\n  "
            + ",\n  ".join(select_parts)
            + f"\nFROM app.{t} t"
        )

        counts[t] = run_sql(m, f"COUNT_{t}", sql, timeout=120)

    out["counts"] = counts

    out_path = ".windsurf/logs/step6_legacy_video_pk_and_counts.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
