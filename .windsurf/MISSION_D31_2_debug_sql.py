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
    print("SQL:", sql)
    print("Status:", resp.status_code)
    print("Response:", resp.text[:2000])
    return resp.json()

print("=== Project query ===")
result = execute_sql(f"SELECT id, subject, storyboard_json FROM app.whiteboard_projects WHERE id = '{PROJECT_ID}'")

print("\n=== Insert render job ===")
result2 = execute_sql(f"INSERT INTO app.whiteboard_renders (project_id, status, progress) VALUES ('{PROJECT_ID}', 'queued', 0) RETURNING id")
