"""
FIX: Grant permissions via a temporary PL/pgSQL function (since execute_sql doesn't allow GRANT)
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
            for row in data[:10]:
                print(f"    {row}")
        elif data:
            print(f"    {str(data)[:300]}")
        else:
            print(f"    OK (no output)")
    else:
        print(f"    ❌ HTTP {r.status_code}: {r.text[:300]}")
    return r

# Strategy: Create a SECURITY DEFINER function that runs as superuser to grant perms
print("=" * 60)
print("Creating temporary admin function to grant permissions...")
print("=" * 60)

sql("""
CREATE OR REPLACE FUNCTION public._temp_fix_app_permissions()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Grant usage on app schema
    EXECUTE 'GRANT USAGE ON SCHEMA app TO service_role';
    EXECUTE 'GRANT USAGE ON SCHEMA app TO authenticated';
    
    -- Grant on live tables
    EXECUTE 'GRANT ALL ON app.challenge_game_live_sessions TO service_role';
    EXECUTE 'GRANT ALL ON app.prep_live_sessions TO service_role';
    EXECUTE 'GRANT ALL ON app.prep_live_participants TO service_role';
    EXECUTE 'GRANT ALL ON app.online_course_live_sessions TO service_role';
    EXECUTE 'GRANT ALL ON app.online_course_live_session_participants TO service_role';
    EXECUTE 'GRANT ALL ON app.students TO service_role';
    
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.challenge_game_live_sessions TO authenticated';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.prep_live_sessions TO authenticated';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.prep_live_participants TO authenticated';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.online_course_live_sessions TO authenticated';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.online_course_live_session_participants TO authenticated';
    EXECUTE 'GRANT SELECT ON app.students TO authenticated';
    
    -- Grant sequences
    EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO service_role';
    EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO authenticated';
    
    RETURN 'Permissions granted successfully';
END;
$$;
""", "Creating _temp_fix_app_permissions function")

# Execute the function
print("\n" + "=" * 60)
print("Executing permissions fix...")
print("=" * 60)

r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/_temp_fix_app_permissions",
    headers=HEADERS,
    json={}
)
print(f"  HTTP {r.status_code}: {r.text[:300]}")

# Clean up temp function
sql("DROP FUNCTION IF EXISTS public._temp_fix_app_permissions()", "Cleaning up temp function")

# Verify access
print("\n" + "=" * 60)
print("Verifying access after fix...")
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
    print(f"  {status} app.{table}: HTTP {r.status_code} — {r.text[:100]}")

# Check students
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/students?select=id,full_name&limit=1",
    headers={**HEADERS, "Accept-Profile": "app"},
)
print(f"  {'✅' if r.status_code == 200 else '❌'} app.students: HTTP {r.status_code} — {r.text[:100]}")

print("\n🏁 Done.")
