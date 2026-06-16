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

# 1. Full app_resolve_revenue_split
print("### 1. app_resolve_revenue_split ###")
defn = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_resolve_revenue_split' LIMIT 1")
if isinstance(defn, list) and defn:
    print(defn[0].get('def', ''))

# 2. Full app_confirm_ligdicash_payment (part 2 - from offset)
print("\n### 2. app_confirm_ligdicash_payment (FULL) ###")
defn2 = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_confirm_ligdicash_payment' LIMIT 1")
if isinstance(defn2, list) and defn2:
    full = defn2[0].get('def', '')
    # Print in chunks
    chunk = 3000
    for i in range(0, len(full), chunk):
        print(f"\n--- chars {i}-{i+chunk} ---")
        print(full[i:i+chunk])

# 3. app_admin_validate_split_totals
print("\n### 3. app_admin_validate_split_totals ###")
defn3 = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_admin_validate_split_totals' LIMIT 1")
if isinstance(defn3, list) and defn3:
    print(defn3[0].get('def', '')[:2000])
