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

# 1. actor_balances data
print("### 1. ACTOR BALANCES ###")
rows = sql("SELECT * FROM app.actor_balances ORDER BY actor_type, updated_at DESC")
if isinstance(rows, list):
    if rows:
        for r in rows:
            print(f"  type={r.get('actor_type','?'):15s} id={str(r.get('actor_id',''))[:8]}... avail={r.get('available_balance',0):>10} pending={r.get('pending_balance',0):>10} earned={r.get('total_earned',0):>10} withdrawn={r.get('total_withdrawn',0):>10}")
    else:
        print("  (vide)")
else:
    print(f"  {rows}")

# 2. payout_queue data
print("\n### 2. PAYOUT QUEUE ###")
rows2 = sql("SELECT * FROM app.payout_queue ORDER BY created_at DESC LIMIT 15")
if isinstance(rows2, list):
    if rows2:
        for r in rows2:
            print(f"  id={str(r.get('id',''))[:8]}... status={r.get('status','?'):12s} amount={r.get('amount',0):>8} type={r.get('beneficiary_type','?'):15s} phone={r.get('beneficiary_phone','?'):15s} reason={r.get('reason','?')}")
    else:
        print("  (vide)")
else:
    print(f"  {rows2}")

# 3. platform_ledger data
print("\n### 3. PLATFORM LEDGER ###")
rows3 = sql("SELECT * FROM app.platform_ledger ORDER BY created_at DESC LIMIT 10")
if isinstance(rows3, list):
    if rows3:
        for r in rows3:
            print(f"  type={r.get('transaction_type','?'):12s} amount={r.get('amount',0):>8} dir={r.get('direction','?'):6s} counterpart={r.get('counterpart_type','?'):15s} desc={str(r.get('description',''))[:50]}")
    else:
        print("  (vide)")
else:
    print(f"  {rows3}")

# 4. revenue_split_rules data
print("\n### 4. REVENUE SPLIT RULES ###")
rows4 = sql("SELECT * FROM app.revenue_split_rules ORDER BY payment_reason, priority")
if isinstance(rows4, list):
    if rows4:
        for r in rows4:
            print(f"  reason={r.get('payment_reason','?'):25s} beneficiary={r.get('beneficiary_type','?'):15s} pct={r.get('percentage',0):>5}% active={r.get('is_active',False)} desc={str(r.get('description',''))[:40]}")
    else:
        print("  (vide)")
else:
    print(f"  {rows4}")

# 5. Full RPC definitions for key payout RPCs
print("\n### 5. FULL RPC: app_instructor_request_payout ###")
defn = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_instructor_request_payout' LIMIT 1")
if isinstance(defn, list) and defn:
    print(defn[0].get('def', '')[:2000])

print("\n### 6. FULL RPC: app_commercial_request_payout ###")
defn2 = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_commercial_request_payout' LIMIT 1")
if isinstance(defn2, list) and defn2:
    print(defn2[0].get('def', '')[:2000])

print("\n### 7. FULL RPC: app_merchant_request_payout ###")
defn3 = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_merchant_request_payout' LIMIT 1")
if isinstance(defn3, list) and defn3:
    print(defn3[0].get('def', '')[:2000])

# 6. Check ligdicash-callback Edge Function
print("\n### 8. LIGDICASH CALLBACK exists? ###")
import os
cb = r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\functions\ligdicash-callback\index.ts"
if os.path.isfile(cb):
    print(f"  YES - {os.path.getsize(cb)} bytes")
else:
    print("  NOT FOUND")

# 7. LIGDICASH_MODE env var
print("\n### 9. ENVIRONMENT (from Edge Function) ###")
print("  LIGDICASH_MODE is set in Supabase Secrets (mock/live)")
print("  Edge Function: ligdicash-payout uses /pay/v01/withdrawal/create")
print("  Edge Function: ligdicash-callback handles callback from LigdiCash")
