#!/usr/bin/env python3
"""Audit complet push pour TECNO KG7h — token, events, Edge Function, trigger."""
import json, time, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in (rows or [])[:15]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:500]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()
print("=" * 70)
print("AUDIT TECNO KG7h — PUSH NOTIFICATIONS")
print("=" * 70)

# 1. ALL active tokens (android) — sorted by most recent
rows = q(m, "1. ALL active Android tokens (most recent first)", """
SELECT id, user_id, LEFT(fcm_token, 50) AS token_prefix, 
       platform, is_active, updated_at, created_at,
       LEFT(device_info::text, 100) AS device_info
FROM app.user_device_tokens
WHERE platform = 'android' AND is_active = true
ORDER BY updated_at DESC
""")

# 2. ALL tokens for nexiomgroup user (6745c7ad)
q(m, "2. ALL tokens for nexiomgroup (6745c7ad) — active AND inactive", """
SELECT id, LEFT(fcm_token, 50) AS token_prefix, platform, is_active, 
       updated_at, created_at
FROM app.user_device_tokens
WHERE user_id = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'
ORDER BY updated_at DESC
""")

# 3. ALL tokens for admin user (040e7e6e)
q(m, "3. ALL tokens for admin (040e7e6e) — active AND inactive", """
SELECT id, LEFT(fcm_token, 50) AS token_prefix, platform, is_active, 
       updated_at, created_at
FROM app.user_device_tokens
WHERE user_id = '040e7e6e-2763-46b8-963f-8d0e713f3336'
ORDER BY updated_at DESC
""")

# 4. Recent notification events (last 2 hours)
q(m, "4. Recent notification events (last 2h)", """
SELECT id, user_id, domain, event_type, created_at, processed_at, 
       attempt_count, LEFT(last_error, 150) AS last_error
FROM app.notification_events
WHERE created_at > NOW() - INTERVAL '2 hours'
ORDER BY created_at DESC
LIMIT 15
""")

# 5. Pending events
q(m, "5. Pending events (processed_at IS NULL)", """
SELECT COUNT(*) AS pending FROM app.notification_events WHERE processed_at IS NULL
""")

# 6. Trigger exists?
q(m, "6. Instant push trigger exists?", """
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_schema='app' AND event_object_table='notification_events'
""")

# 7. Cron last runs
q(m, "7. Cron last 3 runs", """
SELECT status, start_time, end_time, return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='academia_send_push_notifications' LIMIT 1)
ORDER BY start_time DESC LIMIT 3
""")

# 8. Edge Function direct call test
print(f"\n{'='*70}")
print("8. Edge Function direct call test")
ef_url = f"{m.url.rstrip('/')}/functions/v1/send-push-notifications"
try:
    r = requests.post(ef_url, headers={"Content-Type": "application/json"}, json={}, timeout=15)
    print(f"  HTTP {r.status_code} — {r.text[:300]}")
except Exception as e:
    print(f"  Error: {e}")

# 9. Inject test event for nexiomgroup AND check instant processing
print(f"\n{'='*70}")
print("9. SIMULATION: inject event + check instant processing")
test_user = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'
t0 = time.time()
q(m, f"Insert test event for {test_user}", f"""
INSERT INTO app.notification_events (user_id, domain, event_type, payload)
VALUES ('{test_user}', 'student_announcements', 'tecno_kgh7_test',
        '{{"title":"TEST TECNO KG7h","urgency":"critical"}}'::jsonb)
""")
time.sleep(8)
rows = q(m, "Check if processed (after 8s)", f"""
SELECT id, created_at, processed_at, last_error,
       EXTRACT(EPOCH FROM (processed_at - created_at)) AS delay_seconds
FROM app.notification_events
WHERE user_id='{test_user}' AND event_type='tecno_kgh7_test'
ORDER BY created_at DESC LIMIT 1
""")

if rows and rows[0].get('processed_at'):
    delay = rows[0].get('delay_seconds', '?')
    err = rows[0].get('last_error')
    print(f"\n  🚀 Processed in {delay}s | Error: {err or 'NONE'}")
else:
    print(f"\n  ⏳ NOT processed after 8s")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
