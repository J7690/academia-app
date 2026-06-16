#!/usr/bin/env python3
"""Fix: ajouter credit_purchase a l'enum payment_reason (trouver le bon schema)."""

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

# Find the exact schema of the enum
print("=== Find enum schema ===")
r = sql("SELECT n.nspname as schema, t.typname FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'payment_reason'")
if isinstance(r, list):
    for row in r:
        schema = row.get('schema')
        name = row.get('typname')
        print(f"  Found: {schema}.{name}")
        
        # Try ALTER TYPE with correct schema
        print(f"\n=== Adding credit_purchase to {schema}.{name} ===")
        s, t = ddl(f"ALTER TYPE {schema}.payment_reason ADD VALUE IF NOT EXISTS 'credit_purchase'")
        print(f"  Result: {s} - {t}")

# Verify
print("\n=== Verify ===")
r2 = sql("SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_enum.enumtypid = pg_type.oid WHERE pg_type.typname = 'payment_reason' ORDER BY enumsortorder")
if isinstance(r2, list):
    vals = [x.get('enumlabel') for x in r2]
    print(f"  Enum values: {vals}")
    print(f"  Has credit_purchase: {'credit_purchase' in vals}")

print("\nDone.")
