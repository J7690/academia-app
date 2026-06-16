import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_fn(query):
    """Create temp function, call it, drop it — to get SELECT results back"""
    fname = "tmp_audit_fn_" + str(hash(query))[-8:]
    create = f"""
    CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB;
    BEGIN
      {query}
      RETURN v;
    END; $fn$;
    """
    r1 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": create})
    r2 = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    r3 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return r2.json()

out = []
def p(s):
    print(s)
    out.append(str(s))

p("=" * 80)
p("AUDIT COLONNES FINANCE (via temp functions)")
p("=" * 80)

# Columns for each table
for table in ['platform_ledger', 'payout_queue', 'actor_balances', 'application_payments',
              'marketplace_payments', 'referral_commissions', 'revenue_split_rules', 'subscriptions',
              'instructors', 'commercial_profiles', 'marketplace_merchants', 'user_referrals']:
    p(f"\n### app.{table} — COLUMNS ###")
    data = sql_fn(f"""
      SELECT jsonb_agg(jsonb_build_object(
        'c', column_name, 't', data_type, 'n', is_nullable
      ) ORDER BY ordinal_position) INTO v
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='{table}';
    """)
    if isinstance(data, list):
        for c in data:
            p(f"  {c['c']:40s} {c['t']:25s} null={c['n']}")
    elif isinstance(data, dict) and not data.get('message'):
        p(f"  Result: {json.dumps(data, ensure_ascii=False)[:200]}")
    else:
        p(f"  ERROR: {data}")

# RLS policies
p(f"\n### RLS POLICIES ###")
data = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('tbl', tablename, 'pol', policyname, 'cmd', cmd, 'roles', roles::text)
  ORDER BY tablename) INTO v
  FROM pg_policies WHERE schemaname='app'
    AND tablename IN ('platform_ledger','payout_queue','actor_balances');
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r['tbl']:25s} {r['pol']:50s} {r['cmd']:8s} {r['roles']}")
else:
    p(f"  {data}")

# Triggers
p(f"\n### TRIGGERS ###")
data = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('tbl', event_object_table, 'trg', trigger_name, 'time', action_timing, 'evt', event_manipulation)
  ORDER BY event_object_table) INTO v
  FROM information_schema.triggers WHERE event_object_schema='app'
    AND event_object_table IN ('platform_ledger','payout_queue','actor_balances','application_payments');
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r['tbl']:25s} {r['trg']:50s} {r['time']} {r['evt']}")
else:
    p(f"  {data}")

# Realtime
p(f"\n### REALTIME PUBLICATION ###")
data = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object('s', schemaname, 't', tablename) ORDER BY schemaname, tablename) INTO v
  FROM pg_publication_tables WHERE pubname='supabase_realtime';
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r['s']}.{r['t']}")
elif data is None:
    p("  NONE — no tables in supabase_realtime publication")
else:
    p(f"  {data}")

# Admin RPCs finance
p(f"\n### ADMIN RPCs (finance) ###")
data = sql_fn("""
  SELECT jsonb_agg(proname ORDER BY proname) INTO v FROM pg_proc
  WHERE proname LIKE 'app_admin%'
    AND (proname LIKE '%treasury%' OR proname LIKE '%payout%' OR proname LIKE '%ledger%'
         OR proname LIKE '%balance%' OR proname LIKE '%split%' OR proname LIKE '%finance%'
         OR proname LIKE '%payment%' OR proname LIKE '%commission%' OR proname LIKE '%subscription%');
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r}")
else:
    p(f"  {data}")

# Sample application_payments (correct columns)
p(f"\n### SAMPLE application_payments ###")
data = sql_fn("""
  SELECT jsonb_agg(row_to_json(t)::jsonb) INTO v FROM (
    SELECT id::text, student_id::text, amount_paid, currency, payment_reason, status, ligdicash_status, confirmed_at, created_at
    FROM app.application_payments ORDER BY created_at DESC LIMIT 3
  ) t;
""")
if isinstance(data, list):
    for r in data:
        p(f"  {json.dumps(r, ensure_ascii=False)}")
else:
    p(f"  {data}")

with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_finance_columns_v2.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
p("\n>>> Saved to audit_finance_columns_v2.txt")
