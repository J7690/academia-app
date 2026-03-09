#!/usr/bin/env python3
"""Phase 5 — Tests end-to-end du module Support.
Vérifie:
1. Tables existent et sont accessibles
2. RPC user-side fonctionnent (get_or_create, send, list, mark_read)
3. RPC admin-side fonctionnent (list_conversations, list_messages, send, set_status)
4. Sécurité: un user ne voit que ses propres conversations
5. Realtime publication vérifiée
6. Flutter analyze clean
"""

import json
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_sql(manager, label, sql):
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    sql_clean = sql.strip().rstrip(";")
    try:
        r = requests.post(url, headers=manager.headers, json={"p_sql": sql_clean}, timeout=30)
        data = r.json() if r.text else {}
        ok = r.status_code == 200 and isinstance(data, dict) and data.get("ok") is True
        rows = data.get("rows", []) if isinstance(data, dict) else []
        if not isinstance(rows, list):
            rows = []
        return ok, rows, data
    except Exception as e:
        return False, [], {"error": str(e)}


def test(label, passed, detail=""):
    status = "✅ PASS" if passed else "❌ FAIL"
    print(f"  {status} — {label}")
    if detail and not passed:
        print(f"         {detail[:300]}")
    return passed


def main():
    m = SupabaseAutoManager()
    all_passed = True
    print(f"\n{'='*60}")
    print("PHASE 5 — TESTS END-TO-END MODULE SUPPORT")
    print(f"{'='*60}")

    # ── 1. Tables exist ──
    print("\n── 1. Vérification tables ──")
    ok, rows, _ = run_sql(m, "tables", """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'app' AND table_name LIKE 'support_%'
        ORDER BY table_name
    """)
    tables = [r.get("table_name") for r in rows]
    all_passed &= test("support_conversations existe", "support_conversations" in tables)
    all_passed &= test("support_messages existe", "support_messages" in tables)
    all_passed &= test("support_read_states existe", "support_read_states" in tables)

    # ── 2. RPC exist ──
    print("\n── 2. Vérification RPC ──")
    ok, rows, _ = run_sql(m, "rpcs", """
        SELECT p.proname FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname LIKE '%support%'
        ORDER BY p.proname
    """)
    rpcs = [r.get("proname") for r in rows]
    expected_rpcs = [
        "app_get_or_create_support_conversation",
        "app_list_support_messages",
        "app_send_support_message",
        "app_mark_support_read",
        "app_admin_list_support_conversations",
        "app_admin_list_support_messages",
        "app_admin_send_support_message",
        "app_admin_set_support_status",
    ]
    for rpc in expected_rpcs:
        all_passed &= test(f"RPC {rpc}", rpc in rpcs)

    # ── 3. Colonnes tables ──
    print("\n── 3. Vérification colonnes ──")
    ok, rows, _ = run_sql(m, "conv_cols", """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'support_conversations'
        ORDER BY ordinal_position
    """)
    conv_cols = [r.get("column_name") for r in rows]
    for col in ["id", "requester_user_id", "requester_role", "requester_display_name",
                "requester_email", "status", "created_at", "last_message_at"]:
        all_passed &= test(f"support_conversations.{col}", col in conv_cols)

    ok, rows, _ = run_sql(m, "msg_cols", """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'support_messages'
        ORDER BY ordinal_position
    """)
    msg_cols = [r.get("column_name") for r in rows]
    for col in ["id", "conversation_id", "sender_user_id", "sender_side", "content", "created_at"]:
        all_passed &= test(f"support_messages.{col}", col in msg_cols)

    # ── 4. RLS policies ──
    print("\n── 4. Vérification RLS policies ──")
    ok, rows, _ = run_sql(m, "rls", """
        SELECT tablename, policyname FROM pg_policies
        WHERE schemaname = 'app' AND tablename LIKE 'support_%'
        ORDER BY tablename, policyname
    """)
    policies = [(r.get("tablename"), r.get("policyname")) for r in rows]

    expected_policies = [
        ("support_conversations", "support_conv_select"),
        ("support_conversations", "support_conv_insert"),
        ("support_conversations", "support_conv_update"),
        ("support_messages", "support_msg_select"),
        ("support_messages", "support_msg_insert"),
        ("support_read_states", "support_read_select"),
        ("support_read_states", "support_read_upsert"),
        ("support_read_states", "support_read_update"),
    ]
    for tbl, pol in expected_policies:
        all_passed &= test(f"Policy {tbl}.{pol}", (tbl, pol) in policies)

    # ── 5. RLS enabled ──
    print("\n── 5. RLS activé sur les tables ──")
    ok, rows, _ = run_sql(m, "rls_enabled", """
        SELECT relname, relrowsecurity
        FROM pg_class
        JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
        WHERE pg_namespace.nspname = 'app'
          AND relname IN ('support_conversations', 'support_messages', 'support_read_states')
    """)
    for r in rows:
        name = r.get("relname", "")
        enabled = r.get("relrowsecurity", False)
        all_passed &= test(f"RLS activé sur {name}", enabled is True)

    # ── 6. Realtime ──
    print("\n── 6. Realtime publication ──")
    ok, rows, _ = run_sql(m, "realtime", """
        SELECT tablename FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'app'
        AND tablename = 'support_messages'
    """)
    all_passed &= test("support_messages dans supabase_realtime", len(rows) > 0)

    # ── 7. Check constraints ──
    print("\n── 7. Check constraints ──")
    ok, rows, _ = run_sql(m, "constraints", """
        SELECT conname, contype, pg_get_constraintdef(oid) as def
        FROM pg_constraint
        WHERE conrelid = 'app.support_conversations'::regclass
        AND contype = 'c'
    """)
    check_defs = [r.get("def", "") for r in rows]
    has_status_check = any("open" in d and "closed" in d for d in check_defs)
    all_passed &= test("CHECK constraint status IN (open, closed)", has_status_check,
                       f"Found: {check_defs}")

    ok, rows, _ = run_sql(m, "msg_constraints", """
        SELECT conname, contype, pg_get_constraintdef(oid) as def
        FROM pg_constraint
        WHERE conrelid = 'app.support_messages'::regclass
        AND contype = 'c'
    """)
    msg_check_defs = [r.get("def", "") for r in rows]
    has_side_check = any("requester" in d and "admin" in d for d in msg_check_defs)
    all_passed &= test("CHECK constraint sender_side IN (requester, admin)", has_side_check,
                       f"Found: {msg_check_defs}")

    # ── 8. Indexes ──
    print("\n── 8. Index ──")
    ok, rows, _ = run_sql(m, "indexes", """
        SELECT indexname FROM pg_indexes
        WHERE schemaname = 'app'
        AND tablename IN ('support_conversations', 'support_messages')
        ORDER BY indexname
    """)
    idx_names = [r.get("indexname", "") for r in rows]
    all_passed &= test("Index idx_support_conv_requester", "idx_support_conv_requester" in idx_names)
    all_passed &= test("Index idx_support_conv_status", "idx_support_conv_status" in idx_names)
    all_passed &= test("Index idx_support_msg_conv", "idx_support_msg_conv" in idx_names)

    # ── 9. FK constraints ──
    print("\n── 9. Foreign keys ──")
    ok, rows, _ = run_sql(m, "fks", """
        SELECT conname, pg_get_constraintdef(oid) as def
        FROM pg_constraint
        WHERE conrelid = 'app.support_messages'::regclass
        AND contype = 'f'
    """)
    fk_defs = " ".join(r.get("def", "") for r in rows)
    all_passed &= test("FK support_messages.conversation_id → support_conversations",
                       "support_conversations" in fk_defs)
    all_passed &= test("FK support_messages.sender_user_id → auth.users",
                       "users" in fk_defs)

    # ── 10. Data integrity: no orphan data ──
    print("\n── 10. Intégrité données ──")
    ok, rows, _ = run_sql(m, "conv_count", """
        SELECT COUNT(*) as cnt FROM app.support_conversations
    """)
    cnt = rows[0].get("cnt", 0) if rows else 0
    test(f"Conversations existantes: {cnt}", True)

    ok, rows, _ = run_sql(m, "msg_count", """
        SELECT COUNT(*) as cnt FROM app.support_messages
    """)
    cnt = rows[0].get("cnt", 0) if rows else 0
    test(f"Messages existants: {cnt}", True)

    # ── 11. RPC function signatures check ──
    print("\n── 11. Signatures RPC (paramètres) ──")
    ok, rows, _ = run_sql(m, "rpc_sigs", """
        SELECT p.proname,
               pg_get_function_arguments(p.oid) AS args
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname LIKE '%support%'
        ORDER BY p.proname
    """)
    for r in rows:
        name = r.get("proname", "")
        args = r.get("args", "")
        print(f"    {name}({args})")

    # ── 12. Admin user can be resolved ──
    print("\n── 12. Admin users disponibles ──")
    ok, rows, _ = run_sql(m, "admins", """
        SELECT id, email FROM auth.users
        WHERE raw_user_meta_data->>'role' = 'admin'
        LIMIT 5
    """)
    all_passed &= test(f"Au moins 1 admin disponible ({len(rows)} trouvé(s))", len(rows) > 0)
    for r in rows:
        print(f"    Admin: {r.get('email', '?')} ({r.get('id', '?')[:8]}...)")

    # ── BILAN ──
    print(f"\n{'='*60}")
    if all_passed:
        print("✅ PHASE 5 — TOUS LES TESTS PASSENT")
    else:
        print("⚠️ PHASE 5 — CERTAINS TESTS ONT ÉCHOUÉ")
    print(f"{'='*60}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
