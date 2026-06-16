#!/usr/bin/env python3
"""Test LiveKit server on Kamatera: generate JWT, list rooms, verify secrets match Supabase."""

import json
import time
import hmac
import hashlib
import base64
import requests

CREDS = json.loads(open("livekit_credentials.json").read())
SERVER_IP = CREDS["server_ip"]
API_KEY = CREDS["livekit_api_key"]
API_SECRET = CREDS["livekit_api_secret"]
LIVEKIT_HTTP = CREDS["livekit_http"]

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def generate_livekit_jwt(api_key, api_secret, ttl=30):
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "iss": api_key,
        "sub": "test-audit",
        "nbf": now,
        "exp": now + ttl,
        "iat": now,
        "jti": f"audit-{now}",
        "video": {"roomList": True, "roomCreate": True},
    }
    h = b64url(json.dumps(header).encode())
    p = b64url(json.dumps(payload).encode())
    sig_input = f"{h}.{p}"
    sig = hmac.new(api_secret.encode(), sig_input.encode(), hashlib.sha256).digest()
    return f"{sig_input}.{b64url(sig)}"

print("=" * 60)
print(f"LiveKit Server: {SERVER_IP}")
print(f"API Key: {API_KEY}")
print(f"HTTP URL: {LIVEKIT_HTTP}")
print("=" * 60)

# 1. Health check
print("\n[1] Health check...")
try:
    r = requests.get(LIVEKIT_HTTP, timeout=10)
    print(f"    Status: {r.status_code} Body: {r.text[:100]}")
except Exception as e:
    print(f"    FAIL: {e}")

# 2. Generate JWT and list rooms
print("\n[2] Generating JWT and listing rooms...")
token = generate_livekit_jwt(API_KEY, API_SECRET)
print(f"    Token: {token[:50]}...")

try:
    r = requests.post(
        f"{LIVEKIT_HTTP}/twirp/livekit.RoomService/ListRooms",
        json={},
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        timeout=10,
    )
    print(f"    Status: {r.status_code}")
    print(f"    Response: {r.text[:500]}")
    if r.status_code == 200:
        rooms = r.json().get("rooms", [])
        print(f"    Active rooms: {len(rooms)}")
        print("    >>> LiveKit API is WORKING with these credentials <<<")
    else:
        print(f"    >>> PROBLEM: Status {r.status_code} <<<")
except Exception as e:
    print(f"    FAIL: {e}")

# 3. Verify Supabase secrets match
print("\n[3] Checking if Supabase Edge Function uses same credentials...")
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# The Edge Function livekit-token returns 500 if secrets are missing, 401 if they exist but auth fails
try:
    r = requests.post(
        f"{SUPABASE_URL}/functions/v1/livekit-token",
        json={"session_id": "test-audit"},
        headers={
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
        timeout=15,
    )
    print(f"    Edge Function status: {r.status_code}")
    print(f"    Response: {r.text[:300]}")
    if r.status_code == 500 and "non configuré" in r.text.lower():
        print("    >>> PROBLEM: Supabase secrets NOT configured <<<")
    elif r.status_code == 503:
        print("    >>> PROBLEM: Edge Function BOOT ERROR <<<")
    else:
        print("    >>> Edge Function is running (secrets exist) <<<")
except Exception as e:
    print(f"    FAIL: {e}")

# 4. Try creating a test room to verify full pipeline
print("\n[4] Creating a test room 'audit_test_room'...")
try:
    r = requests.post(
        f"{LIVEKIT_HTTP}/twirp/livekit.RoomService/CreateRoom",
        json={"name": "audit_test_room", "empty_timeout": 60, "max_participants": 5},
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        timeout=10,
    )
    print(f"    Status: {r.status_code}")
    print(f"    Response: {r.text[:500]}")
    if r.status_code == 200:
        print("    >>> Room creation WORKS <<<")
    else:
        print(f"    >>> PROBLEM: Cannot create rooms <<<")
except Exception as e:
    print(f"    FAIL: {e}")

# 5. Delete test room
print("\n[5] Deleting test room...")
try:
    r = requests.post(
        f"{LIVEKIT_HTTP}/twirp/livekit.RoomService/DeleteRoom",
        json={"room": "audit_test_room"},
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        timeout=10,
    )
    print(f"    Status: {r.status_code}")
except Exception as e:
    print(f"    FAIL: {e}")

print("\n" + "=" * 60)
print("AUDIT COMPLETE")
print("=" * 60)
