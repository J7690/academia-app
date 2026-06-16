import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    j = r.json()
    if isinstance(j, dict) and j.get('ok'):
        return j.get('rows', [])
    return j

# 1. ALL triggers on application_payments
print("### 1. TRIGGERS on app.application_payments ###")
rows = sql("""
  SELECT trigger_name, event_manipulation, action_statement, action_timing
  FROM information_schema.triggers
  WHERE event_object_schema = 'app' AND event_object_table = 'application_payments'
  ORDER BY trigger_name
""")
if isinstance(rows, list):
    for r in rows:
        print(f"  {r['action_timing']:6s} {r['event_manipulation']:8s} {r['trigger_name']:50s} -> {r['action_statement'][:80]}")
else:
    print(f"  {rows}")

# 2. ALL triggers on marketplace_payments
print("\n### 2. TRIGGERS on app.marketplace_payments ###")
rows2 = sql("""
  SELECT trigger_name, event_manipulation, action_statement, action_timing
  FROM information_schema.triggers
  WHERE event_object_schema = 'app' AND event_object_table = 'marketplace_payments'
  ORDER BY trigger_name
""")
if isinstance(rows2, list):
    for r in rows2:
        print(f"  {r['action_timing']:6s} {r['event_manipulation']:8s} {r['trigger_name']:50s} -> {r['action_statement'][:80]}")
else:
    print(f"  {rows2}")

# 3. Look for revenue split function
print("\n### 3. REVENUE SPLIT FUNCTIONS ###")
rows3 = sql("SELECT proname FROM pg_proc WHERE proname LIKE '%split%' OR proname LIKE '%revenue%' OR proname LIKE '%distribute%' OR proname LIKE '%allocat%' ORDER BY proname")
if isinstance(rows3, list):
    for r in rows3:
        print(f"  {r.get('proname','?')}")

# 4. Check app_confirm_ligdicash_payment for revenue split logic
print("\n### 4. RPC app_confirm_ligdicash_payment (full) ###")
defn = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_confirm_ligdicash_payment' LIMIT 1")
if isinstance(defn, list) and defn:
    print(defn[0].get('def', '')[:4000])

# 5. marketplace_merchant_balances schema
print("\n### 5. marketplace_merchant_balances schema ###")
cols = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='marketplace_merchant_balances' ORDER BY ordinal_position")
if isinstance(cols, list):
    for c in cols:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 6. marketplace_payments schema
print("\n### 6. marketplace_payments schema ###")
cols2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='marketplace_payments' ORDER BY ordinal_position")
if isinstance(cols2, list):
    for c in cols2:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 7. Check what happens when payment is confirmed
print("\n### 7. TRIGGER FUNCTIONS on payment confirmation ###")
for fn in ['trg_on_payment_confirmed', 'trg_apply_revenue_split', 'trg_create_commission', 'handle_payment_confirmed', 'fn_revenue_split']:
    defn2 = sql(f"SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = '{fn}' LIMIT 1")
    if isinstance(defn2, list) and defn2:
        print(f"\n  --- {fn} ---")
        print(f"  {defn2[0].get('def', '')[:1500]}")
    else:
        print(f"  --- {fn} --- NOT FOUND")

# 8. ALL trigger functions in app schema
print("\n### 8. ALL TRIGGER FUNCTIONS ###")
rows8 = sql("""
  SELECT DISTINCT p.proname
  FROM pg_trigger t
  JOIN pg_proc p ON t.tgfoid = p.oid
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'app'
  ORDER BY p.proname
""")
if isinstance(rows8, list):
    for r in rows8:
        name = r.get('proname', '?')
        print(f"  {name}")
        # Get short definition
        defn3 = sql(f"SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = '{name}' LIMIT 1")
        if isinstance(defn3, list) and defn3:
            d = defn3[0].get('def', '')
            # Find key words
            if 'revenue' in d.lower() or 'split' in d.lower() or 'commission' in d.lower() or 'balance' in d.lower() or 'payout' in d.lower():
                print(f"    *** CONTAINS REVENUE/SPLIT/COMMISSION/BALANCE/PAYOUT ***")
                print(f"    {d[:600]}")
