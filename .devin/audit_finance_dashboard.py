import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": query})
    j = r.json()
    if isinstance(j, dict) and j.get('ok'):
        return j.get('rows', []), j.get('affected_rows', 0)
    return j, 0

out = []
def p(s):
    print(s)
    out.append(s)

p("=" * 80)
p("AUDIT SUPABASE — Finance Dashboard (tables, colonnes, RPCs, data)")
p("=" * 80)

# 1. ALL tables in app schema
p("\n### 1. TABLES schema 'app' ###")
rows, _ = sql("""
  SELECT table_name FROM information_schema.tables
  WHERE table_schema = 'app' AND table_type = 'BASE TABLE'
  ORDER BY table_name
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  app.{r['table_name']}")

# 2. platform_ledger columns
p("\n### 2. app.platform_ledger — COLUMNS ###")
rows, _ = sql("""
  SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_schema='app' AND table_name='platform_ledger'
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:35s} {r['data_type']:20s} null={r['is_nullable']} default={r.get('column_default','')}")

# 3. payout_queue columns
p("\n### 3. app.payout_queue — COLUMNS ###")
rows, _ = sql("""
  SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_schema='app' AND table_name='payout_queue'
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:35s} {r['data_type']:20s} null={r['is_nullable']} default={r.get('column_default','')}")

# 4. actor_balances columns
p("\n### 4. app.actor_balances — COLUMNS ###")
rows, _ = sql("""
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema='app' AND table_name='actor_balances'
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:35s} {r['data_type']:20s} null={r['is_nullable']}")

# 5. application_payments columns
p("\n### 5. app.application_payments — COLUMNS ###")
rows, _ = sql("""
  SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_schema='app' AND table_name='application_payments'
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:35s} {r['data_type']}")

# 6. marketplace_payments columns
p("\n### 6. app.marketplace_payments — COLUMNS ###")
rows, _ = sql("""
  SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_schema='app' AND table_name='marketplace_payments'
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:35s} {r['data_type']}")

# 7. referral_commissions columns
p("\n### 7. app.referral_commissions — COLUMNS ###")
rows, _ = sql("""
  SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_schema='app' AND table_name='referral_commissions'
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:35s} {r['data_type']}")

# 8. ALL RPCs containing 'admin' and finance-related
p("\n### 8. RPCs admin finance-related ###")
rows, _ = sql("""
  SELECT proname FROM pg_proc
  WHERE proname LIKE 'app_admin%'
    AND (proname LIKE '%treasury%' OR proname LIKE '%payout%' OR proname LIKE '%ledger%'
         OR proname LIKE '%balance%' OR proname LIKE '%split%' OR proname LIKE '%finance%'
         OR proname LIKE '%payment%' OR proname LIKE '%commission%')
  ORDER BY proname
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['proname']}")

# 9. Full definitions of key RPCs
for rpc_name in ['app_admin_get_treasury_summary', 'app_admin_list_ledger', 'app_admin_list_payout_queue', 'app_admin_list_actor_balances', 'app_admin_trigger_payouts']:
    p(f"\n### RPC: {rpc_name} ###")
    rows, _ = sql(f"SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = '{rpc_name}' LIMIT 1")
    if isinstance(rows, list) and rows:
        defn = rows[0].get('def', '')
        p(defn[:2500])
    else:
        p(f"  NOT FOUND")

# 10. Data counts
p("\n### 10. DATA COUNTS ###")
for t in ['platform_ledger', 'payout_queue', 'actor_balances', 'application_payments', 'marketplace_payments', 'referral_commissions', 'revenue_split_rules']:
    rows, _ = sql(f"SELECT COUNT(*) as cnt FROM app.{t}")
    cnt = rows[0]['cnt'] if isinstance(rows, list) and rows else '?'
    p(f"  app.{t:40s} {cnt} rows")

# 11. Existing RLS policies on finance tables
p("\n### 11. RLS POLICIES on finance tables ###")
rows, _ = sql("""
  SELECT tablename, policyname, permissive, roles, cmd
  FROM pg_policies
  WHERE schemaname = 'app'
    AND tablename IN ('platform_ledger', 'payout_queue', 'actor_balances')
  ORDER BY tablename, policyname
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['tablename']:25s} {r['policyname']:45s} {r['cmd']:8s} roles={r['roles']}")

# 12. Existing triggers on finance tables
p("\n### 12. TRIGGERS on finance tables ###")
rows, _ = sql("""
  SELECT event_object_table, trigger_name, action_timing, event_manipulation
  FROM information_schema.triggers
  WHERE event_object_schema = 'app'
    AND event_object_table IN ('platform_ledger', 'payout_queue', 'actor_balances', 'application_payments')
  ORDER BY event_object_table, trigger_name
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['event_object_table']:25s} {r['trigger_name']:45s} {r['action_timing']} {r['event_manipulation']}")

# 13. Realtime publication status
p("\n### 13. REALTIME PUBLICATION ###")
rows, _ = sql("""
  SELECT schemaname, tablename FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
  ORDER BY schemaname, tablename
""")
if isinstance(rows, list):
    finance_tables = {'platform_ledger', 'payout_queue', 'actor_balances', 'application_payments'}
    for r in rows:
        mark = " <<<" if r['tablename'] in finance_tables else ""
        if r['schemaname'] == 'app' or r['tablename'] in finance_tables:
            p(f"  {r['schemaname']}.{r['tablename']}{mark}")

# 14. auth.users columns relevant (for actor name resolution)
p("\n### 14. auth.users relevant columns ###")
rows, _ = sql("""
  SELECT column_name, data_type FROM information_schema.columns
  WHERE table_schema='auth' AND table_name='users'
    AND column_name IN ('id', 'email', 'raw_user_meta_data', 'created_at')
  ORDER BY ordinal_position
""")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r['column_name']:30s} {r['data_type']}")

# 15. Sample raw_user_meta_data keys
p("\n### 15. SAMPLE raw_user_meta_data keys ###")
rows, _ = sql("SELECT DISTINCT jsonb_object_keys(raw_user_meta_data) as k FROM auth.users LIMIT 20")
if isinstance(rows, list):
    for r in rows:
        p(f"  {r.get('k','?')}")

# Save to file
with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_finance_supabase.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
p("\n>>> Saved to .windsurf/logs/audit_finance_supabase.txt")
