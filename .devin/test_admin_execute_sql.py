#!/usr/bin/env python3
"""Petits tests ciblés de la RPC admin_execute_sql"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

    tests = [
        "CREATE SCHEMA IF NOT EXISTS app",
        "CREATE TABLE IF NOT EXISTS app.test_schema_table (id uuid default gen_random_uuid())",
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'app'",
        "DROP TABLE IF EXISTS app.test_schema_table",
    ]

    for sql in tests:
        print("\n=== SQL ===")
        print(sql)
        try:
            r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
        except Exception as exc:
            print(f"❌ Erreur réseau: {exc}")
            continue

        print(f"HTTP {r.status_code}")
        try:
            data = r.json()
            print(json.dumps(data, indent=2, ensure_ascii=False))
        except Exception:
            print(r.text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
