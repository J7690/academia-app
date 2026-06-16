import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_fn(query):
    fname = f"_tmp_sub_{abs(hash(query)) % 99999999}"
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {query} RETURN v; END; $fn$;"""})
    time.sleep(1.5)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return r.json()

print("=" * 70)
print("AUDIT ONGLET ABONNEMENTS")
print("=" * 70)

# 1. subscription_plans columns
print("\n### 1. app.subscription_plans ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='subscription_plans';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
else:
    print(f"  NOT FOUND or ERROR: {r}")

# 2. subscriptions columns
print("\n### 2. app.subscriptions ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='subscriptions';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
else:
    print(f"  NOT FOUND or ERROR: {r}")

# 3. Count data
print("\n### 3. Data counts ###")
for tbl in ['subscription_plans', 'subscriptions']:
    cnt = sql_fn(f"SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.{tbl};")
    print(f"  app.{tbl}: {cnt}")

# 4. RPC source — find the sp.title bug
print("\n### 4. app_admin_list_subscriptions source ###")
r = sql_fn("""
  SELECT jsonb_build_object('src', pg_get_functiondef(oid))
  INTO v FROM pg_proc WHERE proname = 'app_admin_list_subscriptions';
""")
if isinstance(r, dict) and 'src' in r:
    src = r['src']
    print(f"  {src[:1200]}")
else:
    print(f"  NOT FOUND: {r}")

# 5. All subscription-related RPCs
print("\n### 5. RPCs subscription-related ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', proname, 'args', pg_get_function_arguments(oid)) ORDER BY proname)
  INTO v FROM pg_proc WHERE proname LIKE '%subscription%';
""")
if isinstance(r, list):
    for rpc in r:
        print(f"  {rpc['name']}({rpc['args']})")
else:
    print(f"  {r}")

# 6. Sample subscription_plans data
print("\n### 6. subscription_plans data ###")
r = sql_fn("""
  SELECT jsonb_agg(row_to_json(sp)::jsonb) INTO v FROM app.subscription_plans sp;
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)[:500]}")

# 7. Sample subscriptions data
print("\n### 7. subscriptions data ###")
r = sql_fn("""
  SELECT jsonb_agg(row_to_json(s)::jsonb) INTO v FROM app.subscriptions s LIMIT 10;
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)[:500]}")

# 8. Check pg_cron jobs related to subscriptions
print("\n### 8. pg_cron subscription jobs ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('id', jobid, 'schedule', schedule, 'command', command, 'active', active))
  INTO v FROM cron.job WHERE command ILIKE '%subscription%';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)[:400]}")

# 9. Check PaywallOverlay references
print("\n### 9. user_feature_entitlements ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='user_feature_entitlements';
""")
if isinstance(r, list):
    for c in r:
        print(f"  {c['col']} ({c['type']})")
cnt = sql_fn("SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.user_feature_entitlements;")
print(f"  Count: {cnt}")

print("\n" + "=" * 70)
print("FIN AUDIT ABONNEMENTS")
print("=" * 70)
