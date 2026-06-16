#!/usr/bin/env python3
"""
Test complet du flux Phone OTP:
1. Envoyer OTP via Supabase Auth (/auth/v1/otp)
2. Verifier que le hook send_sms_hook se declenche
3. Tester la verification OTP avec le code test
"""

import requests
import json
import time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)

# Numero de test enregistre dans Supabase (22670000001=000000)
TEST_PHONE = "+22670000001"
TEST_OTP   = "000000"

# Numero REEL a tester (commenter si pas disponible)
REAL_PHONE = "+22670000000"  # Remplacer par un vrai numero pour test SMS reel

print("=" * 60)
print("TEST FLUX PHONE OTP - ACADEMIA")
print("=" * 60)

# ──────────────────────────────────────────────────────
# TEST 1: Envoi OTP avec numero de test (bypass SMS)
# ──────────────────────────────────────────────────────
print("\n[TEST 1] Envoi OTP numero de test (bypass SMS hook)...")
r1 = requests.post(
    f"{SUPABASE_URL}/auth/v1/otp",
    headers={
        "apikey": ANON_KEY,
        "Content-Type": "application/json",
    },
    json={"phone": TEST_PHONE},
    timeout=20,
)
print(f"  HTTP {r1.status_code}")
try:
    print(f"  Body: {json.dumps(r1.json(), indent=2)}")
except Exception:
    print(f"  Body: {r1.text[:300]}")

# ──────────────────────────────────────────────────────
# TEST 2: Verification OTP avec code test
# ──────────────────────────────────────────────────────
if r1.status_code == 200:
    print(f"\n[TEST 2] Verification OTP code={TEST_OTP}...")
    r2 = requests.post(
        f"{SUPABASE_URL}/auth/v1/verify",
        headers={
            "apikey": ANON_KEY,
            "Content-Type": "application/json",
        },
        json={
            "phone": TEST_PHONE,
            "token": TEST_OTP,
            "type": "sms",
        },
        timeout=20,
    )
    print(f"  HTTP {r2.status_code}")
    try:
        body2 = r2.json()
        print(f"  Body: {json.dumps(body2, indent=2)[:600]}")
        if r2.status_code == 200 and body2.get("access_token"):
            print("\n  [OK] Session creee - access_token recu!")
            print(f"  user_id: {body2.get('user', {}).get('id', 'N/A')}")
            print(f"  phone: {body2.get('user', {}).get('phone', 'N/A')}")
    except Exception:
        print(f"  Body: {r2.text[:300]}")
else:
    print("\n  [SKIP] Test 2 saute (envoi OTP echoue)")

# ──────────────────────────────────────────────────────
# TEST 3: Verifier le hook pg_net - voir les requetes recentes
# ──────────────────────────────────────────────────────
print("\n[TEST 3] Verification des requetes pg_net recentes...")
svc_headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}
r3 = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
    headers=svc_headers,
    json={"sql_query": """
        SELECT id, url, status_code, timed_out,
               created
        FROM net._http_response
        WHERE url LIKE '%send-phone-otp%'
        ORDER BY created DESC
        LIMIT 5
    """},
    timeout=20,
)
print(f"  HTTP {r3.status_code}")
try:
    print(f"  Requetes hook: {json.dumps(r3.json(), indent=2)[:800]}")
except Exception:
    print(f"  Body: {r3.text[:300]}")

# ──────────────────────────────────────────────────────
# TEST 4: Envoi OTP numero REEL (declenche vrai SMS)
# ──────────────────────────────────────────────────────
print("\n[TEST 4] Envoi OTP numero REEL (declenche le hook Twilio)...")
print(f"  Cible: {REAL_PHONE}")
r4 = requests.post(
    f"{SUPABASE_URL}/auth/v1/otp",
    headers={
        "apikey": ANON_KEY,
        "Content-Type": "application/json",
    },
    json={"phone": REAL_PHONE},
    timeout=20,
)
print(f"  HTTP {r4.status_code}")
try:
    print(f"  Body: {json.dumps(r4.json(), indent=2)}")
except Exception:
    print(f"  Body: {r4.text[:300]}")

print("\n" + "=" * 60)
print("RESUME:")
print(f"  Phone Provider active : YES (configure dashboard)")
print(f"  Send SMS Hook         : send_sms_hook (Postgres -> pg_net -> Edge Function)")
print(f"  Edge Function         : send-phone-otp -> Twilio Verify")
print(f"  Test numero bypass    : {TEST_PHONE} / OTP={TEST_OTP}")
print("=" * 60)
print("\nPour tester sur TECNO:")
print("  1. Ouvrir l'app Academia")
print("  2. 'Se connecter par telephone'")
print("  3. Saisir le numero (7X XX XX XX)")
print("  4. Recevoir le SMS OTP")
print("  5. Entrer le code -> session creee -> StudentDashboard")
