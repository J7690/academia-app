#!/usr/bin/env python3
"""D23 - Audit SQL contrats Supabase - sans point-virgule final"""
import requests
import json
import time
from datetime import datetime
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

session = requests.Session()
retry = Retry(total=3, backoff_factor=1)
session.mount("https://", HTTPAdapter(max_retries=retry))
ADMIN = URL + "/rest/v1/rpc/admin_execute_sql"

def q(label, sql):
    print(f"\n{'='*60}")
    print(f"[{label}]")
    time.sleep(0.4)
    sql_clean = sql.strip().rstrip(";")
    r = session.post(ADMIN, headers=H, json={"p_sql": sql_clean}, timeout=30)
    print(f"HTTP: {r.status_code}")
    try:
        b = r.json()
        print(json.dumps(b, ensure_ascii=False)[:4000])
        return b
    except:
        print(r.text[:500])
        return None

print(f"D23 SQL Audit (no semicolon) - {datetime.now().isoformat()}")

q("D23-SB-01 RETURN TYPE + ARGS whiteboard_create_project",
  "SELECT proname, pg_get_function_result(oid) AS return_type, pg_get_function_arguments(oid) AS arguments FROM pg_proc WHERE proname = 'whiteboard_create_project'")

q("D23-SB-02 PROSRC whiteboard_create_project",
  "SELECT proname, prosrc FROM pg_proc WHERE proname = 'whiteboard_create_project'")

q("D23-SB-03 FULL DEF whiteboard_create_project",
  "SELECT proname, pg_get_functiondef(oid) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_create_project'")

q("D23-SB-04 FULL DEF whiteboard_get_project",
  "SELECT proname, pg_get_functiondef(oid) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_get_project'")

q("D23-SB-05 COLUMNS whiteboard_projects",
  "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = 'whiteboard_projects' ORDER BY ordinal_position")

q("D23-SB-06 FULL DEF whiteboard_get_render_status",
  "SELECT proname, pg_get_functiondef(oid) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_get_render_status'")

q("D23-SB-07 COLUMNS whiteboard_renders",
  "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'whiteboard_renders' ORDER BY ordinal_position")

q("D23-SB-08 ALL whiteboard RPCs return types",
  "SELECT proname, pg_get_function_result(oid) AS return_type FROM pg_proc WHERE proname ILIKE '%whiteboard%' ORDER BY proname")

print(f"\nDone: {datetime.now().isoformat()}")
