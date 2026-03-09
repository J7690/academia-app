#!/usr/bin/env python3
"""Phase 8 — Audit rigoureux du système de notifications (visuelles + sonores).
Vérifie toute la chaîne: tables, RPC, Edge Functions, tokens, événements.
"""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'='*60}")
    print(f"AUDIT: {label}")
    print(f"{'='*60}")
    for row in rows[:20]:
        display = {}
        for k, v in row.items():
            sv = str(v) if v is not None else "NULL"
            display[k] = sv[:250] if len(sv) > 250 else sv
        print(f"  {json.dumps(display, ensure_ascii=False)}")
    if not rows:
        print("  (0 rows)")
    return rows

def main():
    m = SupabaseAutoManager()

    # 1. Check notification-related tables
    run_sql(m, "1. Tables notification/event dans schema app",
        """SELECT table_name FROM information_schema.tables
           WHERE table_schema='app'
           AND (table_name LIKE '%notif%' OR table_name LIKE '%event%'
                OR table_name LIKE '%device%' OR table_name LIKE '%token%'
                OR table_name LIKE '%seen%' OR table_name LIKE '%state%')
           ORDER BY table_name""")

    # 2. user_notification_state table structure
    run_sql(m, "2. Colonnes de app.user_notification_state",
        """SELECT column_name, data_type FROM information_schema.columns
           WHERE table_schema='app' AND table_name='user_notification_state'
           ORDER BY ordinal_position""")

    # 3. notification_events table structure
    run_sql(m, "3. Colonnes de app.notification_events",
        """SELECT column_name, data_type FROM information_schema.columns
           WHERE table_schema='app' AND table_name='notification_events'
           ORDER BY ordinal_position""")

    # 4. user_device_tokens table structure
    run_sql(m, "4. Colonnes de app.user_device_tokens",
        """SELECT column_name, data_type FROM information_schema.columns
           WHERE table_schema='app' AND table_name='user_device_tokens'
           ORDER BY ordinal_position""")

    # 5. Check if app_get_notification_summary RPC exists and its source
    run_sql(m, "5. Source de app_get_notification_summary (truncated)",
        """SELECT LEFT(pg_get_functiondef(p.oid), 800) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_get_notification_summary'""")

    # 6. Check if app_mark_domain_seen exists
    run_sql(m, "6. app_mark_domain_seen signature",
        """SELECT p.proname, pg_get_function_arguments(p.oid) AS args
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_mark_domain_seen'""")

    # 7. Check device tokens for our test student
    run_sql(m, "7. Device tokens enregistrés (sample)",
        """SELECT user_id, platform, LEFT(fcm_token, 30) AS token_prefix,
                  created_at, updated_at
           FROM app.user_device_tokens
           ORDER BY updated_at DESC
           LIMIT 10""")

    # 8. Check notification_events recent
    run_sql(m, "8. notification_events récents",
        """SELECT id, user_id, domain, LEFT(payload::text, 100) AS payload_preview,
                  is_read, created_at
           FROM app.notification_events
           ORDER BY created_at DESC
           LIMIT 10""")

    # 9. Check user_notification_state for our test student
    run_sql(m, "9. user_notification_state (sample)",
        """SELECT user_id, domain, last_seen_at, last_event_at
           FROM app.user_notification_state
           ORDER BY last_event_at DESC NULLS LAST
           LIMIT 20""")

    # 10. Test app_get_notification_summary directly for the test student
    run_sql(m, "10. Test direct app_get_notification_summary pour student connu",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_get_notification_summary'""")

    # 11. Check Edge Function send-push-notifications
    run_sql(m, "11. Check RPC app_register_device_token",
        """SELECT p.proname, pg_get_function_arguments(p.oid) AS args
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname LIKE '%register%device%token%'""")

    # 12. Check if there's any trigger on notification_events
    run_sql(m, "12. Triggers sur notification_events",
        """SELECT trigger_name, event_manipulation, action_statement
           FROM information_schema.triggers
           WHERE event_object_schema='app'
           AND event_object_table='notification_events'""")

    # 13. Count total notification_events by domain
    run_sql(m, "13. Nombre d'événements par domain",
        """SELECT domain, COUNT(*) as cnt, MAX(created_at) as last_event
           FROM app.notification_events
           GROUP BY domain
           ORDER BY cnt DESC""")

    # 14. Check the actual RPC response structure (via service_role impersonation)
    run_sql(m, "14. Source complète app_get_notification_summary (2000 chars)",
        """SELECT LEFT(pg_get_functiondef(p.oid), 2000) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_get_notification_summary'""")

    print(f"\n{'='*60}")
    print("AUDIT NOTIFICATIONS PHASE 8 TERMINÉ")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
