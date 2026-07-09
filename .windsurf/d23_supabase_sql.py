#!/usr/bin/env python3
"""D23 - Audit SQL contrats Supabase via execute_sql (SELECT) et pg_proc directement"""
import requests
import json
from datetime import datetime

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(label, query):
    print(f"\n{'='*60}")
    print(f"[{label}]")
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql",
                      headers=H, json={"sql_query": query}, timeout=30)
    print(f"HTTP: {r.status_code}")
    try:
        b = r.json()
        out = json.dumps(b, ensure_ascii=False)
        print(out[:3000])
        return b
    except:
        print(r.text[:1000])
        return None

print(f"D23 SQL Audit - {datetime.now().isoformat()}")

# D23-SB-01 : Type de retour et arguments de whiteboard_create_project
sql("D23-SB-01 RETURNS + ARGS whiteboard_create_project",
    """SELECT proname,
              pg_get_function_result(oid) AS return_type,
              pg_get_function_arguments(oid) AS arguments
       FROM pg_proc
       WHERE proname = 'whiteboard_create_project';""")

# D23-SB-02 : Corps SQL de whiteboard_create_project
sql("D23-SB-02 BODY whiteboard_create_project",
    """SELECT proname, prosrc
       FROM pg_proc
       WHERE proname = 'whiteboard_create_project';""")

# D23-SB-03 : Corps SQL de whiteboard_get_project
sql("D23-SB-03 BODY whiteboard_get_project",
    """SELECT proname, prosrc
       FROM pg_proc
       WHERE proname = 'whiteboard_get_project';""")

# D23-SB-04 : Colonnes de whiteboard_projects
sql("D23-SB-04 COLUMNS whiteboard_projects",
    """SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
       WHERE table_name = 'whiteboard_projects'
       ORDER BY ordinal_position;""")

# D23-SB-05 : Corps SQL de whiteboard_get_render_status (cassée SQL 42703)
sql("D23-SB-05 BODY whiteboard_get_render_status",
    """SELECT proname, prosrc
       FROM pg_proc
       WHERE proname = 'whiteboard_get_render_status';""")

# D23-SB-06 : Colonnes de whiteboard_renders
sql("D23-SB-06 COLUMNS whiteboard_renders",
    """SELECT column_name, data_type, is_nullable
       FROM information_schema.columns
       WHERE table_name = 'whiteboard_renders'
       ORDER BY ordinal_position;""")

# D23-SB-07 : Toutes les RPCs whiteboard + signature + return type
sql("D23-SB-07 ALL whiteboard RPCs return types",
    """SELECT proname,
              pg_get_function_result(oid) AS return_type,
              pg_get_function_arguments(oid) AS arguments
       FROM pg_proc
       WHERE proname ILIKE '%whiteboard%'
       ORDER BY proname;""")

print(f"\nDone: {datetime.now().isoformat()}")
