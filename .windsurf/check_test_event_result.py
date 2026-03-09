#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get('rows', []) if isinstance(d, dict) else []
    print(f"\n{label}")
    for row in (rows or [])[:5]:
        print(" ", json.dumps(row, ensure_ascii=False, default=str)[:600])
    if not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

# Check the test event we just created (student_announcements / test)
q(m, "Test event result (most recent for TECNO user)", """
SELECT id, domain, event_type, created_at, processed_at, attempt_count, last_error
FROM app.notification_events
WHERE user_id = '9c09d123-286c-414c-8b52-b70054290924'
ORDER BY created_at DESC
LIMIT 3
""")
