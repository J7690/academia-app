"""
Fix livekit_lookup_session - check actual columns and recreate
"""
import requests

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
            for row in data[:20]:
                print(f"    {row}")
            return data
    else:
        print(f"    ❌ HTTP {r.status_code}: {r.text[:200]}")
    return None

def ddl(query, label=""):
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": query}
    )
    data = r.json() if r.status_code == 200 else r.text[:200]
    ok = r.status_code == 200 and isinstance(data, dict) and data.get('success')
    print(f"    {'✅' if ok else '❌'} {str(data)[:200]}")
    return ok

# Check exact columns of challenge_game_live_sessions
sql("""
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'challenge_game_live_sessions'
ORDER BY ordinal_position
""", "Columns of app.challenge_game_live_sessions")

# The table doesn't have livekit_room_name. Need to add it or remove from RPC.
# Let's check what the RPC challenge_game_start_live returns:
sql("""
SELECT prosrc FROM pg_proc WHERE proname = 'challenge_game_start_live' 
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
""", "challenge_game_start_live source (checking room_name column)")

# The source showed it uses 'livekit_room_name' column in INSERT
# So the column should exist - let me add it if missing
ddl("""
ALTER TABLE app.challenge_game_live_sessions 
ADD COLUMN IF NOT EXISTS livekit_room_name TEXT
""", "Adding livekit_room_name column if missing")

# Now fix and recreate the lookup RPC
ddl("""
CREATE OR REPLACE FUNCTION public.livekit_lookup_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_result JSONB;
BEGIN
  -- Try prep_live_sessions first
  SELECT jsonb_build_object(
    'id', id, 'title', title, 'status', status, 'teacher_id', teacher_id,
    'session_type', 'prep'
  ) INTO v_result
  FROM app.prep_live_sessions WHERE id = p_session_id;
  IF v_result IS NOT NULL THEN RETURN v_result; END IF;

  -- Try online_course_live_sessions
  SELECT jsonb_build_object(
    'id', id, 'title', title, 'status', status, 'instructor_id', host_id,
    'livekit_room_name', livekit_room_name, 'session_type', 'course'
  ) INTO v_result
  FROM app.online_course_live_sessions WHERE id = p_session_id;
  IF v_result IS NOT NULL THEN RETURN v_result; END IF;

  -- Try challenge_game_live_sessions
  SELECT jsonb_build_object(
    'id', id, 'user_id', user_id, 'game_type', game_type, 'mode', mode,
    'status', status, 'livekit_room_name', livekit_room_name,
    'session_type', 'game'
  ) INTO v_result
  FROM app.challenge_game_live_sessions WHERE id = p_session_id;
  IF v_result IS NOT NULL THEN RETURN v_result; END IF;

  RETURN NULL;
END;
$fn$
""", "Recreating livekit_lookup_session with correct columns")

# Verify
print("\n" + "=" * 60)
print("VERIFYING")

r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/livekit_lookup_session",
    headers=HEADERS,
    json={"p_session_id": "00000000-0000-0000-0000-000000000001"}
)
print(f"  livekit_lookup_session (fake ID): HTTP {r.status_code} — {r.text[:200]}")
# Expected: null (not found)

# Test with real session from online_course_live_sessions
sql("SELECT id FROM app.online_course_live_sessions LIMIT 1", "Real session ID")

print("\n🏁 Done.")
