#!/usr/bin/env python3
"""Test la RPC app_student_create_profile_payment avec payment_reason='credit_purchase'."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:300]}

# 1. Check if RPC exists and what it expects
print("=== RPC app_student_create_profile_payment ===")
r = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_student_create_profile_payment' LIMIT 1")
if isinstance(r, list) and len(r) > 0:
    src = r[0].get('prosrc', '')
    print(f"  Exists: YES ({len(src)} chars)")
    # Check what payment_reasons it accepts
    if 'credit_purchase' in src:
        print(f"  Handles 'credit_purchase': YES")
    else:
        print(f"  Handles 'credit_purchase': NO")
    # Check the enum constraint
    if 'payment_reason' in src:
        print(f"  Has payment_reason check: YES")
    # Print first 600 chars to see the logic
    print(f"\n  Source (first 600):\n{src[:600]}")
else:
    print(f"  NOT FOUND: {r}")

# 2. Check payment_reason enum values
print("\n=== payment_reason enum values ===")
r2 = sql("SELECT enum_range(NULL::app.payment_reason)")
if isinstance(r2, list) and len(r2) > 0:
    print(f"  {r2[0]}")
else:
    # Try another way
    r3 = sql("SELECT DISTINCT payment_reason FROM app.application_payments ORDER BY payment_reason")
    if isinstance(r3, list):
        for v in r3:
            print(f"  - {v.get('payment_reason')}")
    else:
        print(f"  Error: {r3}")

# 3. Check if 'credit_purchase' is a valid enum value
print("\n=== Check if 'credit_purchase' is valid ===")
r4 = sql("SELECT 'credit_purchase'::app.payment_reason AS test")
if isinstance(r4, list):
    print(f"  Valid: YES")
else:
    print(f"  Valid: NO - {r4}")

print("\nDone.")
