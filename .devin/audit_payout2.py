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

# 1. payout_queue schema
print("### 1. payout_queue schema ###")
cols = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='payout_queue' ORDER BY ordinal_position")
if isinstance(cols, list):
    for c in cols:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 2. platform_ledger schema
print("\n### 2. platform_ledger schema ###")
cols2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='platform_ledger' ORDER BY ordinal_position")
if isinstance(cols2, list):
    for c in cols2:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 3. actor_balances schema
print("\n### 3. actor_balances schema ###")
cols3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='actor_balances' ORDER BY ordinal_position")
if isinstance(cols3, list):
    for c in cols3:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 4. actor_balances data
print("\n### 4. actor_balances data ###")
ab = get("actor_balances?select=*&limit=20")
if isinstance(ab, list):
    for a in ab:
        print(f"  type={a.get('actor_type','?'):15s} id={str(a.get('actor_id',''))[:8]}... available={a.get('available_balance',0):>10} pending={a.get('pending_balance',0):>10} total_earned={a.get('total_earned',0):>10}")
else:
    print(f"  {ab}")

# 5. payout_queue data
print("\n### 5. payout_queue data ###")
pq = get("payout_queue?select=*&order=created_at.desc&limit=10")
if isinstance(pq, list):
    for p in pq:
        print(f"  id={str(p.get('id',''))[:8]}... status={p.get('status','?'):12s} amount={p.get('amount',0):>8} type={p.get('beneficiary_type','?'):15s} phone={p.get('beneficiary_phone','?'):15s} reason={p.get('reason','?')}")
else:
    print(f"  {pq}")

# 6. revenue_split_rules schema + data
print("\n### 6. revenue_split_rules ###")
cols6 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='revenue_split_rules' ORDER BY ordinal_position")
if isinstance(cols6, list):
    for c in cols6:
        print(f"  {c['column_name']:30s} {c['data_type']}")
rules = get("revenue_split_rules?select=*")
if isinstance(rules, list):
    print(f"\n  Data ({len(rules)} rules):")
    for r in rules:
        print(f"    context={r.get('context','?'):20s} actor={r.get('actor_type','?'):15s} pct={r.get('percentage',0):>5}% active={r.get('is_active',False)}")

# 7. referral_commissions schema
print("\n### 7. referral_commissions schema ###")
cols7 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='referral_commissions' ORDER BY ordinal_position")
if isinstance(cols7, list):
    for c in cols7:
        print(f"  {c['column_name']:30s} {c['data_type']}")
rc = get("referral_commissions?select=*&limit=5")
if isinstance(rc, list):
    print(f"  Data ({len(rc)} records)")
    for r in rc:
        print(f"    id={str(r.get('id',''))[:8]}... amount={r.get('commission_amount',0)} status={r.get('status','?')} type={r.get('source_type','?')}")

# 8. commercial_profiles schema
print("\n### 8. commercial_profiles (payout cols) ###")
cols8 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='commercial_profiles' ORDER BY ordinal_position")
if isinstance(cols8, list):
    for c in cols8:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 9. marketplace_merchants schema
print("\n### 9. marketplace_merchants schema ###")
cols9 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='marketplace_merchants' ORDER BY ordinal_position")
if isinstance(cols9, list):
    for c in cols9:
        print(f"  {c['column_name']:30s} {c['data_type']}")

# 10. Edge Functions deployed
print("\n### 10. EDGE FUNCTIONS (local files) ###")
import os, glob
ef_dir = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions"
if os.path.isdir(ef_dir):
    for d in sorted(os.listdir(ef_dir)):
        fpath = os.path.join(ef_dir, d, "index.ts")
        if os.path.isfile(fpath):
            sz = os.path.getsize(fpath)
            print(f"  {d:40s} {sz:>6} bytes")
