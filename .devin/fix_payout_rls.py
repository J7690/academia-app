import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": query})
    j = r.json()
    print(f"  -> {j}")
    return j

print("=" * 70)
print("DIAGNOSTIC: RLS sur payout_queue et platform_ledger")
print("=" * 70)

# 1. Check RLS status
print("\n### 1. RLS enabled? ###")
sql("""
  SELECT relname, relrowsecurity, relforcerowsecurity
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'app' AND c.relname IN ('payout_queue', 'platform_ledger', 'actor_balances')
""")

# 2. Check existing policies
print("\n### 2. Existing RLS policies ###")
sql("""
  SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
  FROM pg_policies
  WHERE schemaname = 'app' AND tablename IN ('payout_queue', 'platform_ledger', 'actor_balances')
""")

# 3. Check GRANT permissions on the tables
print("\n### 3. Grants on app.payout_queue ###")
sql("""
  SELECT grantee, privilege_type
  FROM information_schema.table_privileges
  WHERE table_schema = 'app' AND table_name = 'payout_queue'
""")

print("\n### 4. Grants on app.platform_ledger ###")
sql("""
  SELECT grantee, privilege_type
  FROM information_schema.table_privileges
  WHERE table_schema = 'app' AND table_name = 'platform_ledger'
""")

print("\n### 5. Grants on app.actor_balances ###")
sql("""
  SELECT grantee, privilege_type
  FROM information_schema.table_privileges
  WHERE table_schema = 'app' AND table_name = 'actor_balances'
""")

# 4. Fix: Grant permissions to service_role and authenticated
print("\n" + "=" * 70)
print("FIX: Grant permissions")
print("=" * 70)

# service_role should bypass RLS, but we need GRANT on the schema and tables
print("\n### Fix A: GRANT USAGE on schema app ###")
sql("GRANT USAGE ON SCHEMA app TO service_role, authenticated, anon;")

print("\n### Fix B: GRANT ALL on payout_queue ###")
sql("GRANT ALL ON app.payout_queue TO service_role;")
sql("GRANT SELECT ON app.payout_queue TO authenticated;")

print("\n### Fix C: GRANT ALL on platform_ledger ###")
sql("GRANT ALL ON app.platform_ledger TO service_role;")
sql("GRANT SELECT ON app.platform_ledger TO authenticated;")

print("\n### Fix D: GRANT ALL on actor_balances ###")
sql("GRANT ALL ON app.actor_balances TO service_role;")
sql("GRANT SELECT ON app.actor_balances TO authenticated;")

# 5. Add RLS policies for service_role (full access)
print("\n### Fix E: RLS policies for payout_queue ###")
sql("ALTER TABLE app.payout_queue ENABLE ROW LEVEL SECURITY;")
sql("DROP POLICY IF EXISTS service_role_all_payout_queue ON app.payout_queue;")
sql("""
  CREATE POLICY service_role_all_payout_queue ON app.payout_queue
  FOR ALL TO service_role USING (true) WITH CHECK (true);
""")

print("\n### Fix F: RLS policies for platform_ledger ###")
sql("ALTER TABLE app.platform_ledger ENABLE ROW LEVEL SECURITY;")
sql("DROP POLICY IF EXISTS service_role_all_platform_ledger ON app.platform_ledger;")
sql("""
  CREATE POLICY service_role_all_platform_ledger ON app.platform_ledger
  FOR ALL TO service_role USING (true) WITH CHECK (true);
""")

print("\n### Fix G: RLS policies for actor_balances ###")
sql("ALTER TABLE app.actor_balances ENABLE ROW LEVEL SECURITY;")
sql("DROP POLICY IF EXISTS service_role_all_actor_balances ON app.actor_balances;")
sql("""
  CREATE POLICY service_role_all_actor_balances ON app.actor_balances
  FOR ALL TO service_role USING (true) WITH CHECK (true);
""")

print("\nDone! Permissions fixed.")
