#!/usr/bin/env python3
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

# Trouver le schema des tables whiteboard
r = sql("SELECT table_schema, table_name FROM information_schema.tables WHERE table_name ILIKE '%whiteboard%' ORDER BY table_schema, table_name;")
print("TABLES WHITEBOARD:")
for row in r.get('rows', []):
    print(f"  {row.get('table_schema')}.{row.get('table_name')}")

# Lister les RPCs whiteboard dans tous schemas
r2 = sql("SELECT routine_schema, routine_name FROM information_schema.routines WHERE routine_name ILIKE '%whiteboard%' ORDER BY routine_schema, routine_name;")
print("\nRPCs WHITEBOARD:")
for row in r2.get('rows', []):
    print(f"  {row.get('routine_schema')}.{row.get('routine_name')}")
