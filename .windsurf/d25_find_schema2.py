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

# Chercher dans tous les schemas avec search_path
r = sql("""
SET search_path TO app, public;
SELECT schemaname, tablename 
FROM pg_tables 
WHERE tablename ILIKE '%whiteboard%' 
ORDER BY schemaname, tablename;
""")
print("TABLES (pg_tables):")
for row in r.get('rows', []):
    print(f"  {row.get('schemaname')}.{row.get('tablename')}")

# RPCs
r2 = sql("""
SET search_path TO app, public;
SELECT n.nspname AS schema, p.proname AS routine_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY n.nspname, p.proname;
""")
print("\nRPCs (pg_proc):")
for row in r2.get('rows', []):
    print(f"  {row.get('schema')}.{row.get('routine_name')}")
