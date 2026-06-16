import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_fn(query):
    fname = f"_tmp_bob_{abs(hash(query)) % 99999999}"
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {query} RETURN v; END; $fn$;"""})
    time.sleep(1.5)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return r.json()

print("=" * 70)
print("AUDIT BOBODO — Architecture Supabase")
print("=" * 70)

# 1. All bobodo-related tables
print("\n### 1. Tables Bobodo ###")
r = sql_fn("""
  SELECT jsonb_agg(tablename ORDER BY tablename)
  INTO v FROM pg_tables WHERE schemaname='app' AND tablename LIKE '%bobodo%';
""")
print(f"  {r}")

# Also check for AI/chatbot related tables
print("\n### 1b. Tables IA/chatbot/filter ###")
r = sql_fn("""
  SELECT jsonb_agg(tablename ORDER BY tablename)
  INTO v FROM pg_tables WHERE schemaname='app'
    AND (tablename LIKE '%ai%' OR tablename LIKE '%chat%' OR tablename LIKE '%filter%'
         OR tablename LIKE '%blocked%' OR tablename LIKE '%forbidden%'
         OR tablename LIKE '%banned%' OR tablename LIKE '%moderat%'
         OR tablename LIKE '%topic%' OR tablename LIKE '%restrict%');
""")
print(f"  {r}")

# 2. Columns of each bobodo table
print("\n### 2. Colonnes tables Bobodo ###")
tables_r = sql_fn("""
  SELECT jsonb_agg(tablename ORDER BY tablename)
  INTO v FROM pg_tables WHERE schemaname='app' AND tablename LIKE '%bobodo%';
""")
if isinstance(tables_r, list):
    for tbl in tables_r:
        cols = sql_fn(f"""
          SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
          INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='{tbl}';
        """)
        print(f"\n  app.{tbl}:")
        if isinstance(cols, list):
            for c in cols:
                print(f"    {c['col']} ({c['type']})")
        cnt = sql_fn(f"SELECT jsonb_build_object('c', COUNT(*)) INTO v FROM app.{tbl};")
        print(f"    Count: {cnt}")

# 3. RPCs bobodo
print("\n### 3. RPCs Bobodo ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', proname, 'args', pg_get_function_arguments(oid)) ORDER BY proname)
  INTO v FROM pg_proc WHERE proname LIKE '%bobodo%';
""")
if isinstance(r, list):
    for rpc in r:
        print(f"  {rpc['name']}({rpc['args']})")
else:
    print(f"  {r}")

# 4. RPCs AI/chatbot related
print("\n### 4. RPCs IA/chatbot ###")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('name', proname, 'args', pg_get_function_arguments(oid)) ORDER BY proname)
  INTO v FROM pg_proc WHERE proname LIKE '%ai%' OR proname LIKE '%chatbot%' OR proname LIKE '%filter%topic%'
    OR proname LIKE '%blocked%question%' OR proname LIKE '%forbidden%';
""")
if isinstance(r, list):
    for rpc in r:
        print(f"  {rpc['name']}({rpc['args']})")
else:
    print(f"  {r}")

# 5. Edge Functions bobodo
print("\n### 5. Edge Functions Bobodo ###")
import os
ef_path = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions"
if os.path.isdir(ef_path):
    fns = [d for d in os.listdir(ef_path) if os.path.isdir(os.path.join(ef_path, d)) and ('bobodo' in d.lower() or 'ai' in d.lower() or 'chat' in d.lower())]
    for fn in sorted(fns):
        print(f"  {fn}/")
        idx = os.path.join(ef_path, fn, 'index.ts')
        if os.path.isfile(idx):
            with open(idx, 'r', encoding='utf-8') as f:
                content = f.read()
            print(f"    Size: {len(content)} chars")
            # Look for filter/blocked/forbidden keywords
            for kw in ['filter', 'block', 'forbidden', 'banned', 'restrict', 'topic', 'interdit', 'refus']:
                if kw in content.lower():
                    print(f"    *** Contains keyword: '{kw}' ***")

# 6. Get sources of key bobodo RPCs
print("\n### 6. Sources RPCs Bobodo (filtres) ###")
rpcs_to_inspect = sql_fn("""
  SELECT jsonb_agg(proname ORDER BY proname)
  INTO v FROM pg_proc WHERE proname LIKE '%bobodo%';
""")
if isinstance(rpcs_to_inspect, list):
    for rpc_name in rpcs_to_inspect:
        src = sql_fn(f"""
          SELECT jsonb_build_object('src', pg_get_functiondef(oid))
          INTO v FROM pg_proc WHERE proname = '{rpc_name}';
        """)
        if isinstance(src, dict) and 'src' in src:
            source = src['src']
            print(f"\n  --- {rpc_name} ({len(source)} chars) ---")
            # Print first 800 chars
            print(f"  {source[:800]}")
            # Check for filter keywords
            for kw in ['filter', 'block', 'forbidden', 'banned', 'restrict', 'topic', 'interdit', 'refus', 'categor', 'not_allowed']:
                if kw in source.lower():
                    # Find context
                    idx = source.lower().find(kw)
                    snippet = source[max(0,idx-50):idx+100]
                    print(f"  *** FILTER KEYWORD '{kw}' at char {idx}: ...{snippet}...")

# 7. Check for bobodo_blocked_topics or similar
print("\n### 7. Blocked/filtered topics data ###")
for candidate in ['bobodo_blocked_topics', 'bobodo_filters', 'bobodo_restricted_topics',
                   'ai_blocked_topics', 'chatbot_filters', 'bobodo_settings',
                   'bobodo_config', 'bobodo_categories']:
    r = sql_fn(f"""
      SELECT jsonb_build_object('exists', EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='app' AND tablename='{candidate}'))
      INTO v;
    """)
    if isinstance(r, dict) and r.get('exists'):
        print(f"  ✅ app.{candidate} EXISTS")
        cols = sql_fn(f"""
          SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type) ORDER BY ordinal_position)
          INTO v FROM information_schema.columns WHERE table_schema='app' AND table_name='{candidate}';
        """)
        print(f"    Cols: {cols}")
        data = sql_fn(f"SELECT jsonb_agg(row_to_json(t)::jsonb) INTO v FROM app.{candidate} t LIMIT 20;")
        print(f"    Data: {json.dumps(data, default=str, ensure_ascii=False)[:500]}")

print("\n" + "=" * 70)
print("FIN AUDIT BOBODO")
print("=" * 70)
