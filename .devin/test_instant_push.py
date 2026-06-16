#!/usr/bin/env python3
"""Test instant push: insert event, wait 10s, check if processed."""
import json, time, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    return d.get('rows', []) if isinstance(d, dict) and d.get('ok') else []

m = SupabaseAutoManager()

# Find most recent active android token user
rows = q(m, """
SELECT user_id FROM app.user_device_tokens
WHERE platform='android' AND is_active=true ORDER BY updated_at DESC LIMIT 1
""")
user_id = rows[0]['user_id'] if rows else None
if not user_id:
    print("❌ No active android token found"); exit(1)

print(f"User: {user_id}")

# Insert event
t0 = time.time()
q(m, f"""
INSERT INTO app.notification_events (user_id, domain, event_type, payload)
VALUES ('{user_id}', 'student_announcements', 'instant_test',
        '{{"title":"Test INSTANTANÉ","urgency":"normal"}}'::jsonb)
""")
print(f"Event inserted at t=0")

# Wait 10 seconds then check
time.sleep(10)
rows = q(m, f"""
SELECT id, created_at, processed_at, last_error,
       EXTRACT(EPOCH FROM (processed_at - created_at)) AS delay_seconds
FROM app.notification_events
WHERE user_id='{user_id}' AND event_type='instant_test'
ORDER BY created_at DESC LIMIT 1
""")

if rows:
    r = rows[0]
    delay = r.get('delay_seconds')
    err = r.get('last_error')
    processed = r.get('processed_at')
    if processed:
        print(f"✅ Processed! Delay: {delay}s | Error: {err or 'none'}")
        if delay and float(delay) < 15:
            print(f"🚀 INSTANTANÉ! Push envoyé en {delay}s (pas 60s)")
        else:
            print(f"⚠️ Délai: {delay}s — vérifier trigger")
    else:
        print(f"⏳ Not yet processed after 10s — trigger may not have fired")
else:
    print("❌ Event not found")
