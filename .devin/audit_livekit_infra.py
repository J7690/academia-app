#!/usr/bin/env python3
"""Audit Supabase pour infrastructure LiveKit / sessions live."""
import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

def exec_sql(sql):
    sql = sql.strip().rstrip(";")
    for rpc_name in ["admin_execute_sql", "execute_sql"]:
        try:
            r = requests.post(f"{URL}/rest/v1/rpc/{rpc_name}",
                              headers=HEADERS, json={"sql_query": sql}, timeout=30)
            if r.status_code == 200:
                return r.json()
        except:
            pass
    return {"error": "both RPCs failed"}

print("=" * 60)
print("1. Tables live_session / online_course_live")
print("=" * 60)
result = exec_sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('app', 'public')
  AND (table_name ILIKE '%live_session%'
    OR table_name ILIKE '%live_participant%'
    OR table_name ILIKE '%online_course_live%'
    OR table_name ILIKE '%prep_live%')
ORDER BY table_schema, table_name
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("2. Row counts")
print("=" * 60)
if isinstance(result, list):
    for row in result:
        tbl = f"{row['table_schema']}.{row['table_name']}"
        cnt = exec_sql(f"SELECT count(*) as cnt FROM {tbl}")
        print(f"  {tbl}: {json.dumps(cnt, default=str)}")

print("\n" + "=" * 60)
print("3. RPCs live_session")
print("=" * 60)
result = exec_sql("""
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
  AND (routine_name ILIKE '%live_session%'
    OR routine_name ILIKE '%livekit%')
ORDER BY routine_name
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("4. Colonnes prep_live_sessions")
print("=" * 60)
result = exec_sql("""
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'prep_live_sessions'
ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("5. Edge Functions deployees (via supabase schema)")
print("=" * 60)
# Check if there's a livekit edge function
r = requests.get(f"{URL}/functions/v1/livekit-token",
                 headers={"Authorization": f"Bearer {SERVICE_KEY}"})
print(f"  livekit-token: HTTP {r.status_code} - {r.text[:200]}")

print("\nAudit termine.")
