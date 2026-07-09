#!/usr/bin/env python3
"""MISSION D.27B — Définitions des 3 RPCs editor (lecture seule)."""
import httpx
import json
import time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
}


def execute_sql(sql):
    sql = sql.strip().rstrip(';')
    for attempt in range(3):
        try:
            with httpx.Client(timeout=60) as client:
                resp = client.post(URL, headers=HEADERS, json={"p_sql": sql})
                resp.raise_for_status()
                return resp.json()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


names = [
    "whiteboard_get_project",
    "whiteboard_update_project",
    "whiteboard_delete_project",
    "whiteboard_list_projects",
    "whiteboard_create_project",
]
results = {}
for name in names:
    sql = f"""SELECT p.proname, n.nspname, pg_get_functiondef(p.oid) AS def
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname='{name}' AND n.nspname='public'"""
    results[name] = execute_sql(sql)

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\MISSION_D27B_rpc_defs_output.json"
with open(outfile, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"Saved {outfile}")
print(json.dumps(results, indent=2, ensure_ascii=False))
