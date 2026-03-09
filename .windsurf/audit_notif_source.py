#!/usr/bin/env python3
"""Get full source of app_get_notification_summary and key trigger functions."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

# 1. Full source - split into chunks to avoid truncation
for fn in [
    'app_get_notification_summary',
    'app_notify_application_message',
    'app_notify_admin_application_message',
]:
    sql = f"""SELECT pg_get_functiondef(p.oid) AS src
              FROM pg_catalog.pg_proc p
              JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
              WHERE n.nspname='public' AND p.proname='{fn}'"""
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    print(f"\n{'='*60}")
    print(f"SOURCE: {fn}")
    print(f"{'='*60}")
    if rows:
        src = rows[0].get("src", "")
        print(src)
    else:
        print("  NOT FOUND")

# 2. All triggers and their function sources
sql2 = """SELECT DISTINCT action_statement
          FROM information_schema.triggers
          WHERE event_object_schema = 'app'"""
r2 = requests.post(url, headers=m.headers, json={"p_sql": sql2.strip()}, timeout=30)
d2 = r2.json() if r2.text else {}
rows2 = d2.get("rows", []) if isinstance(d2, dict) else []
print(f"\n{'='*60}")
print("ALL TRIGGER ACTIONS:")
print(f"{'='*60}")
for row in rows2:
    print(f"  {row.get('action_statement', '')}")

# 3. notification_events for specific user
sql3 = """SELECT id, user_id, domain, is_read, created_at
          FROM app.notification_events
          WHERE user_id = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'
          ORDER BY created_at DESC LIMIT 10"""
r3 = requests.post(url, headers=m.headers, json={"p_sql": sql3.strip()}, timeout=30)
d3 = r3.json() if r3.text else {}
rows3 = d3.get("rows", []) if isinstance(d3, dict) else []
print(f"\n{'='*60}")
print("NOTIFICATION_EVENTS for test student (6745c7ad...):")
print(f"{'='*60}")
for row in rows3:
    print(f"  {json.dumps(row, ensure_ascii=False, default=str)}")
if not rows3:
    print("  (0 rows)")

# 4. user_notification_state for test student
sql4 = """SELECT domain, last_seen_at, last_event_at
          FROM app.user_notification_state
          WHERE user_id = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'
          ORDER BY domain"""
r4 = requests.post(url, headers=m.headers, json={"p_sql": sql4.strip()}, timeout=30)
d4 = r4.json() if r4.text else {}
rows4 = d4.get("rows", []) if isinstance(d4, dict) else []
print(f"\n{'='*60}")
print("USER_NOTIFICATION_STATE for test student:")
print(f"{'='*60}")
for row in rows4:
    print(f"  {json.dumps(row, ensure_ascii=False, default=str)}")
if not rows4:
    print("  (0 rows)")

# 5. Check notification_events NOT empty - maybe it's RLS blocking
sql5 = """SELECT COUNT(*) as cnt FROM app.notification_events"""
r5 = requests.post(url, headers=m.headers, json={"p_sql": sql5.strip()}, timeout=30)
d5 = r5.json() if r5.text else {}
rows5 = d5.get("rows", []) if isinstance(d5, dict) else []
print(f"\nTotal notification_events (via service_role): {rows5[0].get('cnt') if rows5 else '?'}")

sql6 = """SELECT ne.domain, ne.user_id, ne.created_at, ne.is_read
          FROM app.notification_events ne
          ORDER BY ne.created_at DESC LIMIT 5"""
r6 = requests.post(url, headers=m.headers, json={"p_sql": sql6.strip()}, timeout=30)
d6 = r6.json() if r6.text else {}
rows6 = d6.get("rows", []) if isinstance(d6, dict) else []
print(f"\nLatest 5 notification_events (all users):")
for row in rows6:
    print(f"  {json.dumps(row, ensure_ascii=False, default=str)}")
