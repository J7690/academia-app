#!/usr/bin/env python3
"""Fix: ajouter 'credit_purchase' a l'enum payment_reason ou contourner le probleme."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def ddl(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl", headers=HEADERS, json={"ddl_query": q}, timeout=15)
    return r.status_code, r.text[:300]

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:300]}

# 1. Check column type
print("=== Step 1: Check payment_reason column type ===")
r = sql("SELECT data_type, udt_name FROM information_schema.columns WHERE table_schema='app' AND table_name='application_payments' AND column_name='payment_reason'")
if isinstance(r, list) and len(r) > 0:
    dtype = r[0].get('data_type', '')
    udt = r[0].get('udt_name', '')
    print(f"  data_type={dtype}, udt_name={udt}")
else:
    print(f"  {r}")

# 2. Check if enum exists
print("\n=== Step 2: Check enum type ===")
r2 = sql("SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_enum.enumtypid = pg_type.oid WHERE pg_type.typname = 'payment_reason' ORDER BY enumsortorder")
if isinstance(r2, list) and len(r2) > 0:
    vals = [x.get('enumlabel') for x in r2]
    print(f"  Current enum values: {vals}")
    has_credit = 'credit_purchase' in vals
    print(f"  Has credit_purchase: {has_credit}")
    
    if not has_credit:
        print("\n=== Step 3: Adding credit_purchase to enum ===")
        s, t = ddl("ALTER TYPE app.payment_reason ADD VALUE IF NOT EXISTS 'credit_purchase'")
        print(f"  Result: {s} - {t}")
        
        # Verify
        r3 = sql("SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_enum.enumtypid = pg_type.oid WHERE pg_type.typname = 'payment_reason' ORDER BY enumsortorder")
        if isinstance(r3, list):
            vals3 = [x.get('enumlabel') for x in r3]
            print(f"  Updated enum values: {vals3}")
else:
    print(f"  Enum not found or error: {r2}")
    print("  Checking CHECK constraints...")
    r4 = sql("SELECT conname, pg_get_constraintdef(oid) as def FROM pg_constraint WHERE conrelid = 'app.application_payments'::regclass AND pg_get_constraintdef(oid) LIKE '%%payment_reason%%'")
    if isinstance(r4, list):
        for c in r4:
            print(f"  Constraint: {c.get('conname')} = {c.get('def')}")
        if not r4:
            print("  No constraint - column is plain TEXT, credit_purchase should work directly")

print("\nDone.")
