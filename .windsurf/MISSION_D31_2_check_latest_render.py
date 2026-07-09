#!/usr/bin/env python3
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
ADMIN_RPC = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ADMIN_HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

PROJECT_ID = "3993bb85-1818-407b-810e-4bcfe1b983fa"

def execute_sql(sql):
    resp = requests.post(ADMIN_RPC, headers=ADMIN_HEADERS, json={"p_sql": sql}, timeout=60)
    resp.raise_for_status()
    return resp.json()

sql = f"""
SELECT id, status, video_url, duration_ms, error_message, created_at, completed_at
FROM app.whiteboard_renders
WHERE project_id = '{PROJECT_ID}'
ORDER BY created_at DESC
LIMIT 5
"""
result = execute_sql(sql)
print(json.dumps(result, indent=2, ensure_ascii=False))
