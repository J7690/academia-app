#!/usr/bin/env python3
"""Final deep audit: get app_queue_notification_event source + check why events are 0 for test student."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def sql(label, q):
    r = requests.post(url, headers=m.headers, json={"p_sql": q.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n-- {label} --")
    for row in rows[:10]:
        for k, v in row.items():
            print(f"  {k}: {str(v)[:600]}")
        print()
    if not rows: print("  (0 rows)")
    return rows

# 1. app_queue_notification_event source
sql("1. SOURCE app_queue_notification_event",
    """SELECT pg_get_functiondef(p.oid) AS src
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE p.proname='app_queue_notification_event'""")

# 2. Full source of app_get_notification_summary (get more chars)
sql("2. app_get_notification_summary FULL (4000 chars)",
    """SELECT LEFT(pg_get_functiondef(p.oid), 4000) AS src
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE n.nspname='public' AND p.proname='app_get_notification_summary'""")

# 3. ALL user_ids that HAVE notification_events
sql("3. Users with notification_events",
    """SELECT user_id, COUNT(*) as cnt
       FROM app.notification_events
       GROUP BY user_id ORDER BY cnt DESC LIMIT 10""")

# 4. Check our test student id in auth.users
sql("4. Test student auth.users check",
    """SELECT id, email, raw_user_meta_data->>'role' as role
       FROM auth.users WHERE id = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'""")

# 5. Check if notification_events has RLS that blocks
sql("5. RLS on notification_events",
    """SELECT relname, relrowsecurity
       FROM pg_class JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
       WHERE pg_namespace.nspname = 'app' AND relname = 'notification_events'""")

# 6. RLS policies on notification_events
sql("6. Policies on notification_events",
    """SELECT policyname, cmd, qual, with_check
       FROM pg_policies WHERE schemaname='app' AND tablename='notification_events'""")

# 7. user_notification_state — who has entries?
sql("7. user_notification_state sample",
    """SELECT user_id, domain, last_seen_at, last_event_at
       FROM app.user_notification_state
       LIMIT 10""")

print("\n-- DONE --")
