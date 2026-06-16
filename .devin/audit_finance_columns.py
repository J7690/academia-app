import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_json(query):
    """Use jsonb_agg to force rows back through admin_execute_sql"""
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": query})
    j = r.json()
    if isinstance(j, dict) and j.get('ok') and j.get('rows'):
        val = j['rows'][0].get('j') or j['rows'][0].get('result')
        if isinstance(val, str):
            return json.loads(val)
        return val
    return j

out = []
def p(s):
    print(s)
    out.append(str(s))

p("=" * 80)
p("AUDIT COLONNES — Tables finance (via jsonb_agg)")
p("=" * 80)

# 1. All app tables
p("\n### 1. ALL TABLES in schema app ###")
data = sql_json("SELECT jsonb_agg(table_name ORDER BY table_name) as j FROM information_schema.tables WHERE table_schema='app' AND table_type='BASE TABLE'")
if isinstance(data, list):
    for t in data:
        p(f"  app.{t}")

# 2-7. Columns for each finance table
for table in ['platform_ledger', 'payout_queue', 'actor_balances', 'application_payments', 'marketplace_payments', 'referral_commissions', 'revenue_split_rules', 'subscriptions']:
    p(f"\n### app.{table} — COLUMNS ###")
    data = sql_json(f"""
      SELECT jsonb_agg(jsonb_build_object('col', column_name, 'type', data_type, 'nullable', is_nullable) ORDER BY ordinal_position) as j
      FROM information_schema.columns WHERE table_schema='app' AND table_name='{table}'
    """)
    if isinstance(data, list):
        for c in data:
            p(f"  {c['col']:40s} {c['type']:25s} null={c['nullable']}")
    else:
        p(f"  NOT FOUND or ERROR: {data}")

# 8. RLS policies
p("\n### RLS POLICIES on finance tables ###")
data = sql_json("""
  SELECT jsonb_agg(jsonb_build_object('table', tablename, 'policy', policyname, 'cmd', cmd, 'roles', roles) ORDER BY tablename) as j
  FROM pg_policies WHERE schemaname='app' AND tablename IN ('platform_ledger','payout_queue','actor_balances')
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r['table']:25s} {r['policy']:50s} {r['cmd']:8s} {r['roles']}")
else:
    p(f"  {data}")

# 9. Triggers
p("\n### TRIGGERS on finance tables ###")
data = sql_json("""
  SELECT jsonb_agg(jsonb_build_object('table', event_object_table, 'trigger', trigger_name, 'timing', action_timing, 'event', event_manipulation) ORDER BY event_object_table) as j
  FROM information_schema.triggers WHERE event_object_schema='app' AND event_object_table IN ('platform_ledger','payout_queue','actor_balances','application_payments')
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r['table']:25s} {r['trigger']:50s} {r['timing']} {r['event']}")
else:
    p(f"  {data}")

# 10. Realtime publication
p("\n### REALTIME PUBLICATION (app schema) ###")
data = sql_json("""
  SELECT jsonb_agg(jsonb_build_object('schema', schemaname, 'table', tablename) ORDER BY schemaname, tablename) as j
  FROM pg_publication_tables WHERE pubname='supabase_realtime'
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r['schema']}.{r['table']}")
else:
    p(f"  {data}")

# 11. pg_cron jobs
p("\n### PG_CRON JOBS ###")
data = sql_json("SELECT jsonb_agg(jsonb_build_object('name', jobname, 'schedule', schedule, 'cmd', LEFT(command, 120))) as j FROM cron.job")
if isinstance(data, list):
    for r in data:
        p(f"  {r['name']:35s} {r['schedule']:15s} {r['cmd'][:100]}")
else:
    p(f"  {data}")

# 12. All admin RPCs (finance)
p("\n### ALL ADMIN RPCs (finance-related) ###")
data = sql_json("""
  SELECT jsonb_agg(proname ORDER BY proname) as j FROM pg_proc
  WHERE proname LIKE 'app_admin%'
    AND (proname LIKE '%treasury%' OR proname LIKE '%payout%' OR proname LIKE '%ledger%'
         OR proname LIKE '%balance%' OR proname LIKE '%split%' OR proname LIKE '%finance%'
         OR proname LIKE '%payment%' OR proname LIKE '%commission%' OR proname LIKE '%subscription%')
""")
if isinstance(data, list):
    for r in data:
        p(f"  {r}")
else:
    p(f"  {data}")

# 13. Sample platform_ledger data
p("\n### SAMPLE platform_ledger (3 rows) ###")
data = sql_json("SELECT jsonb_agg(row_to_json(t)::jsonb) as j FROM (SELECT * FROM app.platform_ledger ORDER BY created_at DESC LIMIT 3) t")
if isinstance(data, list):
    for r in data:
        p(f"  {json.dumps(r, ensure_ascii=False)}")
else:
    p(f"  {data}")

# 14. Sample application_payments
p("\n### SAMPLE application_payments (3 recent) ###")
data = sql_json("SELECT jsonb_agg(row_to_json(t)::jsonb) as j FROM (SELECT id, student_id, amount_paid, currency, payment_reason, status, payment_channel, ligdicash_status, confirmed_at, created_at FROM app.application_payments ORDER BY created_at DESC LIMIT 3) t")
if isinstance(data, list):
    for r in data:
        p(f"  {json.dumps(r, ensure_ascii=False)}")
else:
    p(f"  {data}")

# Save
with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_finance_columns.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
p("\n>>> Saved to .windsurf/logs/audit_finance_columns.txt")
