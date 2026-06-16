#!/usr/bin/env python3
"""Audit runtime for push cron + pg_net calls."""
import json
import requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok:
        print(json.dumps(d, ensure_ascii=False, default=str)[:1500])
        return None
    rows = d.get('rows', [])
    for row in (rows or [])[:20]:
        print(" ", json.dumps(row, ensure_ascii=False, default=str)[:500])
    if not rows:
        print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

# Identify job
job = q(m, "cron.job row", """
SELECT jobid, jobname, schedule, command, active, username, database
FROM cron.job
WHERE jobname = 'academia_send_push_notifications'
LIMIT 5
""")

jobid = job[0]['jobid'] if job else None

if jobid is not None:
    q(m, "cron.job_run_details last 10", f"""
    SELECT jobid, status, start_time, end_time, return_message
    FROM cron.job_run_details
    WHERE jobid = {jobid}
    ORDER BY start_time DESC
    LIMIT 10
    """)

# net http responses (pg_net)
# Table exists in net schema on Supabase when pg_net enabled
q(m, "net._http_response last 10", """
SELECT id, status_code, created, url, LEFT(content::text, 200) AS content
FROM net._http_response
ORDER BY created DESC
LIMIT 10
""")

# pending events
q(m, "notification_events pending/processed counts", """
SELECT
  COUNT(*) FILTER (WHERE processed_at IS NULL) AS pending,
  COUNT(*) FILTER (WHERE processed_at IS NOT NULL) AS processed,
  MAX(created_at) AS latest_event_at,
  MAX(processed_at) AS latest_processed_at
FROM app.notification_events
""")

# show pending events sample
q(m, "sample pending events", """
SELECT id, user_id, domain, event_type, created_at, attempt_count, last_error
FROM app.notification_events
WHERE processed_at IS NULL
ORDER BY created_at DESC
LIMIT 10
""")

# show processed events sample
q(m, "sample processed events", """
SELECT id, user_id, domain, event_type, created_at, processed_at, attempt_count, last_error
FROM app.notification_events
WHERE processed_at IS NOT NULL
ORDER BY processed_at DESC
LIMIT 10
""")

# tokens sanity
q(m, "android active tokens count", """
SELECT COUNT(*) AS active_android_tokens
FROM app.user_device_tokens
WHERE platform='android' AND is_active=true
""")
