#!/usr/bin/env python3
"""List university staff emails for selected universities via admin_execute_sql."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

UNIVERSITIES = {
    "IIM": "1736c347-2c1e-4cbf-b7b0-3dad36ada326",
    "ISTAPEM": "58bf2713-26ad-4134-98b1-3ac2e2ccc951",
    "UMET-BURKINA": "07d5722b-d71b-498d-858e-140ff3458931",
}


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

    ids_sql = ",".join(["'" + v.replace("'", "''") + "'" for v in UNIVERSITIES.values()])

    rows = exec_sql(
        m,
        f"""
        SELECT
          s.university_id,
          u.name as university_name,
          s.full_name,
          s.role,
          s.email,
          s.phone,
          s.is_active,
          s.created_at,
          s.updated_at
        FROM app.university_staff s
        JOIN app.universities u ON u.id = s.university_id
        WHERE s.university_id IN ({ids_sql})
        ORDER BY u.name, s.is_active DESC, s.sort_order NULLS LAST, s.created_at DESC
        LIMIT 500
        """.strip(),
    )

    print(json.dumps(rows, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
