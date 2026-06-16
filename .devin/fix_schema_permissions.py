"""
FIX: Grant service_role access to app schema tables for Edge Functions
and fix PostgREST exposed schemas to include 'app'
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
        else:
            print(f"    {str(data)[:300]}")
    else:
        print(f"    ❌ HTTP {r.status_code}: {r.text[:300]}")
    return r

# Step 1: Grant USAGE on app schema to service_role and authenticated
print("=" * 60)
print("FIXING PERMISSIONS ON APP SCHEMA")
print("=" * 60)

sql("GRANT USAGE ON SCHEMA app TO service_role", "Grant USAGE on app schema to service_role")
sql("GRANT USAGE ON SCHEMA app TO authenticated", "Grant USAGE on app schema to authenticated")
sql("GRANT USAGE ON SCHEMA app TO anon", "Grant USAGE on app schema to anon")

# Step 2: Grant SELECT on all live-related tables in app schema
live_tables = [
    'challenge_game_live_sessions',
    'online_course_live_sessions',
    'online_course_live_session_participants',
    'prep_live_sessions',
    'prep_live_participants',
]

for table in live_tables:
    sql(f"GRANT ALL ON app.{table} TO service_role", f"Grant ALL on app.{table} to service_role")
    sql(f"GRANT SELECT, INSERT, UPDATE ON app.{table} TO authenticated", f"Grant SELECT/INSERT/UPDATE on app.{table} to authenticated")

# Step 3: Grant execute on sequences (for inserts)
sql("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO service_role", "Grant sequences to service_role")
sql("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO authenticated", "Grant sequences to authenticated")

# Step 4: Verify access
print("\n" + "=" * 60)
print("VERIFYING ACCESS")
print("=" * 60)

for table in live_tables:
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    status = "✅" if r.status_code == 200 else "❌"
    print(f"  {status} app.{table}: HTTP {r.status_code} — {r.text[:100]}")

# Step 5: Also check if 'students' table is accessible (Edge Function needs it)
print("\n  Checking students table access...")
sql("""
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_name = 'students'
""", "Where is 'students' table?")

r = requests.get(
    f"{SUPABASE_URL}/rest/v1/students?select=id,full_name&limit=1",
    headers=HEADERS,
)
print(f"  students (public): HTTP {r.status_code} — {r.text[:100]}")

r = requests.get(
    f"{SUPABASE_URL}/rest/v1/students?select=id,full_name&limit=1",
    headers={**HEADERS, "Accept-Profile": "app"},
)
print(f"  students (app): HTTP {r.status_code} — {r.text[:100]}")

print("\n🏁 Permissions fix done.")
