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
            "COUNTS_VIDEO_ASSETS",
            """
            SELECT
              COUNT(*) AS total_assets,
              COUNT(*) FILTER (WHERE origin = 'challenge_submission') AS challenge_assets,
              COUNT(*) FILTER (WHERE origin = 'student_home') AS student_home_assets,
              COUNT(*) FILTER (WHERE origin = 'landing') AS landing_assets,
              COUNT(*) FILTER (WHERE origin = 'university_media') AS university_assets,
              COUNT(*) FILTER (WHERE origin = 'course_resource') AS course_assets
            FROM app.video_assets
            """.strip(),
        ),
        (
            "COUNTS_LEGACY_MAP",
            """
            SELECT context_type, role, COUNT(*) AS n
            FROM app.video_asset_legacy_map
            GROUP BY context_type, role
            ORDER BY context_type, role
            """.strip(),
        ),
        (
            "COUNTS_CONTEXTS",
            """
            SELECT context_type, role, COUNT(*) AS n
            FROM app.video_asset_contexts
            GROUP BY context_type, role
            ORDER BY context_type, role
            """.strip(),
        ),
        (
            "COUNTS_RENDITIONS",
            """
            SELECT kind, rendition_key, COUNT(*) AS n
            FROM app.video_renditions
            WHERE rendition_key LIKE 'legacy%'
            GROUP BY kind, rendition_key
            ORDER BY kind, rendition_key
            """.strip(),
        ),
        (
            "LEGACY_FILL_RATIOS",
            """
            SELECT 'challenge_participations' AS tbl,
                   COUNT(*) AS total,
                   COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL) AS with_video_asset_id
            FROM app.challenge_participations
            UNION ALL
            SELECT 'challenge_participation_videos', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.challenge_participation_videos
            UNION ALL
            SELECT 'free_videos', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.free_videos
            UNION ALL
            SELECT 'landing_videos', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.landing_videos
            UNION ALL
            SELECT 'landing_config', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.landing_config
            UNION ALL
            SELECT 'student_home_videos', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.student_home_videos
            UNION ALL
            SELECT 'hero_playlist', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.hero_playlist
            UNION ALL
            SELECT 'university_media', COUNT(*), COUNT(*) FILTER (WHERE video_asset_id IS NOT NULL)
            FROM app.university_media
            UNION ALL
            SELECT 'online_course_live_sessions', COUNT(*), COUNT(*) FILTER (WHERE replay_video_asset_id IS NOT NULL)
            FROM app.online_course_live_sessions
            ORDER BY tbl
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        out[label] = run_sql(m, label, sql)

    out_path = ".windsurf/logs/step6_backfill_phase1_verify.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    for k, v in out.items():
        print(f"{k}: ok={v.get('ok')} rows={len(v.get('rows') or [])}")

    ok = all(v.get("ok") for v in out.values())
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
