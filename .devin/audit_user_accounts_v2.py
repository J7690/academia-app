import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_fn(query):
    fname = f"_tmp_au2_{abs(hash(query)) % 99999999}"
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {query} RETURN v; END; $fn$;"""})
    time.sleep(1.5)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return r.json()

print("=" * 70)
print("AUDIT V2 — Comptes utilisateurs détails")
print("=" * 70)

# 1. marketplace_merchants columns
print("\n### 1. marketplace_merchants ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='marketplace_merchants';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
print(f"\n  Count:")
cnt = sql_fn("SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.marketplace_merchants;")
print(f"  {cnt}")

# 2. merchant_profiles columns
print("\n### 2. merchant_profiles ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='merchant_profiles';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
cnt = sql_fn("SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.merchant_profiles;")
print(f"  Count: {cnt}")

# 3. commercial_profiles columns  
print("\n### 3. commercial_profiles ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='commercial_profiles';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
cnt = sql_fn("SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.commercial_profiles;")
print(f"  Count: {cnt}")

# 4. admin_user_action_logs columns
print("\n### 4. admin_user_action_logs ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='admin_user_action_logs';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
cnt = sql_fn("SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.admin_user_action_logs;")
print(f"  Count: {cnt}")

# 5. commercial_milestones columns
print("\n### 5. commercial_milestones ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='commercial_milestones';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")

# 6. commercial_milestone_claims columns
print("\n### 6. commercial_milestone_claims ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='commercial_milestone_claims';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")

# 7. user_admin_status columns
print("\n### 7. user_admin_status ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='user_admin_status';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")

# 8. user_presence columns
print("\n### 8. user_presence ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='user_presence';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")

# 9. admin_users columns
print("\n### 9. admin_users ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='admin_users';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")

# 10. Check Edge Functions that exist
print("\n### 10. Edge Functions listing ###")
import os
ef_path = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions"
if os.path.isdir(ef_path):
    fns = [d for d in os.listdir(ef_path) if os.path.isdir(os.path.join(ef_path, d)) and 'admin' in d.lower()]
    for fn in sorted(fns):
        print(f"  {fn}/")

# 11. Deleted users RPC — check if it queries auth or app table
print("\n### 11. Deleted users RPC source ###")
r = sql_fn("""
  SELECT jsonb_build_object('src', pg_get_functiondef(oid))
  INTO v FROM pg_proc WHERE proname = 'app_admin_list_deleted_users';
""")
if isinstance(r, dict) and 'src' in r:
    src = r['src']
    # Find what table it queries
    if 'auth.users' in src:
        print("  Queries auth.users (flags is_deleted)")
    elif 'app.deleted_users' in src:
        print("  Queries app.deleted_users")
    else:
        print(f"  Source: {src[:400]}")
else:
    print(f"  Result: {str(r)[:200]}")

print("\n" + "=" * 70)
print("FIN AUDIT V2")
print("=" * 70)
