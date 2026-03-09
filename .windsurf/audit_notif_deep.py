#!/usr/bin/env python3
"""Audit approfondi: source complète de app_get_notification_summary + test live."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n-- {label} --")
    for row in rows[:5]:
        for k, v in row.items():
            print(f"  {k}: {str(v)[:500]}")
        print()
    if not rows:
        print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

# 1. Full source of app_get_notification_summary
run_sql(m, "1. FULL SOURCE app_get_notification_summary",
    """SELECT pg_get_functiondef(p.oid) AS src
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE n.nspname='public' AND p.proname='app_get_notification_summary'""")

# 2. user_notification_state — is this table empty for all users?
run_sql(m, "2. user_notification_state count",
    """SELECT COUNT(*) as cnt FROM app.user_notification_state""")

# 3. notification_events — total count
run_sql(m, "3. notification_events total count",
    """SELECT COUNT(*) as cnt FROM app.notification_events""")

# 4. notification_events — last 5 for any user
run_sql(m, "4. notification_events last 5",
    """SELECT id, user_id, domain, is_read, created_at
       FROM app.notification_events
       ORDER BY created_at DESC LIMIT 5""")

# 5. Check if the Edge Function send-push-notifications exists
print("\n-- 5. Edge Function check --")
ef_url = f"{m.url}/functions/v1/send-push-notifications"
try:
    r = requests.post(ef_url, headers={
        "apikey": m.service_key,
        "Authorization": f"Bearer {m.service_key}",
        "Content-Type": "application/json"
    }, json={}, timeout=10)
    print(f"  HTTP {r.status_code}: {r.text[:300]}")
except Exception as e:
    print(f"  Error: {e}")

# 6. Check if there are triggers that insert into notification_events
run_sql(m, "6. ALL triggers in app schema (notification related)",
    """SELECT trigger_name, event_object_table, event_manipulation, action_statement
       FROM information_schema.triggers
       WHERE event_object_schema = 'app'
       ORDER BY event_object_table, trigger_name""")

# 7. Check if app_emit_notification_event exists
run_sql(m, "7. RPC app_emit_notification_event",
    """SELECT p.proname, pg_get_function_arguments(p.oid) AS args
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE n.nspname='public' AND p.proname LIKE '%emit%notif%'""")

# 8. Check all RPCs with 'notification' in name
run_sql(m, "8. ALL notification RPCs",
    """SELECT p.proname, pg_get_function_arguments(p.oid) AS args
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE n.nspname='public' AND p.proname LIKE '%notif%'
       ORDER BY p.proname""")

print("\n-- AUDIT DEEP DONE --")
