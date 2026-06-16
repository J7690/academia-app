"""
Test full LiveKit chain - use admin_execute_sql for INSERT, and verify all RPCs
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

def admin_sql(query, label=""):
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": query}
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, dict):
            if data.get('ok') == False:
                print(f"    ❌ {data.get('error','')}")
            elif data.get('rows'):
                for row in data['rows'][:5]:
                    print(f"    {row}")
            else:
                print(f"    {str(data)[:300]}")
        else:
            print(f"    {str(data)[:300]}")
        return data
    else:
        print(f"    ❌ HTTP {r.status_code}: {r.text[:200]}")
    return None

def rpc(fn_name, params, label=""):
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/{fn_name}",
        headers=HEADERS,
        json=params
    )
    print(f"    HTTP {r.status_code}: {r.text[:300]}")
    return r.status_code, r.json() if r.status_code == 200 else None

# =========================================================================
# TEST 1: Lookup existing online_course session via RPC
# =========================================================================
print("=" * 60)
print("TEST 1: livekit_lookup_session — online_course session")
print("=" * 60)

status, data = rpc('livekit_lookup_session',
    {"p_session_id": "0a61b265-f232-4232-aeb1-6aae2cf2d9c8"},
    "Lookup known session")

if status == 200 and data:
    print(f"  ✅ session_type={data.get('session_type')}, status={data.get('status')}")
else:
    print("  ❌ Lookup failed")

# =========================================================================
# TEST 2: Create game session via admin_execute_sql + lookup + cleanup
# =========================================================================
print("\n" + "=" * 60)
print("TEST 2: Create game session → lookup → cleanup")
print("=" * 60)

# Use admin_execute_sql for INSERT
result = admin_sql("""
INSERT INTO app.challenge_game_live_sessions 
  (user_id, game_type, mode, status, livekit_room_name)
VALUES 
  ('c63e9c1e-92d9-43f3-ab41-066ec3dc788b', 'test_audit', 'solo', 'live', 'game_test_audit')
RETURNING id::text, status, livekit_room_name
""", "Inserting test game session")

test_sid = None
if isinstance(result, dict) and result.get('rows'):
    test_sid = result['rows'][0].get('id')
elif isinstance(result, dict) and result.get('affected_rows', 0) > 0:
    # Get the last inserted session
    admin_sql("SELECT id::text FROM app.challenge_game_live_sessions WHERE game_type='test_audit' ORDER BY created_at DESC LIMIT 1", "Get test session ID")

# If we got a session, look it up
if test_sid:
    print(f"\n  Test session ID: {test_sid}")
    status2, data2 = rpc('livekit_lookup_session',
        {"p_session_id": test_sid},
        "Lookup test game session")
    if status2 == 200 and data2 and data2.get('session_type') == 'game':
        print(f"  ✅ Game session lookup works! room={data2.get('livekit_room_name')}")
    else:
        print("  ❌ Game session lookup failed")
    
    # Cleanup
    admin_sql(f"DELETE FROM app.challenge_game_live_sessions WHERE game_type='test_audit'", "Cleanup")
else:
    # Fallback: check if there are any game sessions we can test with
    print("\n  Trying without INSERT (looking for existing game sessions)...")
    from_rest = requests.get(
        f"{SUPABASE_URL}/rest/v1/challenge_game_live_sessions?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    print(f"    REST access: HTTP {from_rest.status_code} — {from_rest.text[:100]}")

# =========================================================================
# TEST 3: User display name
# =========================================================================
print("\n" + "=" * 60)
print("TEST 3: livekit_get_user_display_name")
print("=" * 60)

status3, name = rpc('livekit_get_user_display_name',
    {"p_user_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"},
    "Get display name for known user")
if status3 == 200 and name:
    print(f"  ✅ Display name: {name}")

# =========================================================================
# TEST 4: All app schema tables accessible
# =========================================================================
print("\n" + "=" * 60)
print("TEST 4: App schema table access")
print("=" * 60)

for t in ['challenge_game_live_sessions', 'online_course_live_sessions', 'prep_live_sessions',
          'prep_live_participants', 'online_course_live_session_participants']:
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    print(f"  {'✅' if r.status_code == 200 else '❌'} app.{t}: HTTP {r.status_code}")

# =========================================================================
# TEST 5: Edge Function alive
# =========================================================================
print("\n" + "=" * 60)
print("TEST 5: Edge Function livekit-token alive")
print("=" * 60)

r = requests.post(
    f"{SUPABASE_URL}/functions/v1/livekit-token",
    headers={"Content-Type": "application/json"},
    json={"session_id": "test"},
    timeout=10
)
print(f"  {'✅' if r.status_code == 401 else '❌'} HTTP {r.status_code}: {r.text[:200]}")

# =========================================================================
# TEST 6: LiveKit server
# =========================================================================
print("\n" + "=" * 60)
print("TEST 6: LiveKit server 185.167.96.214:7880")
print("=" * 60)

try:
    r = requests.get("http://185.167.96.214:7880", timeout=10)
    print(f"  {'✅' if r.text.strip() == 'OK' else '❌'} HTTP {r.status_code}: {r.text[:50]}")
except Exception as e:
    print(f"  ❌ {e}")

print("\n" + "=" * 60)
print("ALL TESTS COMPLETE")
print("=" * 60)
