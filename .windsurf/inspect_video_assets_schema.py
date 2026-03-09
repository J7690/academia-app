#!/usr/bin/env python3
"""Inspect app.video_assets and app.video_renditions schema via admin_execute_sql."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def rows(m: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql", headers=m.headers, json={"p_sql": sql}, timeout=60)
    r.raise_for_status()
    data = r.json()
    out = data.get("rows") if isinstance(data, dict) else None
    return out if isinstance(out, list) else []


def cols(m: SupabaseAutoManager, table: str) -> List[Dict[str, Any]]:
    return rows(m, f"""
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='{table}'
    ORDER BY ordinal_position
    """.strip())


def main() -> int:
    m = SupabaseAutoManager()
    for t in ["video_assets", "video_renditions", "video_asset_contexts"]:
        exists = rows(m, f"SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}' LIMIT 1")
        print(f"\n[{t}] exists={bool(exists)}")
        if exists:
            print(json.dumps(cols(m, t), indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
