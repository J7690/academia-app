#!/usr/bin/env python3
"""Audit where to store university mini-site media (image/video).

- Lists Supabase Storage buckets
- Lists columns of app.university_media
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql_rows(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    rows = data.get("rows") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def main() -> int:
    m = SupabaseAutoManager()

    buckets = exec_sql_rows(
        m,
        """
        SELECT id, name, public, created_at
        FROM storage.buckets
        ORDER BY created_at DESC NULLS LAST
        """.strip(),
    )

    cols = exec_sql_rows(
        m,
        """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='university_media'
        ORDER BY ordinal_position
        """.strip(),
    )

    print("[BUCKETS]")
    print(json.dumps(buckets, indent=2, ensure_ascii=False))
    print("\n[app.university_media columns]")
    print(json.dumps(cols, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
