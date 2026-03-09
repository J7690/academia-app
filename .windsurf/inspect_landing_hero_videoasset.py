#!/usr/bin/env python3
"""Inspect landing hero config video_asset_id and its renditions readiness."""

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

    cfg = exec_rows(
        m,
        """
        SELECT id, hero_title, video_asset_id, created_at, updated_at
        FROM app.landing_config
        ORDER BY created_at DESC
        LIMIT 1
        """.strip(),
    )
    print("[landing_config latest]")
    print(json.dumps(cfg, indent=2, ensure_ascii=False))

    if not cfg or not cfg[0].get("video_asset_id"):
        print("[INFO] landing_config.video_asset_id is NULL/empty -> playback.best_url will be NULL")
        return 0

    va = str(cfg[0]["video_asset_id"])
    renditions = exec_rows(
        m,
        f"""
        SELECT kind, status, width, height, public_url_hint, created_at
        FROM app.video_renditions
        WHERE video_asset_id = '{va}'::uuid
        ORDER BY created_at DESC
        LIMIT 50
        """.strip(),
    )
    print("\n[video_renditions for landing_config.video_asset_id]")
    print(json.dumps(renditions, indent=2, ensure_ascii=False))

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
