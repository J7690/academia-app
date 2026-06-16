#!/usr/bin/env python3
"""List universities (id, name, slug) from app.universities via admin_execute_sql."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=30)
    r.raise_for_status()
    data = r.json()
    if isinstance(data, dict) and data.get("ok") is True and data.get("mode") == "select":
        rows = data.get("rows")
        if isinstance(rows, list):
            return rows
    return []


def main() -> int:
    m = SupabaseAutoManager()
    rows = exec_sql(
        m,
        """
        SELECT id, name, slug
        FROM app.universities
        ORDER BY created_at DESC NULLS LAST
        LIMIT 500
        """.strip(),
    )
    print(json.dumps(rows, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
