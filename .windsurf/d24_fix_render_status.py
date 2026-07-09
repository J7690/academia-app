#!/usr/bin/env python3
"""D24 - FIX #2 : Retirer wr.file_size_bytes de whiteboard_get_render_status via execute_ddl"""
import requests
import json
import time
from datetime import datetime
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

sess = requests.Session()
sess.mount("https://", HTTPAdapter(max_retries=Retry(total=3, backoff_factor=1)))

def ddl(label, sql):
    print(f"\n{'='*60}")
    print(f"[{label}]")
    time.sleep(0.5)
    r = sess.post(f"{URL}/rest/v1/rpc/execute_ddl", headers=H,
                  json={"ddl_query": sql}, timeout=30)
    print(f"HTTP: {r.status_code}")
    try:
        b = r.json()
        print(json.dumps(b, ensure_ascii=False)[:2000])
        return r.status_code, b
    except:
        print(r.text[:500])
        return r.status_code, None

def admin_sql(label, sql):
    print(f"\n{'='*60}")
    print(f"[{label}]")
    time.sleep(0.5)
    r = sess.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                  json={"p_sql": sql.strip().rstrip(";")}, timeout=30)
    print(f"HTTP: {r.status_code}")
    try:
        b = r.json()
        print(json.dumps(b, ensure_ascii=False)[:3000])
        return r.status_code, b
    except:
        print(r.text[:500])
        return r.status_code, None

def rest_rpc(name, payload):
    print(f"\n{'='*60}")
    print(f"[TEST RPC: {name}]")
    time.sleep(0.5)
    r = sess.post(f"{URL}/rest/v1/rpc/{name}", headers=H, json=payload, timeout=20)
    print(f"HTTP: {r.status_code}")
    try:
        b = r.json()
        print(json.dumps(b, ensure_ascii=False)[:1000])
        return r.status_code, b
    except:
        print(r.text[:500])
        return r.status_code, None

print(f"D24 FIX #2 - {datetime.now().isoformat()}")

# STEP 1 : Lire le SQL actuel pour vérifier avant modification
admin_sql("D24-PRE : SQL actuel de whiteboard_get_render_status",
    "SELECT left(pg_get_functiondef(oid),3000) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_get_render_status'")

# STEP 2 : Recréer la fonction SANS wr.file_size_bytes via execute_ddl
FIX_SQL = """
CREATE OR REPLACE FUNCTION public.whiteboard_get_render_status(p_render_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  render_record RECORD;
  result JSONB;
BEGIN
  SELECT
    wr.id,
    wr.project_id,
    wr.status,
    wr.video_url,
    wr.duration_ms,
    wr.created_at,
    wr.completed_at,
    wr.error_message,
    wr.progress
  INTO render_record
  FROM app.whiteboard_renders wr
  JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
  WHERE wr.id = p_render_id
  AND wp.student_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Render not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'render', to_jsonb(render_record)
  );

  RETURN result;
END;
$$
"""

status, body = ddl("D24-FIX2 : CREATE OR REPLACE whiteboard_get_render_status (sans file_size_bytes)", FIX_SQL)

# STEP 3 : Vérifier le nouveau SQL
admin_sql("D24-POST : SQL après correction de whiteboard_get_render_status",
    "SELECT left(pg_get_functiondef(oid),3000) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_get_render_status'")

# STEP 4 : Test live avec un render_id connu (même si 'not found' c'est OK — pas d'erreur SQL 400)
KNOWN_RENDER_ID = "fd9e3969-be64-45a9-8e95-00606ac51446"
rest_rpc("whiteboard_get_render_status", {"p_render_id": KNOWN_RENDER_ID})

print(f"\nTimestamp fin: {datetime.now().isoformat()}")
