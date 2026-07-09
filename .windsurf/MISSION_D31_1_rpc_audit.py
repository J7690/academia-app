#!/usr/bin/env python3
"""MISSION D31.1 — Audit des définitions RPC de fetch_queued_jobs et create_render_job."""
import requests
import json
import time

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}


def execute_sql(sql):
    sql = sql.strip().rstrip(';')
    for attempt in range(3):
        try:
            resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=60)
            resp.raise_for_status()
            return resp.json()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


rpcs = ['whiteboard_fetch_queued_jobs', 'whiteboard_create_render_job', 'whiteboard_mark_done']
results = {}
for rpc in rpcs:
    sql = f"""
SELECT proname, nspname, pg_get_functiondef(p.oid) AS def
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname='{rpc}'
"""
    results[rpc] = execute_sql(sql)

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\MISSION_D31_1_rpc_audit_output.json"
with open(outfile, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"Saved {outfile}")
print(json.dumps(results, indent=2, ensure_ascii=False))
