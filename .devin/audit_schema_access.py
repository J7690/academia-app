"""
AUDIT: Verify Edge Function schema access
The livekit-token Edge Function uses supabase.from('table') (default public schema)
but the actual tables are in 'app' schema. Check if PostgREST search_path includes 'app'.
Also audit concordance Flutter ↔ Supabase for all live-related calls.
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
        print(f"\n{'='*60}")
        print(f"  {label}")
        print(f"{'='*60}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query}
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:20]:
                print(f"  {row}")
            return data
        else:
            print(f"  {str(data)[:500]}")
            return data
    else:
        print(f"  ❌ HTTP {r.status_code}: {r.text[:300]}")
        return None

# =========================================================================
# TEST 1: Check PostgREST search_path (what schemas are accessible via REST)
# =========================================================================
sql("SHOW search_path", "PostgREST search_path")

# =========================================================================
# TEST 2: Check if PostgREST can access 'app' schema tables directly
# =========================================================================
print("\n" + "="*60)
print("  TEST 2: Try accessing app schema tables via REST API")
print("="*60)

# Try accessing challenge_game_live_sessions via REST (without schema prefix)
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/challenge_game_live_sessions?select=id,status&limit=1",
    headers=HEADERS,
)
print(f"  REST /challenge_game_live_sessions (no schema): HTTP {r.status_code} — {r.text[:200]}")

# Try with schema header
r2 = requests.get(
    f"{SUPABASE_URL}/rest/v1/challenge_game_live_sessions?select=id,status&limit=1",
    headers={**HEADERS, "Accept-Profile": "app"},
)
print(f"  REST /challenge_game_live_sessions (schema=app): HTTP {r2.status_code} — {r2.text[:200]}")

# Try prep_live_sessions
r3 = requests.get(
    f"{SUPABASE_URL}/rest/v1/prep_live_sessions?select=id,status&limit=1",
    headers=HEADERS,
)
print(f"  REST /prep_live_sessions (no schema): HTTP {r3.status_code} — {r3.text[:200]}")

r4 = requests.get(
    f"{SUPABASE_URL}/rest/v1/prep_live_sessions?select=id,status&limit=1",
    headers={**HEADERS, "Accept-Profile": "app"},
)
print(f"  REST /prep_live_sessions (schema=app): HTTP {r4.status_code} — {r4.text[:200]}")

# Try online_course_live_sessions
r5 = requests.get(
    f"{SUPABASE_URL}/rest/v1/online_course_live_sessions?select=id,status&limit=1",
    headers=HEADERS,
)
print(f"  REST /online_course_live_sessions (no schema): HTTP {r5.status_code} — {r5.text[:200]}")

r6 = requests.get(
    f"{SUPABASE_URL}/rest/v1/online_course_live_sessions?select=id,status&limit=1",
    headers={**HEADERS, "Accept-Profile": "app"},
)
print(f"  REST /online_course_live_sessions (schema=app): HTTP {r6.status_code} — {r6.text[:200]}")

# =========================================================================
# TEST 3: Check the exposed schemas in PostgREST config
# =========================================================================
sql("""
SELECT name, setting FROM pg_settings WHERE name LIKE '%pgrst%' OR name LIKE '%search%'
""", "PostgREST/search settings")

# Also check the db_schemas via PostgREST
sql("""
SELECT current_schemas(true) as schemas
""", "Current schemas in session")

# =========================================================================
# TEST 4: Check if there are VIEWS in public schema that mirror app tables
# =========================================================================
sql("""
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_name IN (
    'challenge_game_live_sessions',
    'online_course_live_sessions', 
    'prep_live_sessions',
    'online_course_live_session_participants',
    'prep_live_participants'
)
ORDER BY table_schema, table_name
""", "Tables/views in all schemas for live tables")

# =========================================================================
# TEST 5: Check which RPCs Flutter calls and verify they exist
# =========================================================================
print("\n" + "#"*60)
print("# CONCORDANCE FLUTTER → SUPABASE")
print("#"*60)

flutter_rpc_calls = [
    # From GameLiveService
    ("challenge_game_start_live", "GameLiveService.startLive()"),
    ("challenge_game_end_live", "GameLiveService.endLive()"),
    ("challenge_game_list_live", "GameLiveService.getLiveSessions()"),
    # From livekit-token Edge Function
    ("app_prep_student_join_live_session", "livekit-token Edge Function"),
    ("app_register_online_course_live_session_participant", "livekit-token Edge Function"),
    # From student live sessions tab
    ("app_student_list_online_course_live_sessions", "StudentLiveSessionsTab"),
    ("app_student_list_my_online_course_live_sessions", "StudentLiveSessionsTab"),
    # From prep lives tab
    ("app_prep_student_list_live_sessions", "PrepLivesTab"),
    ("app_prep_student_join_live_session", "PrepLivesTab"),
]

for rpc_name, caller in flutter_rpc_calls:
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": f"SELECT routine_schema, routine_name FROM information_schema.routines WHERE routine_name = '{rpc_name}'"}
    )
    if r.status_code == 200:
        data = r.json()
        if data:
            schemas = [d.get('routine_schema', '?') for d in data]
            print(f"  ✅ {rpc_name} → exists in [{', '.join(schemas)}] (called by {caller})")
        else:
            print(f"  ❌ {rpc_name} → MISSING! (called by {caller})")
    else:
        print(f"  ❌ {rpc_name} → Error checking")

# =========================================================================
# TEST 6: Check Edge Functions list (all deployed)
# =========================================================================
print("\n" + "#"*60)
print("# EDGE FUNCTIONS DEPLOYED")
print("#"*60)

edge_fns = ['livekit-token', 'livekit-recording', 'assemble-video-chunks', 
            'merge-video-segments', 'transcode-video', 'transcode-multi-resolution']
for fn in edge_fns:
    try:
        r = requests.options(f"{SUPABASE_URL}/functions/v1/{fn}", timeout=5)
        print(f"  {'✅' if r.status_code == 200 else '❌'} {fn}: HTTP {r.status_code}")
    except:
        print(f"  ❌ {fn}: unreachable")

# =========================================================================
# TEST 7: Verify livekit-token can access challenge_game_live_sessions
# =========================================================================
print("\n" + "#"*60)
print("# CRITICAL: Edge Function schema access for challenge_game_live_sessions")
print("#"*60)

# The Edge Function uses supabase.schema('app').from('challenge_game_live_sessions')
# Let's verify this works by checking the API directly
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/challenge_game_live_sessions?select=id,status,user_id&limit=3",
    headers={**HEADERS, "Accept-Profile": "app"},
)
print(f"  schema('app').from('challenge_game_live_sessions'): HTTP {r.status_code} — {r.text[:200]}")

# The Edge Function also uses supabase.from('prep_live_sessions') WITHOUT .schema('app')
# This might fail if the search_path doesn't include 'app'
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/prep_live_sessions?select=id,status&limit=1",
    headers=HEADERS,  # NO Accept-Profile header = public schema
)
print(f"  from('prep_live_sessions') [default schema]: HTTP {r.status_code} — {r.text[:200]}")

# Same for online_course_live_sessions
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/online_course_live_sessions?select=id,status&limit=1",
    headers=HEADERS,
)
print(f"  from('online_course_live_sessions') [default schema]: HTTP {r.status_code} — {r.text[:200]}")

print("\n🏁 Audit terminé.")
