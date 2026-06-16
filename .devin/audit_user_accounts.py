import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    return r.json()

def sql_fn(query):
    fname = f"_tmp_audit_{abs(hash(query)) % 99999999}"
    sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {query} RETURN v; END; $fn$;""")
    time.sleep(1.5)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    sql(f"DROP FUNCTION IF EXISTS public.{fname}();")
    return r.json()

print("=" * 70)
print("AUDIT COMPTES UTILISATEURS — Supabase")
print("=" * 70)

# 1. RPCs liées aux comptes utilisateurs
print("\n### 1. RPCs admin user/commercial ###")
rpcs = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', proname, 'args', pg_get_function_arguments(oid)) ORDER BY proname)
  INTO v FROM pg_proc
  WHERE proname LIKE 'app_admin_%user%'
     OR proname LIKE 'app_admin_%commercial%'
     OR proname LIKE 'app_admin_%invitation%'
     OR proname LIKE 'app_admin_%milestone%'
     OR proname LIKE 'app_admin_%promote%'
     OR proname LIKE 'app_admin_%teacher%'
     OR proname LIKE 'app_admin_%merchant%'
     OR proname LIKE 'app_admin_%deleted%';
""")
if isinstance(rpcs, list):
    for r in rpcs:
        print(f"  {r['name']}({r['args']})")
else:
    print(f"  ERROR: {rpcs}")

# 2. Edge Functions liées aux comptes
print("\n### 2. Edge Functions (from code scan) ###")
edge_fns = [
    'admin-create-merchant-account',
    'admin-create-commercial-account', 
    'admin-create-admin-account',
    'admin-create-university-account',
    'admin-create-teacher-account',
    'admin-hard-delete-user-account',
    'admin-promote-user-role',
]
for fn in edge_fns:
    print(f"  {fn}")

# 3. Tables liées aux comptes
print("\n### 3. Tables liées aux comptes ###")
tables = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('t', tablename) ORDER BY tablename)
  INTO v FROM pg_tables WHERE schemaname='app'
    AND (tablename LIKE '%user%' OR tablename LIKE '%commercial%' OR tablename LIKE '%instructor%'
      OR tablename LIKE '%merchant%' OR tablename LIKE '%invitation%' OR tablename LIKE '%referral%'
      OR tablename = 'universities');
""")
if isinstance(tables, list):
    for t in tables:
        print(f"  app.{t['t']}")
else:
    print(f"  ERROR: {tables}")

# 4. Comptage par rôle
print("\n### 4. Comptage des comptes par rôle ###")
counts = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('role', role, 'count', cnt) ORDER BY cnt DESC)
  INTO v FROM (
    SELECT raw_user_meta_data->>'role' as role, COUNT(*) as cnt
    FROM auth.users
    GROUP BY raw_user_meta_data->>'role'
  ) t;
""")
if isinstance(counts, list):
    for c in counts:
        print(f"  {c['role']}: {c['count']} comptes")
else:
    print(f"  ERROR: {counts}")

# 5. Colonnes des tables clés
print("\n### 5. Colonnes des tables clés ###")
for tbl in ['user_invitations', 'user_referrals', 'referral_commissions', 'instructors', 'universities']:
    cols = sql_fn(f"""
      SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
      INTO v FROM information_schema.columns
      WHERE table_schema='app' AND table_name='{tbl}';
    """)
    if isinstance(cols, list):
        col_list = ', '.join([f"{c['col']}({c['type']})" for c in cols])
        print(f"\n  app.{tbl}: {col_list}")
    else:
        print(f"\n  app.{tbl}: NOT FOUND or ERROR")

# 6. Merchants table
print("\n### 6. Merchants table ###")
merchants = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns
  WHERE table_schema='app' AND table_name='merchants';
""")
if isinstance(merchants, list):
    col_list = ', '.join([f"{c['col']}({c['type']})" for c in merchants])
    print(f"  app.merchants: {col_list}")
else:
    print(f"  app.merchants: NOT FOUND — checking marketplace_merchants...")
    mm = sql_fn("""
      SELECT jsonb_agg(tablename) INTO v FROM pg_tables WHERE schemaname='app' AND tablename LIKE '%merchant%';
    """)
    print(f"  Tables marchands: {mm}")

# 7. Deleted users table
print("\n### 7. Deleted users archive ###")
du = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns
  WHERE table_schema='app' AND table_name='deleted_users';
""")
if isinstance(du, list):
    col_list = ', '.join([f"{c['col']}({c['type']})" for c in du])
    print(f"  app.deleted_users: {col_list}")
else:
    print(f"  app.deleted_users: NOT FOUND — checking...")
    du2 = sql_fn("""
      SELECT jsonb_agg(tablename) INTO v FROM pg_tables WHERE schemaname='app' AND tablename LIKE '%deleted%';
    """)
    print(f"  Tables deleted: {du2}")

# 8. admin_action_logs
print("\n### 8. Admin action logs ###")
al = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns
  WHERE table_schema='app' AND table_name='admin_action_logs';
""")
if isinstance(al, list):
    col_list = ', '.join([f"{c['col']}({c['type']})" for c in al])
    print(f"  app.admin_action_logs: {col_list}")
else:
    print(f"  app.admin_action_logs: NOT FOUND")

# 9. Commercials overview RPC structure test
print("\n### 9. app_admin_list_commercials_overview response shape ###")
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_list_commercials_overview", headers=H, json={})
body = r.json()
if isinstance(body, dict) and body.get('success'):
    commercials = body.get('commercials', [])
    print(f"  success=true, {len(commercials)} commercials")
    if commercials:
        print(f"  keys: {list(commercials[0].keys())}")
        print(f"  sample: {json.dumps(commercials[0], default=str)[:300]}")
else:
    print(f"  {str(body)[:200]}")

# 10. app_admin_list_users_overview response shape
print("\n### 10. app_admin_list_users_overview response shape ###")
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_list_users_overview", headers=H, json={})
body = r.json()
if isinstance(body, dict) and body.get('success'):
    users = body.get('users', [])
    print(f"  success=true, {len(users)} users total")
    # Count by role
    roles = {}
    for u in users:
        role = u.get('role', 'unknown')
        roles[role] = roles.get(role, 0) + 1
    for role, count in sorted(roles.items(), key=lambda x: -x[1]):
        print(f"    {role}: {count}")
    if users:
        print(f"  user keys: {list(users[0].keys())}")
else:
    print(f"  {str(body)[:200]}")

# 11. Milestone claims
print("\n### 11. Milestone tables ###")
ms = sql_fn("""
  SELECT jsonb_agg(tablename) INTO v FROM pg_tables WHERE schemaname='app' AND tablename LIKE '%milestone%';
""")
print(f"  Tables: {ms}")

print("\n" + "=" * 70)
print("FIN AUDIT")
print("=" * 70)
