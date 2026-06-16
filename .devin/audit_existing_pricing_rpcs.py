#!/usr/bin/env python3
"""Audit signatures des RPCs existantes pour la tarification."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:200]}

rpcs = [
    "app_admin_manage_credit_pack",
    "app_admin_manage_subscription_plan",
    "app_admin_manage_ai_action_price",
    "app_admin_upsert_short_training",
]

for rpc in rpcs:
    print(f"\n{'='*60}")
    print(f"RPC: {rpc}")
    print(f"{'='*60}")
    # Get args
    r = sql(f"""SELECT pg_get_function_arguments(oid) as args 
        FROM pg_proc WHERE proname = '{rpc}' LIMIT 1""")
    if isinstance(r, list) and len(r) > 0:
        print(f"  Args: {r[0].get('args')}")
    # Get first 400 chars of source
    r2 = sql(f"SELECT prosrc FROM pg_proc WHERE proname = '{rpc}' LIMIT 1")
    if isinstance(r2, list) and len(r2) > 0:
        src = r2[0].get('prosrc', '')
        print(f"  Source ({len(src)} chars):\n{src[:500]}")

# Also check td programs/local_groups for price column
print(f"\n{'='*60}")
print("TD PROGRAMS + LOCAL GROUPS columns")
print(f"{'='*60}")
for t in ["td_programs", "td_local_groups"]:
    r3 = sql(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='{t}' ORDER BY ordinal_position")
    if isinstance(r3, list):
        cols = [(c.get('column_name'), c.get('data_type')) for c in r3]
        print(f"\n  app.{t}: {cols}")
        # Sample data
        r3b = sql(f"SELECT * FROM app.{t} LIMIT 2")
        if isinstance(r3b, list):
            for row in r3b:
                print(f"    {row}")

# short_training table (parent of sessions)
print(f"\n{'='*60}")
print("SHORT TRAINING parent table columns")
print(f"{'='*60}")
r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='short_trainings' ORDER BY ordinal_position")
if isinstance(r4, list) and len(r4) > 0:
    for c in r4:
        print(f"  {c.get('column_name')} ({c.get('data_type')})")
    r4b = sql("SELECT * FROM app.short_trainings LIMIT 3")
    if isinstance(r4b, list):
        for row in r4b:
            print(f"  Data: {row}")
else:
    print("  Table app.short_trainings: NOT FOUND")

print("\nDone.")
