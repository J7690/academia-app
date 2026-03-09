#!/usr/bin/env python3
"""Check if a fresh FCM token was registered after TECNO app launch."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"\n{'OK' if ok else 'ERR'} {label}")
    if not ok:
        print(json.dumps(d, ensure_ascii=False, default=str)[:500])
        return []
    rows = d.get('rows', [])
    for row in (rows or [])[:10]:
        print(" ", json.dumps(row, ensure_ascii=False, default=str)[:400])
    if not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

# Recent android tokens
q(m, "Recent active android tokens (last 30 min)", """
SELECT id, user_id, platform, LEFT(fcm_token, 30) AS token_prefix, 
       is_active, last_seen_at, updated_at
FROM app.user_device_tokens
WHERE platform = 'android' AND is_active = true
ORDER BY updated_at DESC
LIMIT 10
""")

# All active tokens count by platform
q(m, "Active tokens by platform", """
SELECT platform, COUNT(*) AS cnt
FROM app.user_device_tokens
WHERE is_active = true
GROUP BY platform
""")

# pending events
q(m, "Pending notification events", """
SELECT COUNT(*) AS pending FROM app.notification_events WHERE processed_at IS NULL
""")
