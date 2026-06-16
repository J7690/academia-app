#!/usr/bin/env python3
"""Test direct de ligdicash-confirm pour diagnostiquer l'erreur OTP."""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.BQ4Rh0Kk5T9VLwMNBR_FnSl9Q7oZiUoCD4EnFjP7cZ8"

# Check recent payments in processing state (the one that was initiated)
print("=== Recent payments in 'processing' status ===")
r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
    headers={"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"},
    json={"sql_query": "SELECT id, amount_due, status, payment_method, phone_number, channel, ligdicash_token, created_at FROM app.application_payments WHERE status = 'processing' OR (channel = 'ligdicash' AND created_at > NOW() - INTERVAL '7 days') ORDER BY created_at DESC LIMIT 5"},
    timeout=15)
if r.status_code == 200:
    for p in r.json():
        print(f"  ID: {p.get('id')}")
        print(f"    Amount: {p.get('amount_due')} XOF")
        print(f"    Status: {p.get('status')}")
        print(f"    Method: {p.get('payment_method')}")
        print(f"    Phone: {p.get('phone_number')}")
        print(f"    Channel: {p.get('channel')}")
        print(f"    LigdiCash token: {p.get('ligdicash_token')}")
        print(f"    Created: {p.get('created_at')}")
        print()
else:
    print(f"  Error: {r.status_code} {r.text[:200]}")

# Check Edge Function logs by calling confirm with a fake OTP to see the error pattern
print("\n=== Testing ligdicash-confirm Edge Function directly ===")
print("(Using service_role to bypass auth, with a fake payment to see error response)")
r2 = requests.post(
    f"{SUPABASE_URL}/functions/v1/ligdicash-confirm",
    headers={
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "apikey": ANON_KEY,
        "Content-Type": "application/json",
    },
    json={
        "payment_type": "application",
        "payment_id": "00000000-0000-0000-0000-000000000000",
        "otp_code": "123456",
        "phone_number": "22666660538",
    },
    timeout=30,
)
print(f"  HTTP Status: {r2.status_code}")
print(f"  Response: {r2.text[:500]}")

# Check if the issue is that functions.invoke throws on non-2xx
print("\n=== Key insight ===")
print("The Flutter LigdiCashService uses _client.functions.invoke()")
print("This method throws a FunctionException if status != 2xx")
print("The catch block returns generic 'network_error' hiding the real error")
print("")
print("If ligdicash-confirm returns HTTP 502 (LigdiCash API error),")
print("or HTTP 500 (RPC error), Flutter shows 'Erreur réseau'")
print("instead of the actual LigdiCash error message.")
