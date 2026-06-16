#!/usr/bin/env python3
"""Fix: ajouter 'short_training' dans app_confirm_ligdicash_payment."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else None

def ddl(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl", headers=HEADERS, json={"ddl_query": q}, timeout=30)
    return r.status_code, r.text[:300]

# 1. Get current source
print("1. Getting current RPC source...")
result = sql("SELECT pg_get_functiondef(oid) AS def FROM pg_proc WHERE proname = 'app_confirm_ligdicash_payment' LIMIT 1")
if not result or not isinstance(result, list) or len(result) == 0:
    print("ERROR: Could not get RPC source")
    exit(1)

src = result[0].get("def", "")
print(f"   Source length: {len(src)} chars")

# 2. Check if already fixed
if "'short_training'" in src:
    print("   Already contains 'short_training' - nothing to do!")
    exit(0)

# 3. Fix: replace the condition
old_condition = "p_payment_type = 'application' OR p_payment_type = 'subscription' OR p_payment_type = 'td'"
new_condition = "p_payment_type = 'application' OR p_payment_type = 'subscription' OR p_payment_type = 'td' OR p_payment_type = 'short_training'"

if old_condition not in src:
    print(f"   ERROR: Could not find the condition to replace")
    print(f"   Looking for: {old_condition}")
    exit(1)

new_src = src.replace(old_condition, new_condition)
print(f"   Condition found and replaced")

# 4. Deploy
print("2. Deploying updated RPC...")
status, text = ddl(new_src)
print(f"   Status: {status} - {text}")

# 5. Verify
print("3. Verifying...")
result2 = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_confirm_ligdicash_payment' LIMIT 1")
if isinstance(result2, list) and len(result2) > 0:
    new_prosrc = result2[0].get("prosrc", "")
    has_short = "'short_training'" in new_prosrc
    print(f"   Contains 'short_training': {'YES' if has_short else 'NO'}")
else:
    print("   Could not verify")

print("Done.")
