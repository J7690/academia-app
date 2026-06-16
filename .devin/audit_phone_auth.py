#!/usr/bin/env python3
"""Audit: triggers profil, handle_new_user, secrets Twilio existants."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.text[:300]}

print("=== 1. Triggers sur auth.users ===")
r = sql("""SELECT trigger_name, event_manipulation, action_timing, action_statement
    FROM information_schema.triggers
    WHERE event_object_schema = 'auth' AND event_object_table = 'users'
    ORDER BY trigger_name""")
if isinstance(r, list):
    for t in r:
        print(f"  {t.get('trigger_name')} | {t.get('event_manipulation')} {t.get('action_timing')}")
        print(f"    => {t.get('action_statement')[:100]}")
else:
    print(f"  {r}")

print("\n=== 2. Fonction handle_new_user / handle_phone_user ===")
r2 = sql("""SELECT proname, prosrc FROM pg_proc
    WHERE proname IN ('handle_new_user', 'handle_phone_signup', 'create_profile_for_user',
                      'on_auth_user_created', 'create_student_profile')
    LIMIT 5""")
if isinstance(r2, list):
    for fn in r2:
        print(f"  {fn.get('proname')}:\n{fn.get('prosrc', '')[:300]}\n")
else:
    print(f"  {r2}")

print("\n=== 3. Table profiles / students structure ===")
r3 = sql("""SELECT column_name, data_type, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name IN ('students', 'profiles')
    ORDER BY table_name, ordinal_position""")
if isinstance(r3, list):
    cur = None
    for c in r3:
        if c.get('table_name') != cur:
            cur = c.get('table_name')
            print(f"\n  app.{cur}:")
        print(f"    {c.get('column_name')} ({c.get('data_type')})")
else:
    print(f"  {r3}")

print("\n=== 4. Edge functions deployees (send-phone-otp existe?) ===")
import os
fn_dir = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions"
fns = os.listdir(fn_dir) if os.path.exists(fn_dir) else []
has_phone_otp = 'send-phone-otp' in fns
print(f"  send-phone-otp exists: {has_phone_otp}")
print(f"  Total functions: {len(fns)}")

print("\n=== 5. Config auth Supabase (phone provider) ===")
r5 = requests.get(f"{SUPABASE_URL}/auth/v1/settings", headers=HEADERS, timeout=10)
if r5.status_code == 200:
    settings = r5.json()
    print(f"  phone_enabled: {settings.get('phone_enabled', 'N/A')}")
    print(f"  phone_autoconfirm: {settings.get('phone_autoconfirm', 'N/A')}")
    print(f"  sms_provider: {settings.get('sms_provider', 'N/A')}")
    print(f"  mailer_autoconfirm: {settings.get('mailer_autoconfirm', 'N/A')}")
    print(f"  disable_signup: {settings.get('disable_signup', 'N/A')}")
else:
    print(f"  HTTP {r5.status_code}: {r5.text[:200]}")

print("\nDone.")
