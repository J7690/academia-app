import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_fn(query):
    fname = f"_tmp_b2_{abs(hash(query)) % 99999999}"
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {query} RETURN v; END; $fn$;"""})
    time.sleep(1.5)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return r.json()

# 1. All bobodo tables with columns and counts
print("=== TABLES BOBODO ===")
tables = sql_fn("""
  SELECT jsonb_agg(tablename ORDER BY tablename)
  INTO v FROM pg_tables WHERE schemaname='app' AND tablename LIKE '%bobodo%';
""")
print(f"Tables: {tables}")

if isinstance(tables, list):
    for tbl in tables:
        cols = sql_fn(f"""
          SELECT jsonb_agg(jsonb_build_object('c', column_name, 't', data_type) ORDER BY ordinal_position)
          INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='{tbl}';
        """)
        cnt = sql_fn(f"SELECT jsonb_build_object('n', COUNT(*)) INTO v FROM app.{tbl};")
        n = cnt.get('n', '?') if isinstance(cnt, dict) else '?'
        col_str = ', '.join([f"{c['c']}({c['t']})" for c in cols]) if isinstance(cols, list) else str(cols)
        print(f"\n  app.{tbl} [{n} rows]: {col_str}")

# 2. Edge Function bobodo-chat source (the key filter logic)
print("\n\n=== EDGE FUNCTION bobodo-chat ===")
import os
ef_path = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions\bobodo-chat"
if os.path.isdir(ef_path):
    idx = os.path.join(ef_path, 'index.ts')
    if os.path.isfile(idx):
        with open(idx, 'r', encoding='utf-8') as f:
            content = f.read()
        print(f"Size: {len(content)} chars")
        # Search for filter/block/forbidden/restrict patterns
        lines = content.split('\n')
        for i, line in enumerate(lines):
            low = line.lower()
            for kw in ['filter', 'block', 'forbidden', 'banned', 'restrict', 'interdit', 'refus',
                        'not_allowed', 'off_topic', 'safety', 'guard', 'moderat', 'topic_check',
                        'hors sujet', 'question interdite', 'system_prompt', 'systemprompt',
                        'SYSTEM', 'role.*system']:
                if kw in low:
                    print(f"  L{i+1}: {line.rstrip()[:150]}")
                    break
else:
    print("  Not found")

# 3. Check for other bobodo edge functions
print("\n\n=== ALL BOBODO EDGE FUNCTIONS ===")
ef_base = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions"
for d in sorted(os.listdir(ef_base)):
    if 'bobodo' in d.lower():
        print(f"  {d}/")

# 4. bobodo_knowledge sample data  
print("\n\n=== BOBODO KNOWLEDGE SAMPLE ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('id', id, 'cat', category, 'title', title, 'active', is_active, 'tags', tags))
  INTO v FROM app.bobodo_knowledge LIMIT 10;
""")
if isinstance(r, list):
    for item in r:
        print(f"  [{item.get('cat')}] {item.get('title')} (active={item.get('active')}, tags={item.get('tags')})")
else:
    print(f"  {r}")

# 5. bobodo_answer_cache sample
print("\n\n=== BOBODO ANSWER CACHE ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('q', LEFT(question_text,80), 'cat', category, 'hits', hit_count))
  INTO v FROM app.bobodo_answer_cache ORDER BY hit_count DESC LIMIT 10;
""")
if isinstance(r, list):
    for item in r:
        print(f"  [{item.get('cat')}] hits={item.get('hits')}: {item.get('q')}")
else:
    print(f"  {r}")

# 6. bobodo_unanswered_questions sample
print("\n\n=== BOBODO UNANSWERED QUESTIONS ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('q', LEFT(question_text,80), 'cat', category, 'ts', created_at))
  INTO v FROM app.bobodo_unanswered_questions ORDER BY created_at DESC LIMIT 10;
""")
if isinstance(r, list):
    for item in r:
        print(f"  [{item.get('cat')}] {item.get('q')}")
else:
    print(f"  {r}")

# 7. bobodo_detected_needs sample
print("\n\n=== BOBODO DETECTED NEEDS ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('q', LEFT(question_text,80), 'cat', category, 'need', LEFT(need_summary,80)))
  INTO v FROM app.bobodo_detected_needs ORDER BY detected_at DESC LIMIT 10;
""")
if isinstance(r, list):
    for item in r:
        print(f"  [{item.get('cat')}] {item.get('need')}")
else:
    print(f"  {r}")

# 8. bobodo_messages sample (to see safety_flag usage)
print("\n\n=== BOBODO MESSAGES (safety flags) ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('sender', sender, 'flag', safety_flag, 'content', LEFT(content,60)))
  INTO v FROM (
    SELECT sender, safety_flag, content FROM app.bobodo_messages
    WHERE safety_flag IS NOT NULL AND safety_flag != 'safe'
    ORDER BY created_at DESC LIMIT 10
  ) t;
""")
if isinstance(r, list):
    for item in r:
        print(f"  [{item.get('flag')}] {item.get('sender')}: {item.get('content')}")
else:
    print(f"  Flagged messages: {r}")

# 9. Total messages stats
print("\n\n=== BOBODO STATS ===")
r = sql_fn("""
  SELECT jsonb_build_object(
    'total_sessions', (SELECT COUNT(*) FROM app.bobodo_sessions),
    'total_messages', (SELECT COUNT(*) FROM app.bobodo_messages),
    'flagged_messages', (SELECT COUNT(*) FROM app.bobodo_messages WHERE safety_flag IS NOT NULL AND safety_flag != 'safe'),
    'unanswered', (SELECT COUNT(*) FROM app.bobodo_unanswered_questions),
    'detected_needs', (SELECT COUNT(*) FROM app.bobodo_detected_needs),
    'knowledge_entries', (SELECT COUNT(*) FROM app.bobodo_knowledge),
    'cache_entries', (SELECT COUNT(*) FROM app.bobodo_answer_cache)
  ) INTO v;
""")
print(f"  {json.dumps(r, indent=2)}")

# 10. Admin bobodo RPCs for managing content
print("\n\n=== ADMIN BOBODO RPCs ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', proname, 'args', pg_get_function_arguments(oid)) ORDER BY proname)
  INTO v FROM pg_proc WHERE proname LIKE 'app_admin%bobodo%';
""")
if isinstance(r, list):
    for rpc in r:
        print(f"  {rpc['name']}({rpc['args']})")
else:
    print(f"  {r}")

print("\n=== FIN ===")
