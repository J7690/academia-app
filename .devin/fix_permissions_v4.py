"""
FIX permissions using DO block via execute_sql RPC
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
    ok = r.status_code == 200
    data = r.json() if ok else r.text[:300]
    if ok and isinstance(data, list):
        for row in data[:5]:
            print(f"    {row}")
    elif ok:
        print(f"    {str(data)[:300]}")
    else:
        print(f"    ❌ HTTP {r.status_code}: {data}")
    return ok, data

# Try DO block
print("=" * 60)
print("Attempt 1: DO block")
ok, _ = sql("""
DO $$
BEGIN
  EXECUTE 'GRANT ALL ON app.challenge_game_live_sessions TO service_role';
  EXECUTE 'GRANT ALL ON app.prep_live_sessions TO service_role';
  EXECUTE 'GRANT ALL ON app.prep_live_participants TO service_role';
  EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.challenge_game_live_sessions TO authenticated';
  EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.prep_live_sessions TO authenticated';
  EXECUTE 'GRANT SELECT, INSERT, UPDATE ON app.prep_live_participants TO authenticated';
END;
$$;
""", "DO block with EXECUTE grants")

if not ok:
    # Try approach 2: Check what execute_sql actually accepts
    print("\n" + "=" * 60)
    print("Attempt 2: Check execute_sql source code")
    sql("""
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'execute_sql' AND n.nspname = 'public'
""", "execute_sql source")

    # Try approach 3: Use SELECT with side effects
    print("\n" + "=" * 60)
    print("Attempt 3: Check current permissions on tables")
    sql("""
SELECT grantee, privilege_type, table_schema, table_name
FROM information_schema.table_privileges
WHERE table_name IN ('challenge_game_live_sessions', 'prep_live_sessions', 'prep_live_participants')
ORDER BY table_name, grantee
""", "Current permissions on live tables")

    # Try approach 4: Check if there's a more permissive admin RPC
    print("\n" + "=" * 60)
    print("Attempt 4: List admin RPCs that might execute DDL")
    sql("""
SELECT routine_name FROM information_schema.routines
WHERE routine_name LIKE '%admin%sql%' OR routine_name LIKE '%exec%' OR routine_name LIKE '%run%'
ORDER BY routine_name
""", "Admin SQL execution RPCs")

# Also try connecting via pooler
print("\n" + "=" * 60)
print("Attempt 5: Direct DB via pooler (port 6543)")
try:
    import psycopg2
    conn = psycopg2.connect(
        host=f"db.{SUPABASE_URL.split('//')[1].split('.supabase')[0]}.supabase.co",
        port=6543,
        dbname="postgres",
        user="postgres",
        password="Azert0Yuiop",
        sslmode="require",
    )
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("GRANT ALL ON app.challenge_game_live_sessions TO service_role")
    print("  ✅ Success via pooler!")
    cur.close()
    conn.close()
except Exception as e:
    print(f"  ❌ Pooler also failed: {e}")

# Try with connection string from config directly
print("\n" + "=" * 60)
print("Attempt 6: Direct DB via connection string")
try:
    import psycopg2
    conn = psycopg2.connect("postgres://postgres:Azert0Yuiop@db.thevdfcwlcqzdoybfvgs.supabase.co:5432/postgres?sslmode=require")
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT 1")
    print("  ✅ Connected!")
    cur.close()
    conn.close()
except Exception as e:
    print(f"  ❌ Failed: {str(e)[:200]}")

# Try with aws-0- prefix
print("\n" + "=" * 60)
print("Attempt 7: Try pooler endpoint")
try:
    import psycopg2
    conn = psycopg2.connect(
        host="aws-0-eu-central-1.pooler.supabase.com",
        port=6543,
        dbname="postgres",
        user="postgres.thevdfcwlcqzdoybfvgs",
        password="Azert0Yuiop",
        sslmode="require",
    )
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT 1")
    print("  ✅ Connected via pooler!")
    
    grants = [
        "GRANT ALL ON ALL TABLES IN SCHEMA app TO service_role",
        "GRANT ALL ON app.challenge_game_live_sessions TO service_role",
        "GRANT ALL ON app.prep_live_sessions TO service_role",
        "GRANT ALL ON app.prep_live_participants TO service_role",
        "GRANT SELECT, INSERT, UPDATE ON app.challenge_game_live_sessions TO authenticated",
        "GRANT SELECT, INSERT, UPDATE ON app.prep_live_sessions TO authenticated",
        "GRANT SELECT, INSERT, UPDATE ON app.prep_live_participants TO authenticated",
    ]
    for g in grants:
        try:
            cur.execute(g)
            print(f"  ✅ {g}")
        except Exception as e:
            print(f"  ⚠ {g} → {e}")
    
    cur.close()
    conn.close()
except Exception as e:
    print(f"  ❌ Pooler failed: {str(e)[:200]}")

print("\n🏁 Done.")
