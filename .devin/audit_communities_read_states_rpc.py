#!/usr/bin/env python3
"""Audit ciblé des RPC communautés pour les états de lecture (non-lus).

- Vérifie l'existence et la réponse HTTP de :
  - app_student_mark_community_read
  - app_student_list_my_communities_activity

Utilise SupabaseAutoManager + check_rpc comme les autres audits .windsurf.
"""

from __future__ import annotations

import json
from typing import Any, Dict

from supabase_auto_manager import SupabaseAutoManager
from audit_academia_supabase import check_rpc


def main() -> int:
    manager = SupabaseAutoManager()

    rpc_tests: list[tuple[str, Dict[str, Any] | None]] = [
        # Utilise un UUID factice pour tester uniquement l'existence de la RPC
        (
            "app_student_mark_community_read",
            {"p_community_id": "00000000-0000-0000-0000-000000000000"},
        ),
        ("app_student_list_my_communities_activity", {}),
    ]

    results: list[Dict[str, Any]] = []
    print("=== AUDIT RPC COMMUNAUTES - READ STATES ===")
    for name, payload in rpc_tests:
        result = check_rpc(manager, name, payload)
        results.append(result)

    print(json.dumps(results, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
