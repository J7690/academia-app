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

def get(path):
    r = requests.get(f"{URL}/rest/v1/{path}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Accept-Profile": "app"})
    return r.json()

print("=" * 80)
print("AUDIT PAYOUT - TABLES, RPCs, DONNEES EXISTANTES")
print("=" * 80)

# 1. Table payout_queue
print("\n### 1. SCHEMA app.payout_queue ###")
cols = sql("SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='payout_queue' ORDER BY ordinal_position")
if isinstance(cols, list) and cols:
    for c in cols:
        print(f"  {c['column_name']:30s} {c['data_type']:25s} default={c.get('column_default','')}")
else:
    print(f"  TABLE NOT FOUND or error: {cols}")

# 2. Table platform_ledger
print("\n### 2. SCHEMA app.platform_ledger ###")
cols2 = sql("SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='platform_ledger' ORDER BY ordinal_position")
if isinstance(cols2, list) and cols2:
    for c in cols2:
        print(f"  {c['column_name']:30s} {c['data_type']:25s} default={c.get('column_default','')}")
else:
    print(f"  TABLE NOT FOUND or error: {cols2}")

# 3. Payout-related RPCs
print("\n### 3. PAYOUT-RELATED RPCs ###")
rpcs = sql("""
  SELECT proname FROM pg_proc
  WHERE proname LIKE '%payout%' OR proname LIKE '%balance%' OR proname LIKE '%withdrawal%'
    OR proname LIKE '%commission%' OR proname LIKE '%revenue%' OR proname LIKE '%ledger%'
  ORDER BY proname
""")
if isinstance(rpcs, list):
    for r in rpcs:
        print(f"  {r.get('proname','?')}")

# 4. Existing payout_queue data
print("\n### 4. PAYOUT_QUEUE DATA ###")
pq = get("payout_queue?select=*&order=created_at.desc&limit=10")
if isinstance(pq, list):
    if pq:
        for p in pq:
            print(f"  id={str(p.get('id',''))[:8]} status={p.get('status','?'):12s} amount={p.get('amount','?'):>8} type={p.get('beneficiary_type','?'):15s} phone={p.get('beneficiary_phone','?')}")
    else:
        print("  (vide)")
else:
    print(f"  ERROR: {pq}")

# 5. Existing platform_ledger data
print("\n### 5. PLATFORM_LEDGER DATA ###")
pl = get("platform_ledger?select=*&order=created_at.desc&limit=10")
if isinstance(pl, list):
    if pl:
        for p in pl:
            print(f"  id={str(p.get('id',''))[:8]} type={p.get('transaction_type','?'):12s} amount={p.get('amount','?'):>8} dir={p.get('direction','?')} counterpart={p.get('counterpart_type','?')}")
    else:
        print("  (vide)")
else:
    print(f"  ERROR: {pl}")

# 6. Instructor-related tables
print("\n### 6. SCHEMA app.instructors (payout columns) ###")
cols3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='instructors' AND column_name LIKE '%payout%' ORDER BY ordinal_position")
if isinstance(cols3, list) and cols3:
    for c in cols3:
        print(f"  {c['column_name']:30s} {c['data_type']}")
else:
    print(f"  {cols3}")

# 7. td_teachers payout columns
print("\n### 7. SCHEMA app.td_teachers (payout columns) ###")
cols4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_teachers' AND column_name LIKE '%payout%' ORDER BY ordinal_position")
if isinstance(cols4, list) and cols4:
    for c in cols4:
        print(f"  {c['column_name']:30s} {c['data_type']}")
else:
    print(f"  {cols4}")

# 8. Universities payout columns
print("\n### 8. SCHEMA app.universities (payout columns) ###")
cols5 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='universities' AND column_name LIKE '%payout%' ORDER BY ordinal_position")
if isinstance(cols5, list) and cols5:
    for c in cols5:
        print(f"  {c['column_name']:30s} {c['data_type']}")
else:
    print(f"  {cols5}")

# 9. Commercial commissions table
print("\n### 9. TABLES RELATED TO COMMERCIALS ###")
tables = sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND (table_name LIKE '%commercial%' OR table_name LIKE '%commission%' OR table_name LIKE '%referral%' OR table_name LIKE '%prospect%') ORDER BY table_name")
if isinstance(tables, list):
    for t in tables:
        print(f"  {t.get('table_name','?')}")

# 10. Merchant-related tables
print("\n### 10. TABLES RELATED TO MERCHANTS ###")
tables2 = sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND (table_name LIKE '%merchant%' OR table_name LIKE '%marketplace%' OR table_name LIKE '%escrow%' OR table_name LIKE '%order%') ORDER BY table_name")
if isinstance(tables2, list):
    for t in tables2:
        print(f"  {t.get('table_name','?')}")

# 11. All app schema tables
print("\n### 11. ALL APP SCHEMA TABLES ###")
all_tables = sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' ORDER BY table_name")
if isinstance(all_tables, list):
    for t in all_tables:
        print(f"  {t.get('table_name','?')}")

# 12. Check RPCs for each actor
print("\n### 12. RPCs PAR ACTEUR ###")
for pattern in ['instructor', 'commercial', 'merchant', 'university', 'admin.*payout', 'admin.*balance']:
    rpcs2 = sql(f"SELECT proname FROM pg_proc WHERE proname ~ 'app_{pattern}' ORDER BY proname")
    if isinstance(rpcs2, list) and rpcs2:
        print(f"\n  [{pattern}]")
        for r in rpcs2:
            print(f"    {r.get('proname','?')}")

# 13. Read RPC definitions for payout RPCs
print("\n### 13. RPC DEFINITIONS (payout) ###")
for rpcname in ['app_instructor_request_payout', 'app_commercial_request_payout', 'app_merchant_request_payout', 'app_university_request_payout']:
    defn = sql(f"SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = '{rpcname}' LIMIT 1")
    if isinstance(defn, list) and defn:
        d = defn[0].get('def', '')
        # Print first 600 chars
        print(f"\n  --- {rpcname} ---")
        print(f"  {d[:800]}")
    else:
        print(f"\n  --- {rpcname} --- NOT FOUND")
