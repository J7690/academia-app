#!/usr/bin/env python3
"""Audit ciblé des tables du module Communautés via admin_execute_sql.

- Vérifie l'existence et un échantillon de données pour :
  - app.communities
  - app.community_memberships
  - app.community_posts
  - app.community_read_states

Utilise SupabaseAutoManager.execute_sql_auto (RPC admin_execute_sql) en lecture seule.
"""

from __future__ import annotations

import json

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    manager = SupabaseAutoManager()

    queries = {
        "communities": "SELECT * FROM app.communities LIMIT 5;",
        "community_memberships": "SELECT * FROM app.community_memberships LIMIT 5;",
        "community_posts": "SELECT * FROM app.community_posts LIMIT 5;",
        "community_read_states": "SELECT * FROM app.community_read_states LIMIT 5;",
    }

    for label, sql in queries.items():
        print(f"=== TABLE {label} ===")
        result = manager.execute_sql_auto(sql)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
