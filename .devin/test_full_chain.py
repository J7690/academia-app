"""
Test the full LiveKit chain end-to-end:
1. Create a game live session via RPC
2. Look up the session via livekit_lookup_session RPC
3. Verify the Edge Function can find it
4. Clean up
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def sql(query, label=""):
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query}
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:5]:
                print(f"    {row}")
            return data
        else:
            print(f"    {str(data)[:300]}")
            return data
    else:
        print(f"    ❌ HTTP {r.status_code}: {r.text[:200]}")
    return None

# =========================================================================
# TEST 1: Verify livekit_lookup_session with existing online_course session
# =========================================================================
print("=" * 60)
print("TEST 1: Lookup existing online_course session")
print("=" * 60)

sessions = sql("SELECT id, title, status FROM app.online_course_live_sessions LIMIT 1")
if sessions and len(sessions) > 0:
    sid = sessions[0]['id']
    print(f"\n  Testing lookup for session {sid}...")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/livekit_lookup_session",
        headers=HEADERS,
        json={"p_session_id": sid}
    )
    print(f"  HTTP {r.status_code}: {r.text[:300]}")
    if r.status_code == 200 and r.json():
        print("  ✅ livekit_lookup_session works for online_course sessions!")

# =========================================================================
# TEST 2: Create a test game live session and verify lookup
# =========================================================================
print("\n" + "=" * 60)
print("TEST 2: Create test game session + lookup")
print("=" * 60)

# Insert a test session directly
test_result = sql("""
INSERT INTO app.challenge_game_live_sessions (user_id, game_type, mode, status, livekit_room_name)
VALUES ('c63e9c1e-92d9-43f3-ab41-066ec3dc788b', 'challenge_live_test', 'solo', 'live', 'game_test_room')
RETURNING id, status, livekit_room_name
""", "Inserting test game session")

if test_result and len(test_result) > 0:
    test_sid = test_result[0]['id']
    print(f"\n  Test session created: {test_sid}")
    
    # Look it up
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/livekit_lookup_session",
        headers=HEADERS,
        json={"p_session_id": test_sid}
    )
    print(f"  Lookup: HTTP {r.status_code}: {r.text[:300]}")
    lookup_data = r.json() if r.status_code == 200 else None
    
    if lookup_data and lookup_data.get('session_type') == 'game':
        print("  ✅ Game session lookup works!")
        print(f"    session_type: {lookup_data.get('session_type')}")
        print(f"    status: {lookup_data.get('status')}")
        print(f"    livekit_room_name: {lookup_data.get('livekit_room_name')}")
    else:
        print("  ❌ Game session lookup failed!")
    
    # Clean up test session
    sql(f"DELETE FROM app.challenge_game_live_sessions WHERE id = '{test_sid}'", "Cleaning up test session")

# =========================================================================
# TEST 3: Verify livekit_get_user_display_name
# =========================================================================
print("\n" + "=" * 60)
print("TEST 3: User display name lookup")
print("=" * 60)

r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/livekit_get_user_display_name",
    headers=HEADERS,
    json={"p_user_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"}
)
print(f"  HTTP {r.status_code}: {r.text[:200]}")
if r.status_code == 200 and r.json():
    print(f"  ✅ Display name: {r.json()}")

# =========================================================================
# TEST 4: Verify app schema tables are now accessible
# =========================================================================
print("\n" + "=" * 60)
print("TEST 4: Direct table access verification")
print("=" * 60)

tables = [
    'challenge_game_live_sessions',
    'online_course_live_sessions',
    'prep_live_sessions',
    'prep_live_participants',
    'online_course_live_session_participants',
]
for t in tables:
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    print(f"  {'✅' if r.status_code == 200 else '❌'} app.{t}: HTTP {r.status_code}")

# =========================================================================
# TEST 5: Verify Edge Function responds (without real user JWT)
# =========================================================================
print("\n" + "=" * 60)
print("TEST 5: Edge Function livekit-token health check")
print("=" * 60)

r = requests.post(
    f"{SUPABASE_URL}/functions/v1/livekit-token",
    headers={"Content-Type": "application/json"},
    json={"session_id": "test"},
    timeout=10
)
print(f"  No auth: HTTP {r.status_code} — {r.text[:200]}")
if r.status_code == 401:
    print("  ✅ Edge Function alive (requires auth)")

# =========================================================================
# TEST 6: LiveKit server connectivity
# =========================================================================
print("\n" + "=" * 60)
print("TEST 6: LiveKit server")
print("=" * 60)

try:
    r = requests.get("http://185.167.96.214:7880", timeout=10)
    print(f"  {'✅' if r.text.strip() == 'OK' else '❌'} HTTP {r.status_code}: {r.text[:50]}")
except Exception as e:
    print(f"  ❌ {e}")

print("\n" + "=" * 60)
print("ALL TESTS COMPLETE")
print("=" * 60)
