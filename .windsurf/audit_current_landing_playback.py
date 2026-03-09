#!/usr/bin/env python3
"""Audit whether landing RPCs currently return playback URLs like student hero.

- Calls public.app_public_landing_content() via SQL
- Prints whether config/playback exists and whether landing videos include playback

Read-only.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_rows(m: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql},
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()
    rows = data.get("rows") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def main() -> int:
    m = SupabaseAutoManager()

    rows = exec_rows(m, "SELECT public.app_public_landing_content() AS payload")
    if not rows:
        print("No rows returned")
        return 1

    payload = rows[0].get("payload")
    if not isinstance(payload, dict):
        print("Payload is not a dict:", type(payload))
        print(json.dumps(rows[0], indent=2, ensure_ascii=False))
        return 1

    cfg = payload.get("config")
    videos = payload.get("videos")

    has_cfg_playback = isinstance(cfg, dict) and isinstance(cfg.get("playback"), dict)
    videos_list = videos if isinstance(videos, list) else []
    videos_with_playback = 0
    for v in videos_list:
        if isinstance(v, dict) and isinstance(v.get("playback"), dict):
            videos_with_playback += 1

    print(json.dumps(
        {
            "success": payload.get("success"),
            "has_config": isinstance(cfg, dict),
            "has_config_playback": has_cfg_playback,
            "videos_count": len(videos_list),
            "videos_with_playback": videos_with_playback,
            "config_keys": sorted(list(cfg.keys())) if isinstance(cfg, dict) else [],
            "first_video_keys": sorted(list(videos_list[0].keys())) if videos_list and isinstance(videos_list[0], dict) else [],
        },
        indent=2,
        ensure_ascii=False,
    ))

    # Print sample playback URLs if present
    if has_cfg_playback:
        pb = cfg.get("playback")
        print("config.playback.best_url=", (pb.get("best_url") if isinstance(pb, dict) else None))

    for i, v in enumerate(videos_list[:3]):
        if not isinstance(v, dict):
            continue
        pb = v.get("playback")
        if isinstance(pb, dict):
            print(f"videos[{i}].playback.best_url=", pb.get("best_url"))

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
