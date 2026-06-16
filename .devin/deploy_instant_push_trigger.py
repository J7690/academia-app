#!/usr/bin/env python3
"""Phase 14 — Create trigger on notification_events INSERT to instantly call Edge Function via pg_net."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"  {json.dumps(d, ensure_ascii=False, default=str)[:800]}")
    return ok

m = SupabaseAutoManager()
edge_url = f"{m.url.rstrip('/')}/functions/v1/send-push-notifications"

print("Phase 14 — Instant push trigger via pg_net")
print(f"Edge URL: {edge_url}\n")

sql = f"""
-- Function called by the trigger: fires pg_net HTTP POST immediately
CREATE OR REPLACE FUNCTION app.trg_instant_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
BEGIN
  -- Fire-and-forget HTTP POST to Edge Function
  PERFORM net.http_post(
    url := '{edge_url}',
    headers := '{{"Content-Type":"application/json"}}'::jsonb,
    body := '{{}}'::jsonb,
    timeout_milliseconds := 5000
  );
  RETURN NEW;
END;
$func$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS trg_notification_events_instant_push ON app.notification_events;

-- Create trigger: fires AFTER each INSERT
CREATE TRIGGER trg_notification_events_instant_push
  AFTER INSERT ON app.notification_events
  FOR EACH ROW
  EXECUTE FUNCTION app.trg_instant_push_notification();
"""

ok = run(m, "Create instant push trigger", sql)

if ok:
    # Verify
    run(m, "Verify trigger exists", """
    SELECT trigger_name, event_manipulation, action_statement
    FROM information_schema.triggers
    WHERE event_object_schema='app' AND event_object_table='notification_events'
    AND trigger_name='trg_notification_events_instant_push'
    """)
    print("\n✅ Push notifications are now INSTANT (< 5 seconds)")
    print("   The cron job remains as a safety net for any missed events.")
