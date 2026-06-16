#!/usr/bin/env python3
"""Phase 6 — Audit avant implémentation read receipts + badges non-lus."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    print(f"\n-- {label} --")
    if isinstance(rows, list):
        for row in rows[:20]:
            print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:200]}")
        if not rows:
            print("  (0 rows)")
    else:
        print(f"  {d}")
    return rows if isinstance(rows, list) else []

def main():
    m = SupabaseAutoManager()

    # 1. support_read_states columns
    run_sql(m, "1. support_read_states columns",
        """SELECT column_name, data_type FROM information_schema.columns
           WHERE table_schema='app' AND table_name='support_read_states'
           ORDER BY ordinal_position""")

    # 2. support_messages columns
    run_sql(m, "2. support_messages columns",
        """SELECT column_name, data_type FROM information_schema.columns
           WHERE table_schema='app' AND table_name='support_messages'
           ORDER BY ordinal_position""")

    # 3. Existing conversations with messages (to understand data flow)
    run_sql(m, "3. Existing support conversations",
        """SELECT c.id, c.requester_role, c.requester_display_name, c.status,
                  c.last_message_at,
                  (SELECT COUNT(*) FROM app.support_messages sm WHERE sm.conversation_id = c.id) AS msg_count
           FROM app.support_conversations c
           ORDER BY c.last_message_at DESC NULLS LAST
           LIMIT 10""")

    # 4. Check existing RPCs related to support
    run_sql(m, "4. Existing support RPCs",
        """SELECT p.proname, pg_get_function_arguments(p.oid) AS args
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname = 'public' AND p.proname LIKE '%support%'
           ORDER BY p.proname""")

    # 5. Check if app_list_support_messages returns read info
    run_sql(m, "5. Source of app_list_support_messages",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname = 'public' AND p.proname = 'app_list_support_messages'""")

    # 6. Check if app_send_support_message source
    run_sql(m, "6. Source of app_send_support_message",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname = 'public' AND p.proname = 'app_send_support_message'""")

    print("\n-- AUDIT DONE --")

if __name__ == "__main__":
    main()
