"""
FIX permissions using execute_ddl(ddl_query) and admin_execute_sql(p_sql)
"""
import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def ddl(query, label=""):
    if label:
        print(f"  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": query}
    )
    data = r.json() if r.status_code == 200 else r.text[:200]
    ok = r.status_code == 200 and (isinstance(data, dict) and data.get('success'))
    print(f"    {'✅' if ok else '❌'} HTTP {r.status_code}: {str(data)[:200]}")
    return ok

# =========================================================================
# GRANT PERMISSIONS
# =========================================================================
print("=" * 60)
print("GRANTING PERMISSIONS ON APP SCHEMA TABLES")
print("=" * 60)

grants = [
    ("GRANT USAGE ON SCHEMA app TO service_role", "Schema usage → service_role"),
    ("GRANT USAGE ON SCHEMA app TO authenticated", "Schema usage → authenticated"),
    ("GRANT ALL ON app.challenge_game_live_sessions TO service_role", "challenge_game_live_sessions → service_role"),
    ("GRANT ALL ON app.prep_live_sessions TO service_role", "prep_live_sessions → service_role"),
    ("GRANT ALL ON app.prep_live_participants TO service_role", "prep_live_participants → service_role"),
    ("GRANT ALL ON app.online_course_live_sessions TO service_role", "online_course_live_sessions → service_role"),
    ("GRANT ALL ON app.online_course_live_session_participants TO service_role", "online_course_live_session_participants → service_role"),
    ("GRANT SELECT, INSERT, UPDATE ON app.challenge_game_live_sessions TO authenticated", "challenge_game_live_sessions → authenticated"),
    ("GRANT SELECT, INSERT, UPDATE ON app.prep_live_sessions TO authenticated", "prep_live_sessions → authenticated"),
    ("GRANT SELECT, INSERT ON app.prep_live_participants TO authenticated", "prep_live_participants → authenticated"),
    ("GRANT SELECT ON app.online_course_live_sessions TO authenticated", "online_course_live_sessions → authenticated"),
    ("GRANT SELECT, INSERT ON app.online_course_live_session_participants TO authenticated", "online_course_live_session_participants → authenticated"),
    ("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO service_role", "All sequences → service_role"),
    ("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO authenticated", "All sequences → authenticated"),
]

for query, label in grants:
    ddl(query, label)

# =========================================================================
# CREATE LOOKUP RPC for Edge Function
# =========================================================================
print("\n" + "=" * 60)
print("CREATING livekit_lookup_session RPC")
print("=" * 60)

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

  -- Not found
  RETURN NULL;
END;
$fn$
""", "Creating livekit_lookup_session")

# Also create a user display name lookup
ddl("""
CREATE OR REPLACE FUNCTION public.livekit_get_user_display_name(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_name TEXT;
BEGIN
  SELECT full_name INTO v_name FROM app.students WHERE id = p_user_id;
  RETURN v_name;
END;
$fn$
""", "Creating livekit_get_user_display_name")

# =========================================================================
# VERIFY
# =========================================================================
print("\n" + "=" * 60)
print("VERIFYING ACCESS")
print("=" * 60)

live_tables = [
    'challenge_game_live_sessions',
    'online_course_live_sessions',
    'online_course_live_session_participants',
    'prep_live_sessions',
    'prep_live_participants',
]

for table in live_tables:
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    status = "✅" if r.status_code == 200 else "❌"
    print(f"  {status} app.{table}: HTTP {r.status_code}")

# Test the new RPCs
print("\n  Testing livekit_lookup_session...")
r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/livekit_lookup_session",
    headers=HEADERS,
    json={"p_session_id": "00000000-0000-0000-0000-000000000001"}
)
print(f"  livekit_lookup_session: HTTP {r.status_code} — {r.text[:200]}")

r2 = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/livekit_get_user_display_name",
    headers=HEADERS,
    json={"p_user_id": "00000000-0000-0000-0000-000000000001"}
)
print(f"  livekit_get_user_display_name: HTTP {r2.status_code} — {r2.text[:200]}")

print("\n🏁 Done.")
