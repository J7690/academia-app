#!/usr/bin/env python3
"""D23 - Audit contrat Supabase : SQL réel de whiteboard_create_project"""
import requests
import json
from datetime import datetime

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SKEY,
    "Authorization": "Bearer " + SKEY,
    "Content-Type": "application/json",
}

def rpc_sql(label, sql):
    print(f"\n=== {label} ===")
    r = requests.post(f"{URL}/rest/v1/rpc/execute_ddl", headers=HEADERS,
                      json={"ddl_query": sql}, timeout=30)
    if r.status_code in (200, 201):
        try:
            body = r.json()
            print(json.dumps(body, ensure_ascii=False)[:2000])
            return body
        except:
            print(r.text[:1000])
    else:
        # Try admin_execute_sql
        r2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=HEADERS,
                           json={"p_sql": sql}, timeout=30)
        print(f"HTTP (execute_ddl={r.status_code}) -> admin_execute_sql={r2.status_code}")
        try:
            body2 = r2.json()
            print(json.dumps(body2, ensure_ascii=False)[:2000])
            return body2
        except:
            print(r2.text[:1000])
    return None

def rest_rpc(name, payload, label=""):
    print(f"\n=== RPC: {name} | {label} ===")
    r = requests.post(f"{URL}/rest/v1/rpc/{name}", headers=HEADERS, json=payload, timeout=20)
    print(f"HTTP STATUS: {r.status_code}")
    try:
        body = r.json()
        print(f"BODY TYPE: {type(body).__name__}")
        print(json.dumps(body, ensure_ascii=False)[:1500])
        return r.status_code, body
    except:
        print(r.text[:500])
        return r.status_code, None

print(f"D23 Supabase Contract Audit - {datetime.now().isoformat()}")

# 1. SQL source de whiteboard_create_project
rpc_sql("D23-SB-01 : SQL source de whiteboard_create_project",
    """SELECT p.proname, pg_get_functiondef(p.oid) as definition
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE p.proname = 'whiteboard_create_project';""")

# 2. Type de retour déclaré
rpc_sql("D23-SB-02 : RETURNS type de whiteboard_create_project",
    """SELECT p.proname,
              pg_get_function_result(p.oid) as return_type,
              pg_get_function_arguments(p.oid) as arguments
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE p.proname = 'whiteboard_create_project';""")

# 3. Colonnes de whiteboard_projects
rpc_sql("D23-SB-03 : Colonnes de whiteboard_projects",
    """SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
       WHERE table_name = 'whiteboard_projects'
       ORDER BY ordinal_position;""")

# 4. SQL source de whiteboard_get_project
rpc_sql("D23-SB-04 : SQL source de whiteboard_get_project",
    """SELECT p.proname, pg_get_functiondef(p.oid) as definition
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE p.proname = 'whiteboard_get_project';""")

# 5. SQL source whiteboard_get_render_status (cassée)
rpc_sql("D23-SB-05 : SQL source de whiteboard_get_render_status",
    """SELECT p.proname, pg_get_functiondef(p.oid) as definition
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE p.proname = 'whiteboard_get_render_status';""")

# 6. Colonnes de whiteboard_renders
rpc_sql("D23-SB-06 : Colonnes de whiteboard_renders",
    """SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
       WHERE table_name = 'whiteboard_renders'
       ORDER BY ordinal_position;""")

# 7. Test runtime whiteboard_create_project avec student_id réel
rest_rpc("whiteboard_create_project", {
    "p_student_id": "6745c7ad-732b-47d0-b5b8-06d6dcf286ff",
    "p_subject": "D23_AUDIT_CONTRAT",
    "p_renderer_id": "notebook",
    "p_theme_id": "notebook",
    "p_narration_mode": "tts",
    "p_storyboard_json": {}
}, "D23-SB-07 : Appel réel avec student_id de l'utilisateur test")

print(f"\nTimestamp fin: {datetime.now().isoformat()}")
