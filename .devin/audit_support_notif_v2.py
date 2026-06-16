import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}
def exec_sql(sql):
    return requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql}).json()
def run_fn(body):
    fname = f"_tmp_s2_{int(time.time()*1000) % 999999999}"
    exec_sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {body} RETURN v; END; $fn$;""")
    time.sleep(2)
    exec_sql("NOTIFY pgrst, 'reload schema'")
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    exec_sql(f"DROP FUNCTION IF EXISTS public.{fname}()")
    return result

# 1. Find push_tokens table (any schema)
print("=== 1. push_tokens table location ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('schema', table_schema, 'table', table_name))
  INTO v FROM information_schema.tables WHERE table_name LIKE '%push%token%' OR table_name LIKE '%fcm%token%';
""")
print(f"  {r}")

# 2. Notification events domains
print("\n=== 2. Notification event domains ===")
r = run_fn("""
  SELECT jsonb_agg(DISTINCT jsonb_build_object('domain', domain, 'event', event_type))
  INTO v FROM app.notification_events;
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)[:800]}")

# 3. How register_push_token works
print("\n=== 3. register_push_token ===")
r = run_fn("""
  SELECT jsonb_build_object('src', pg_get_functiondef(oid))
  INTO v FROM pg_proc WHERE proname = 'register_push_token';
""")
if isinstance(r, dict) and 'src' in r:
    print(f"  {r['src'][:600]}")
else:
    print(f"  {r}")

# 4. Check if there's a user_devices or device_tokens table
print("\n=== 4. Device/token tables ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('schema', table_schema, 'table', table_name))
  INTO v FROM information_schema.tables
  WHERE table_name LIKE '%device%' OR table_name LIKE '%token%' OR table_name LIKE '%fcm%';
""")
print(f"  {r}")

# 5. Support stats
print("\n=== 5. Support conversations stats ===")
r = run_fn("""
  SELECT jsonb_build_object(
    'total_conversations', (SELECT COUNT(*) FROM app.support_conversations),
    'open', (SELECT COUNT(*) FROM app.support_conversations WHERE status = 'open'),
    'closed', (SELECT COUNT(*) FROM app.support_conversations WHERE status = 'closed'),
    'total_messages', (SELECT COUNT(*) FROM app.support_messages),
    'user_messages', (SELECT COUNT(*) FROM app.support_messages WHERE sender_side = 'user'),
    'admin_messages', (SELECT COUNT(*) FROM app.support_messages WHERE sender_side = 'admin')
  ) INTO v;
""")
print(f"  {json.dumps(r, indent=2)}")

print("\n=== FIN ===")
