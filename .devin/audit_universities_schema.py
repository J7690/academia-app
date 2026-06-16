#!/usr/bin/env python3
"""Audit app.universities schema (columns + constraints) via admin_execute_sql."""

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

    cols = exec_sql_rows(
        m,
        """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='universities'
        ORDER BY ordinal_position
        """.strip(),
    )

    cons = exec_sql_rows(
        m,
        """
        SELECT
          tc.constraint_type,
          tc.constraint_name,
          kcu.column_name
        FROM information_schema.table_constraints tc
        LEFT JOIN information_schema.key_column_usage kcu
          ON kcu.constraint_name = tc.constraint_name
         AND kcu.constraint_schema = tc.constraint_schema
        WHERE tc.table_schema='app' AND tc.table_name='universities'
        ORDER BY tc.constraint_type, tc.constraint_name, kcu.ordinal_position
        """.strip(),
    )

    print("[COLUMNS]")
    print(json.dumps(cols, indent=2, ensure_ascii=False))
    print("\n[CONSTRAINTS]")
    print(json.dumps(cons, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
