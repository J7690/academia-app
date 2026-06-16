#!/usr/bin/env python3
"""Applique un seul fichier SQL via la RPC admin_execute_sql.

Usage:
    python apply_one_sql_via_admin_rpc.py supabase_student_offers.sql
"""

from __future__ import annotations

import sys
from pathlib import Path

from supabase_auto_manager import SupabaseAutoManager
from apply_academia_schema_via_admin_rpc import apply_sql_file


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python apply_one_sql_via_admin_rpc.py <filename.sql>")
        return 1

    filename = sys.argv[1]
    winds_dir = Path(__file__).parent
    manager = SupabaseAutoManager()

    ok = apply_sql_file(manager, winds_dir, filename)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
