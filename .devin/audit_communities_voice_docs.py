#!/usr/bin/env python3
"""Audit ciblé : messages vocaux & upload documents dans le module Communautés + DM.

Vérifie via admin_execute_sql (RPC) :
1. Colonnes exactes de app.community_posts (type, media_url, edited_at...)
2. Colonnes exactes de app.direct_messages (type, media_url...)
3. Existence et signature des RPCs clés (add_post, list_posts, send_dm, list_dm)
4. Bucket storage community-media (existence + policies)
5. Échantillon de posts avec type != 'text' (audio/image/file)
6. Échantillon de DMs avec type != 'text'
"""

from __future__ import annotations

import json
import sys

from supabase_auto_manager import SupabaseAutoManager
from audit_academia_supabase import check_rpc


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 70)
    print("AUDIT COMMUNAUTÉS — MESSAGES VOCAUX & UPLOAD DOCUMENTS")
    print("=" * 70)

    # ── 1. Colonnes de app.community_posts ──
    print("\n=== 1. COLONNES app.community_posts ===")
    sql1 = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_posts'
    ORDER BY ordinal_position;
    """
    r1 = manager.execute_sql_auto(sql1)
    print(json.dumps(r1, indent=2, ensure_ascii=False))

    # ── 2. Colonnes de app.direct_messages ──
    print("\n=== 2. COLONNES app.direct_messages ===")
    sql2 = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'direct_messages'
    ORDER BY ordinal_position;
    """
    r2 = manager.execute_sql_auto(sql2)
    print(json.dumps(r2, indent=2, ensure_ascii=False))

    # ── 3. Colonnes de app.direct_conversations ──
    print("\n=== 3. COLONNES app.direct_conversations ===")
    sql3 = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'direct_conversations'
    ORDER BY ordinal_position;
    """
    r3 = manager.execute_sql_auto(sql3)
    print(json.dumps(r3, indent=2, ensure_ascii=False))

    # ── 4. Signature exacte de app_student_add_community_post ──
    print("\n=== 4. SIGNATURE app_student_add_community_post ===")
    sql4 = """
    SELECT p.proname AS function_name,
           pg_get_function_arguments(p.oid) AS arguments,
           pg_get_function_result(p.oid) AS return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_add_community_post'
    ORDER BY p.proname;
    """
    r4 = manager.execute_sql_auto(sql4)
    print(json.dumps(r4, indent=2, ensure_ascii=False))

    # ── 5. Signature exacte de app_student_list_community_posts ──
    print("\n=== 5. SIGNATURE app_student_list_community_posts ===")
    sql5 = """
    SELECT p.proname AS function_name,
           pg_get_function_arguments(p.oid) AS arguments,
           pg_get_function_result(p.oid) AS return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_community_posts'
    ORDER BY p.proname;
    """
    r5 = manager.execute_sql_auto(sql5)
    print(json.dumps(r5, indent=2, ensure_ascii=False))

    # ── 6. Signature exacte de app_student_send_direct_message ──
    print("\n=== 6. SIGNATURE app_student_send_direct_message ===")
    sql6 = """
    SELECT p.proname AS function_name,
           pg_get_function_arguments(p.oid) AS arguments,
           pg_get_function_result(p.oid) AS return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_send_direct_message'
    ORDER BY p.proname;
    """
    r6 = manager.execute_sql_auto(sql6)
    print(json.dumps(r6, indent=2, ensure_ascii=False))

    # ── 7. Signature exacte de app_student_list_direct_messages ──
    print("\n=== 7. SIGNATURE app_student_list_direct_messages ===")
    sql7 = """
    SELECT p.proname AS function_name,
           pg_get_function_arguments(p.oid) AS arguments,
           pg_get_function_result(p.oid) AS return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_direct_messages'
    ORDER BY p.proname;
    """
    r7 = manager.execute_sql_auto(sql7)
    print(json.dumps(r7, indent=2, ensure_ascii=False))

    # ── 8. Source SQL de app_student_list_community_posts (pour vérifier les JOINs) ──
    print("\n=== 8. SOURCE SQL app_student_list_community_posts ===")
    sql8 = """
    SELECT pg_get_functiondef(p.oid) AS source
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_community_posts';
    """
    r8 = manager.execute_sql_auto(sql8)
    print(json.dumps(r8, indent=2, ensure_ascii=False))

    # ── 9. Source SQL de app_student_list_direct_messages ──
    print("\n=== 9. SOURCE SQL app_student_list_direct_messages ===")
    sql9 = """
    SELECT pg_get_functiondef(p.oid) AS source
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_direct_messages';
    """
    r9 = manager.execute_sql_auto(sql9)
    print(json.dumps(r9, indent=2, ensure_ascii=False))

    # ── 10. Échantillon de posts non-texte (audio/image/file) ──
    print("\n=== 10. POSTS NON-TEXTE (audio/image/file) ===")
    sql10 = """
    SELECT id, community_id, author_id, type, media_url, created_at
    FROM app.community_posts
    WHERE type != 'text' AND is_deleted = FALSE
    ORDER BY created_at DESC
    LIMIT 10;
    """
    r10 = manager.execute_sql_auto(sql10)
    print(json.dumps(r10, indent=2, ensure_ascii=False))

    # ── 11. Échantillon de DMs non-texte ──
    print("\n=== 11. DMs NON-TEXTE ===")
    sql11 = """
    SELECT id, conversation_id, sender_id, type, media_url, created_at
    FROM app.direct_messages
    WHERE type != 'text' AND is_deleted = FALSE
    ORDER BY created_at DESC
    LIMIT 10;
    """
    r11 = manager.execute_sql_auto(sql11)
    print(json.dumps(r11, indent=2, ensure_ascii=False))

    # ── 12. Bucket storage community-media ──
    print("\n=== 12. BUCKET STORAGE community-media ===")
    sql12 = """
    SELECT id, name, public, file_size_limit, allowed_mime_types
    FROM storage.buckets
    WHERE name = 'community-media';
    """
    r12 = manager.execute_sql_auto(sql12)
    print(json.dumps(r12, indent=2, ensure_ascii=False))

    # ── 13. Policies RLS sur storage.objects pour community-media ──
    print("\n=== 13. POLICIES STORAGE community-media ===")
    sql13 = """
    SELECT polname, polcmd
    FROM pg_policy
    WHERE polrelid = 'storage.objects'::regclass
      AND polname ILIKE '%community%';
    """
    r13 = manager.execute_sql_auto(sql13)
    print(json.dumps(r13, indent=2, ensure_ascii=False))

    # ── 14. Toutes les RPCs communauté/DM existantes ──
    print("\n=== 14. TOUTES LES RPCs COMMUNAUTÉ/DM ===")
    sql14 = """
    SELECT n.nspname AS schema, p.proname AS function_name
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE (p.proname LIKE 'app_student_%community%'
        OR p.proname LIKE 'app_admin_%community%'
        OR p.proname LIKE 'app_student_%dm%'
        OR p.proname LIKE 'app_student_%direct%')
    ORDER BY p.proname;
    """
    r14 = manager.execute_sql_auto(sql14)
    print(json.dumps(r14, indent=2, ensure_ascii=False))

    # ── 15. Vérifier existence table app.students (pour JOINs display_name) ──
    print("\n=== 15. COLONNES app.students (pour JOINs) ===")
    sql15 = """
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'students'
    ORDER BY ordinal_position;
    """
    r15 = manager.execute_sql_auto(sql15)
    print(json.dumps(r15, indent=2, ensure_ascii=False))

    # ── 16. Test RPC existence (HTTP) ──
    print("\n=== 16. TEST EXISTENCE RPCs (HTTP) ===")
    fake_uuid = "00000000-0000-0000-0000-000000000000"
    rpcs_to_test = [
        ("app_student_list_community_posts", {"p_community_id": fake_uuid}),
        ("app_student_add_community_post", {"p_community_id": fake_uuid, "p_content": "audit_test", "p_type": "text"}),
        ("app_student_send_direct_message", {"p_conversation_id": fake_uuid, "p_content": "audit_test"}),
        ("app_student_list_direct_messages", {"p_conversation_id": fake_uuid}),
        ("app_student_list_dm_conversations", {}),
        ("app_student_get_or_create_dm_conversation", {"p_other_user_id": fake_uuid}),
        ("app_student_mark_dm_read", {"p_conversation_id": fake_uuid}),
        ("app_student_edit_community_post", {"p_post_id": fake_uuid, "p_new_content": "audit"}),
        ("app_student_pin_community_post", {"p_post_id": fake_uuid, "p_is_pinned": True}),
        ("app_student_list_community_members", {"p_community_id": fake_uuid}),
        ("app_student_toggle_community_post_reaction", {"p_post_id": fake_uuid, "p_emoji": "👍"}),
        ("app_student_list_community_polls", {"p_community_id": fake_uuid}),
        ("app_student_create_community_poll", {"p_community_id": fake_uuid, "p_question": "test?", "p_options": ["a","b"]}),
    ]

    rpc_results = []
    for name, payload in rpcs_to_test:
        result = check_rpc(manager, name, payload)
        rpc_results.append(result)
        status_icon = "✅" if result["status"] in ("ok", "exists_but_error") else "❌"
        print(f"  {status_icon} {name}: {result['status']} (HTTP {result.get('http_status', '?')})")

    print("\n" + "=" * 70)
    print("FIN DE L'AUDIT")
    print("=" * 70)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
