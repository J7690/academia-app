#!/usr/bin/env python3
"""Phase 11 — Configure pg_cron + pg_net to call Edge Function send-push-notifications server-side."""
import json
import requests
from supabase_auto_manager import SupabaseAutoManager

def run_admin_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"{'✅' if ok else '❌'} {label}")
    if not ok:
        print(json.dumps(d, ensure_ascii=False, default=str)[:1200])
    return ok, d

m = SupabaseAutoManager()
project_url = m.url.rstrip('/')
edge_url = f"{project_url}/functions/v1/send-push-notifications"

print("Phase 11 — Deploy push cron job")
print("Edge URL:", edge_url)

sql = f"""
-- 1) Create helper function that calls Edge Function (no JWT required)
CREATE OR REPLACE FUNCTION app.app_run_send_push_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- pg_net returns a request id; we ignore it.
  PERFORM net.http_post(
    url := '{edge_url}',
    headers := '{{"Content-Type":"application/json"}}'::jsonb,
    body := '{{}}'::jsonb,
    timeout_milliseconds := 15000
  );
END;
$$;

REVOKE ALL ON FUNCTION app.app_run_send_push_notifications() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.app_run_send_push_notifications() TO postgres;
GRANT EXECUTE ON FUNCTION app.app_run_send_push_notifications() TO service_role;

-- 2) (Re)create cron job: every minute
DO $$
DECLARE
  v_job_id integer;
BEGIN
  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'academia_send_push_notifications'
  LIMIT 1;

  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;

  PERFORM cron.schedule(
    'academia_send_push_notifications',
    '*/1 * * * *',
    $cmd$SELECT app.app_run_send_push_notifications();$cmd$
  );
END;
$$;
"""

ok, _ = run_admin_sql(m, "Create function + schedule cron job", sql)

if ok:
    run_admin_sql(
        m,
        "Verify cron job exists",
        """
        SELECT jobid, jobname, schedule, command, nodename, nodeport, database, username, active
        FROM cron.job
        WHERE jobname = 'academia_send_push_notifications'
        ORDER BY jobid DESC
        LIMIT 5
        """,
    )

    run_admin_sql(
        m,
        "Check net schema availability",
        """
        SELECT EXISTS(
          SELECT 1
          FROM information_schema.schemata
          WHERE schema_name = 'net'
        ) AS net_schema_exists
        """,
    )
