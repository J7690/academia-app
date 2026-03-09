#!/usr/bin/env python3
"""Audit: compare 'student hero' playback mechanism vs 'landing hero' media storage.

Uses admin_execute_sql.
Outputs:
- hero_playlist table columns
- landing config table columns (best guess: app.landing_config)
- RPC existence for hero playlist + landing config
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
        timeout=45,
    )
    r.raise_for_status()
    data = r.json()
    rows = data.get("rows") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def main() -> int:
    m = SupabaseAutoManager()

    # Find candidate landing tables
    landing_tables = exec_rows(
        m,
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema='app'
          AND table_type='BASE TABLE'
          AND (table_name ILIKE '%landing%' OR table_name ILIKE '%hero%')
        ORDER BY table_name
        """.strip(),
    )

    print("[TABLES app.* like landing/hero]")
    print(json.dumps(landing_tables, indent=2, ensure_ascii=False))

    def cols(table: str) -> List[Dict[str, Any]]:
        return exec_rows(
            m,
            f"""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema='app' AND table_name='{table.replace("'","''")}'
            ORDER BY ordinal_position
            """.strip(),
        )

    for table in ["hero_playlist", "hero_videos", "landing_config", "landing_videos"]:
        exists = exec_rows(
            m,
            f"""
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema='app' AND table_name='{table}'
            LIMIT 1
            """.strip(),
        )
        if exists:
            print(f"\n[COLUMNS app.{table}]")
            print(json.dumps(cols(table), indent=2, ensure_ascii=False))

    # List relevant RPCs
    rpcs = exec_rows(
        m,
        """
        SELECT
          n.nspname AS schema,
          p.proname AS name,
          pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('public','app')
          AND (
            p.proname IN (
              'app_public_hero_playlist',
              'app_admin_get_hero_playlist',
              'app_videoasset_get_playback_for_direct_url',
              'app_public_landing_content',
              'app_admin_get_landing_content',
              'app_admin_upsert_landing_config'
            )
            OR p.proname ILIKE '%hero_playlist%'
            OR p.proname ILIKE '%landing%config%'
          )
        ORDER BY n.nspname, p.proname
        """.strip(),
    )

    print("\n[RPCS relevant]")
    print(json.dumps(rpcs, indent=2, ensure_ascii=False))

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
