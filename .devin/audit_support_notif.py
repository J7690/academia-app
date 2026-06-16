"""Audit du système de notification support admin."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    return requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql}).json()

def run_fn(body):
    fname = f"_tmp_sn_{int(time.time()*1000) % 999999999}"
    exec_sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {body} RETURN v; END; $fn$;""")
    time.sleep(2)
    exec_sql("NOTIFY pgrst, 'reload schema'")
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    exec_sql(f"DROP FUNCTION IF EXISTS public.{fname}()")
    return result

# 1. Triggers on support_messages
print("=== 1. Triggers on support_messages ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', t.tgname, 'event', t.tgtype::text, 'func', p.proname))
  INTO v
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_proc p ON t.tgfoid = p.oid
  WHERE n.nspname = 'app' AND c.relname = 'support_messages';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 2. Triggers on support_conversations
print("\n=== 2. Triggers on support_conversations ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', t.tgname, 'event', t.tgtype::text, 'func', p.proname))
  INTO v
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_proc p ON t.tgfoid = p.oid
  WHERE n.nspname = 'app' AND c.relname = 'support_conversations';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 3. notification_events table structure
print("\n=== 3. notification_events table ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='notification_events';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 4. Existing notification event types
print("\n=== 4. Notification event types used ===")
r = run_fn("""
  SELECT jsonb_agg(DISTINCT jsonb_build_object('target', target_type, 'event', event_type))
  INTO v FROM app.notification_events;
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 5. app_queue_notification_event function signature
print("\n=== 5. app_queue_notification_event ===")
r = run_fn("""
  SELECT jsonb_build_object('src', pg_get_functiondef(oid))
  INTO v FROM pg_proc WHERE proname = 'app_queue_notification_event';
""")
if isinstance(r, dict) and 'src' in r:
    print(f"  {r['src'][:800]}")
else:
    print(f"  {r}")

# 6. All admin user IDs
print("\n=== 6. Admin users ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('id', id, 'email', email, 'name', raw_user_meta_data->>'full_name'))
  INTO v FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 7. push_tokens for admins
print("\n=== 7. Push tokens admins ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('user_id', pt.user_id, 'platform', pt.platform, 'token_prefix', LEFT(pt.token, 20)))
  INTO v FROM app.push_tokens pt
  JOIN auth.users u ON u.id = pt.user_id
  WHERE u.raw_user_meta_data->>'role' = 'admin';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 8. support_messages table columns
print("\n=== 8. support_messages columns ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='support_messages';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 9. support_conversations columns
print("\n=== 9. support_conversations columns ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
  INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='support_conversations';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)}")

# 10. send-push-notifications Edge Function
print("\n=== 10. Edge Function send-push-notifications ===")
import os
ef = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions\send-push-notifications\index.ts"
if os.path.isfile(ef):
    with open(ef, 'r', encoding='utf-8') as f:
        content = f.read()
    print(f"  Size: {len(content)} chars")
    # Search for support-related handling
    lines = content.split('\n')
    for i, line in enumerate(lines):
        low = line.lower()
        if 'support' in low or 'admin' in low:
            print(f"  L{i+1}: {line.rstrip()[:120]}")
else:
    print("  Not found")

print("\n=== FIN ===")
