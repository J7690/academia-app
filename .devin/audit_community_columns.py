#!/usr/bin/env python3
"""Audit colonnes des tables communautaires + students"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    # Try p_sql first (admin_execute_sql), then sql_query (execute_sql)
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, dict) and "result" in data:
            return data["result"]
        return data
    # Fallback to execute_sql
    r2 = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=30)
    if r2.status_code == 200:
        return r2.json()
    return {"error": r.status_code, "error2": r2.status_code}

tables = [
    "community_post_reactions",
    "community_polls",
    "community_poll_votes",
    "community_read_states",
    "students",
    "communities",
]

for t in tables:
    print(f"\n=== {t} ===")
    res = sql(f"SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='{t}' ORDER BY ordinal_position")
    if isinstance(res, dict) and "result" in res:
        res = res["result"]
    if isinstance(res, list):
        for row in res:
            cn = row.get("column_name","?")
            dt = row.get("data_type","?")
            nu = row.get("is_nullable","?")
            df = row.get("column_default","")
            print(f"  {cn:30s} {dt:25s} null={nu}  default={df}")
    else:
        print(f"  {json.dumps(res, default=str)}")

# Check RPCs source for reactions/polls
print("\n=== RPC SOURCES (reactions/polls/read) ===")
res = sql("""
    SELECT p.proname, pg_get_functiondef(p.oid) as src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.proname LIKE '%reaction%' OR p.proname LIKE '%poll%' OR p.proname LIKE '%mark%read%')
    ORDER BY p.proname
""")
if isinstance(res, dict) and "result" in res:
    res = res["result"]
if isinstance(res, list):
    for row in res:
        name = row.get("proname", "?")
        src = row.get("src", "")
        print(f"\n--- {name} ---")
        print(src[:600] if len(src) > 600 else src)
else:
    print(json.dumps(res, default=str))

print("\n\nDone.")
