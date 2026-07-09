#!/usr/bin/env python3
"""Fetch definitions of whiteboard RPCs."""
import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
}

names = [
    "whiteboard_create_project",
    "whiteboard_create_render_job",
    "whiteboard_get_render_status",
    "whiteboard_fetch_queued_jobs",
    "whiteboard_mark_done",
    "whiteboard_list_projects",
]

results = {}
for name in names:
    sql = f"""SELECT proname, pg_get_functiondef(p.oid) AS def
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname='{name}' AND n.nspname='public'"""
    for attempt in range(3):
        try:
            r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
            body = r.json()
            results[name] = body
            break
        except Exception as e:
            if attempt == 2:
                results[name] = {"error": str(e)}
            else:
                import time
                time.sleep(2)

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\tmp_supabase_rpc_defs_output.json"
with open(outfile, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"saved {outfile}")
