#!/usr/bin/env python3
"""AUDIT COMPLET — Chaîne notification Supabase (tables, triggers, RPCs, tokens, events, cron, Edge Function)."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    sym = "✅" if ok else "❌"
    print(f"\n{sym} {label}")
    if not ok:
        print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in (rows or [])[:15]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:500]}")
    if ok and not rows: print("  (0 rows)")
    return ok, rows

m = SupabaseAutoManager()
print("=" * 70)
print("AUDIT COMPLET NOTIFICATION — SUPABASE")
print("=" * 70)

# ===== 1. TABLES =====
q(m, "1a. notification_events columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns WHERE table_schema='app' AND table_name='notification_events' ORDER BY ordinal_position
""")

q(m, "1b. user_device_tokens columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns WHERE table_schema='app' AND table_name='user_device_tokens' ORDER BY ordinal_position
""")

q(m, "1c. user_notification_state columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns WHERE table_schema='app' AND table_name='user_notification_state' ORDER BY ordinal_position
""")

# ===== 2. TRIGGERS =====
q(m, "2. ALL triggers calling app_queue_notification_event (count)", """
SELECT COUNT(*) AS trigger_count FROM information_schema.triggers t
WHERE t.event_object_schema = 'app' AND t.action_statement LIKE '%notify%'
""")

# ===== 3. RPCs =====
q(m, "3a. app_register_device_token EXISTS", """
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='public' AND p.proname='app_register_device_token'
""")

q(m, "3b. app_get_notification_summary EXISTS", """
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='public' AND p.proname='app_get_notification_summary'
""")

q(m, "3c. app_queue_notification_event EXISTS", """
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='public' AND p.proname='app_queue_notification_event'
""")

q(m, "3d. app_run_send_push_notifications EXISTS", """
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='app' AND p.proname='app_run_send_push_notifications'
""")

# ===== 4. pg_cron =====
q(m, "4a. pg_cron extension", """
SELECT extname, extversion FROM pg_extension WHERE extname='pg_cron'
""")

q(m, "4b. pg_net extension", """
SELECT extname, extversion FROM pg_extension WHERE extname='pg_net'
""")

q(m, "4c. cron job details", """
SELECT jobid, jobname, schedule, command, active
FROM cron.job WHERE jobname='academia_send_push_notifications'
""")

q(m, "4d. cron last 5 runs", """
SELECT status, start_time, end_time, return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='academia_send_push_notifications' LIMIT 1)
ORDER BY start_time DESC LIMIT 5
""")

# ===== 5. DATA STATS =====
q(m, "5a. notification_events stats", """
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE processed_at IS NULL) AS pending,
  COUNT(*) FILTER (WHERE processed_at IS NOT NULL AND last_error IS NULL) AS success,
  COUNT(*) FILTER (WHERE processed_at IS NOT NULL AND last_error IS NOT NULL) AS failed,
  MAX(created_at) AS latest_created,
  MAX(processed_at) AS latest_processed
FROM app.notification_events
""")

q(m, "5b. user_device_tokens stats", """
SELECT platform, is_active, COUNT(*) AS cnt
FROM app.user_device_tokens
GROUP BY platform, is_active
ORDER BY platform, is_active DESC
""")

q(m, "5c. Active Android tokens (last 7 days)", """
SELECT id, user_id, LEFT(fcm_token, 40) AS token_prefix, updated_at
FROM app.user_device_tokens
WHERE platform='android' AND is_active=true AND updated_at > NOW() - INTERVAL '7 days'
ORDER BY updated_at DESC LIMIT 10
""")

# ===== 6. SIMULATION: inject test event + check =====
# Find the most recent active android token user
_, rows = q(m, "6a. Most recent active android token user", """
SELECT user_id, updated_at, LEFT(fcm_token, 40) AS token_prefix
FROM app.user_device_tokens
WHERE platform='android' AND is_active=true
ORDER BY updated_at DESC LIMIT 1
""")

if rows:
    test_user = rows[0]['user_id']
    print(f"\n  >> Test user: {test_user}")

    # Insert test event
    q(m, f"6b. INSERT test event for {test_user}", f"""
    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES ('{test_user}', 'student_announcements', 'audit_test',
            '{{"title":"AUDIT TEST Push","urgency":"normal"}}'::jsonb)
    RETURNING id, created_at
    """)

# ===== 7. Edge Function verification =====
print(f"\n{'='*70}")
print("7. Edge Function send-push-notifications")
ef_url = f"{m.url}/functions/v1/send-push-notifications"
try:
    r = requests.post(ef_url, headers={
        "Content-Type": "application/json",
    }, json={}, timeout=15)
    print(f"  HTTP {r.status_code}")
    body = r.text[:500] if r.text else "(empty)"
    print(f"  Response: {body}")
except Exception as e:
    print(f"  Error: {e}")

# ===== 8. RLS policies on notification tables =====
q(m, "8. RLS policies on notification tables", """
SELECT schemaname, tablename, policyname, permissive, roles, cmd, LEFT(qual::text, 80) AS qual
FROM pg_policies
WHERE schemaname='app' AND tablename IN ('notification_events','user_device_tokens','user_notification_state')
ORDER BY tablename, policyname
""")

print(f"\n{'='*70}")
print("AUDIT SUPABASE TERMINÉ")
print(f"{'='*70}")
