#!/usr/bin/env python3
"""Audit what the app uses for landing hero (playlist slot landing_hero_main vs landing_config)."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def rows(m: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql},
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()
    out = data.get("rows") if isinstance(data, dict) else None
    return out if isinstance(out, list) else []


def main() -> int:
    m = SupabaseAutoManager()

    print("[landing_config latest]")
    print(
        json.dumps(
            rows(
                m,
                """
                SELECT id, hero_video_url, hero_storage_path, video_asset_id, updated_at
                FROM app.landing_config
                ORDER BY created_at DESC
                LIMIT 1
                """.strip(),
            ),
            indent=2,
            ensure_ascii=False,
        )
    )

    print("\n[app.hero_playlist rows for slot landing_hero_main]")
    print(
        json.dumps(
            rows(
                m,
                """
                SELECT id, slot, media_type, title, base_video_url, base_image_url,
                       video_asset_id, is_active, sort_order, created_at, updated_at
                FROM app.hero_playlist
                WHERE slot='landing_hero_main'
                ORDER BY sort_order, created_at
                """.strip(),
            ),
            indent=2,
            ensure_ascii=False,
        )
    )

    print("\n[public.app_public_hero_playlist('landing_hero_main')]")
    print(
        json.dumps(
            rows(m, "SELECT public.app_public_hero_playlist('landing_hero_main') AS payload"),
            indent=2,
            ensure_ascii=False,
        )
    )

    print("\n[public.app_public_landing_content()]")
    print(
        json.dumps(
            rows(m, "SELECT public.app_public_landing_content() AS payload"),
            indent=2,
            ensure_ascii=False,
        )
    )

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
