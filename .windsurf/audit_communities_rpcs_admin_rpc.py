#!/usr/bin/env python3
"""Audit ciblé des RPC du module Communautés via l'API REST.

- Vérifie l'existence et le statut HTTP des RPC étudiantes et admin :
  - app_student_list_communities
  - app_student_list_my_communities
  - app_student_join_community
  - app_student_leave_community
  - app_student_list_community_posts
  - app_student_add_community_post
  - app_student_mark_community_read
  - app_student_list_my_communities_activity

(On ne teste pas ici les RPC admin supplémentaires qui ne sont pas encore dans le cahier des charges phase 1.)
"""

from __future__ import annotations

import json
from typing import Any, Dict

from supabase_auto_manager import SupabaseAutoManager
from audit_academia_supabase import check_rpc


def main() -> int:
    manager = SupabaseAutoManager()

    # UUID factice pour tester l'existence des RPC sans dépendre de vraies données
    fake_uuid = "00000000-0000-0000-0000-000000000000"

    rpc_tests: list[tuple[str, Dict[str, Any] | None]] = [
        ("app_student_list_communities", {"p_search": None, "p_category": None}),
        ("app_student_list_my_communities", {}),
        ("app_student_join_community", {"p_community_id": fake_uuid}),
        ("app_student_leave_community", {"p_community_id": fake_uuid}),
        ("app_student_list_community_posts", {"p_community_id": fake_uuid}),
        (
            "app_student_add_community_post",
            {"p_community_id": fake_uuid, "p_content": "test"},
        ),
        ("app_student_mark_community_read", {"p_community_id": fake_uuid}),
        ("app_student_list_my_communities_activity", {}),
        (
            "app_student_create_group",
            {
                "p_name": "Test Groupe",
                "p_description": "Créé via audit",
                "p_category": "test",
            },
        ),
        ("app_student_list_my_chats", {}),
        (
            "app_student_report_community",
            {
                "p_community_id": fake_uuid,
                "p_reason": "contenu inapproprié (audit)",
                "p_details": "Signalement déclenché depuis le script d'audit.",
            },
        ),
        (
            "app_student_report_community_post",
            {
                "p_post_id": fake_uuid,
                "p_reason": "message suspect (audit)",
                "p_details": "Signalement déclenché depuis le script d'audit.",
            },
        ),
        (
            "app_admin_list_community_moderation_events",
            {"p_community_id": fake_uuid},
        ),
        (
            "app_admin_resolve_moderation_event",
            {
                "p_event_id": fake_uuid,
                "p_resolution": "résolution de test (audit)",
                "p_new_moderation_state": "clean",
                "p_new_status": "active",
            },
        ),
    ]

    results: list[Dict[str, Any]] = []
    print("=== AUDIT RPC COMMUNAUTES (ETUDIANT) ===")
    for name, payload in rpc_tests:
        result = check_rpc(manager, name, payload)
        results.append(result)

    print(json.dumps(results, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
