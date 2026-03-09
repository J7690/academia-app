#!/usr/bin/env python3
"""Audit complet des tables communautés et DM avant intégration saisie mathématique.

Vérifie :
1. Structure des tables community_posts, direct_messages
2. RPCs existantes pour l'envoi de messages (communautés + DM)
3. Colonnes content, type, media_url — pour savoir si on peut stocker du LaTeX inline
4. Échantillon de données existantes
5. RPCs de listing (pour savoir comment le rendu est fait côté Flutter)

Utilise SupabaseAutoManager.execute_sql_auto (RPC execute_sql) en lecture seule.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime

from supabase_auto_manager import SupabaseAutoManager


def run_query(manager: SupabaseAutoManager, label: str, sql: str) -> dict:
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    result = manager.execute_sql_auto(sql)
    if result.get("success"):
        data = result.get("data", [])
        if data:
            print(json.dumps(data, indent=2, ensure_ascii=False, default=str))
        else:
            print("  (aucun résultat)")
    else:
        print(f"  ERREUR: {result.get('error', 'inconnue')}")
    return result


def main() -> int:
    manager = SupabaseAutoManager()
    timestamp = datetime.now().isoformat()
    all_results = {"timestamp": timestamp, "sections": {}}

    # ─────────────────────────────────────────────────────────
    # 1. Structure de app.community_posts
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "1. COLONNES de app.community_posts", """
        SELECT column_name, data_type, is_nullable, column_default,
               character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'community_posts'
        ORDER BY ordinal_position
    """)
    all_results["sections"]["community_posts_columns"] = r

    # ─────────────────────────────────────────────────────────
    # 2. Structure de app.direct_messages
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "2. COLONNES de app.direct_messages", """
        SELECT column_name, data_type, is_nullable, column_default,
               character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'direct_messages'
        ORDER BY ordinal_position
    """)
    all_results["sections"]["direct_messages_columns"] = r

    # ─────────────────────────────────────────────────────────
    # 3. Structure de app.direct_conversations
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "3. COLONNES de app.direct_conversations", """
        SELECT column_name, data_type, is_nullable, column_default,
               character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'direct_conversations'
        ORDER BY ordinal_position
    """)
    all_results["sections"]["direct_conversations_columns"] = r

    # ─────────────────────────────────────────────────────────
    # 4. RPCs liées aux communautés (envoi + listing posts)
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "4. RPCs communautés (add/list/edit posts)", """
        SELECT p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND p.proname LIKE '%community_post%'
        ORDER BY p.proname
    """)
    all_results["sections"]["community_post_rpcs"] = r

    # ─────────────────────────────────────────────────────────
    # 5. RPCs liées aux DM (envoi + listing messages)
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "5. RPCs DM (send/list messages)", """
        SELECT p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND (p.proname LIKE '%direct_message%' OR p.proname LIKE '%dm_%')
        ORDER BY p.proname
    """)
    all_results["sections"]["dm_rpcs"] = r

    # ─────────────────────────────────────────────────────────
    # 6. Échantillon community_posts (content, type)
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "6. Échantillon community_posts (3 derniers)", """
        SELECT id, community_id, content, type, media_url,
               reply_to_post_id, is_deleted, created_at
        FROM app.community_posts
        ORDER BY created_at DESC
        LIMIT 3
    """)
    all_results["sections"]["community_posts_sample"] = r

    # ─────────────────────────────────────────────────────────
    # 7. Échantillon direct_messages (content, type)
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "7. Échantillon direct_messages (3 derniers)", """
        SELECT id, conversation_id, content, type, media_url,
               reply_to_message_id, is_deleted, created_at
        FROM app.direct_messages
        ORDER BY created_at DESC
        LIMIT 3
    """)
    all_results["sections"]["direct_messages_sample"] = r

    # ─────────────────────────────────────────────────────────
    # 8. Types distincts utilisés dans community_posts
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "8. Types distincts dans community_posts", """
        SELECT type, COUNT(*) AS cnt
        FROM app.community_posts
        GROUP BY type
        ORDER BY cnt DESC
    """)
    all_results["sections"]["community_posts_types"] = r

    # ─────────────────────────────────────────────────────────
    # 9. Types distincts utilisés dans direct_messages
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "9. Types distincts dans direct_messages", """
        SELECT type, COUNT(*) AS cnt
        FROM app.direct_messages
        GROUP BY type
        ORDER BY cnt DESC
    """)
    all_results["sections"]["direct_messages_types"] = r

    # ─────────────────────────────────────────────────────────
    # 10. Source des RPCs add_community_post et send_direct_message
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "10. Code source RPC app_student_add_community_post", """
        SELECT p.proname, pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND p.proname = 'app_student_add_community_post'
        LIMIT 2
    """)
    all_results["sections"]["rpc_add_community_post_source"] = r

    r = run_query(manager, "11. Code source RPC app_student_send_direct_message", """
        SELECT p.proname, pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND p.proname = 'app_student_send_direct_message'
        LIMIT 1
    """)
    all_results["sections"]["rpc_send_dm_source"] = r

    # ─────────────────────────────────────────────────────────
    # 12. RPCs de listing posts communautés
    # ─────────────────────────────────────────────────────────
    r = run_query(manager, "12. Code source RPC app_student_list_community_posts", """
        SELECT p.proname, pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND p.proname = 'app_student_list_community_posts'
        LIMIT 1
    """)
    all_results["sections"]["rpc_list_community_posts_source"] = r

    r = run_query(manager, "13. Code source RPC app_student_list_direct_messages", """
        SELECT p.proname, pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND p.proname = 'app_student_list_direct_messages'
        LIMIT 1
    """)
    all_results["sections"]["rpc_list_dm_source"] = r

    # ─────────────────────────────────────────────────────────
    # Sauvegarde du rapport
    # ─────────────────────────────────────────────────────────
    report_path = manager.windsurf_dir / "logs" / "audit_math_input_communities_dm.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False, default=str)
    print(f"\n✅ Rapport sauvegardé: {report_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
