#!/usr/bin/env python3
"""
Test the full OTP flow: Supabase Auth -> Hook -> pg_net -> Edge Function -> Twilio SMS
"""
import requests, json, time

SUPA = "https://thevdfcwlcqzdoybfvgs.supabase.co"
ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0"
    ".8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
)
SK = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
SK_HEADERS = {
    "apikey": SK,
    "Authorization": f"Bearer {SK}",
    "Content-Type": "application/json",
}

TEST_PHONE = "+22666660538"

def sql(query):
    r = requests.post(
        f"{SUPA}/rest/v1/rpc/execute_sql",
        headers=SK_HEADERS,
        json={"sql_query": query},
        timeout=30,
    )
    return r.json()

# Step 1: Send OTP via Supabase Auth
print("=== [1] Envoi OTP via Supabase Auth ===")
r = requests.post(
    f"{SUPA}/auth/v1/otp",
    headers={"apikey": ANON, "Content-Type": "application/json"},
    json={"phone": TEST_PHONE},
    timeout=30,
)
print(f"  Status: {r.status_code}")
print(f"  Body: {r.text[:200]}")

# Step 2: Wait for hook + pg_net to process
print("\n  Attente 5s pour que le hook et pg_net traitent...")
time.sleep(5)

# Step 3: Check debug log
print("\n=== [2] Debug log (hook declenche?) ===")
data = sql(
    "SELECT id, phone_extracted, otp_extracted, created_at "
    "FROM public.sms_hook_debug_log ORDER BY created_at DESC LIMIT 2"
)
if isinstance(data, list):
    for row in data:
        print(f"  id={row['id']} phone={row['phone_extracted']} otp={row['otp_extracted']} at={row['created_at']}")
else:
    print(f"  {data}")

# Step 4: Check pg_net response
print("\n=== [3] pg_net reponse (Edge Function appelee?) ===")
data = sql(
    "SELECT id, status_code, LEFT(content::text, 300) AS content "
    "FROM net._http_response ORDER BY created DESC LIMIT 3"
)
if isinstance(data, list):
    for row in data:
        print(f"  id={row['id']} status={row['status_code']}")
        print(f"  content={row.get('content','')[:200]}")
        print()
else:
    print(f"  {data}")

print("=== FIN ===")
print("Verifiez votre telephone pour le SMS!")
