#!/usr/bin/env python3
"""Dump definitions of landing-related RPCs to verify playback logic."""

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

    targets = [
        "app_public_landing_content",
        "app_admin_get_landing_content",
        "app_admin_upsert_landing_config",
    ]

    res = rows(
        m,
        """
        SELECT
          p.proname AS name,
          pg_get_function_identity_arguments(p.oid) AS args,
          pg_get_functiondef(p.oid) AS def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname='public'
          AND p.proname = ANY(ARRAY['app_public_landing_content','app_admin_get_landing_content','app_admin_upsert_landing_config'])
        ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);
        """.strip(),
    )

    print(f"Found {len(res)} function variants")
    for r in res:
        print("\n---")
        print(r["name"], "(", r["args"], ")")
        d = (r.get("def") or "")
        print(d[:6000])

    # Also check whether landing content includes 'playback'
    for fname in ["app_public_landing_content", "app_admin_get_landing_content"]:
        defs = [r for r in res if r.get("name") == fname]
        if defs:
            txt = (defs[0].get("def") or "").lower()
            print(f"\n[CHECK] {fname} contains word 'playback':", "playback" in txt)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
