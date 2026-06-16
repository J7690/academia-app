"""Audit LigdiCash partie 4 - enums public + fin RPC"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

def sql(query, label):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    print(f"\n--- {label} ---")
    if r.status_code != 200:
        print(f"ERROR {r.status_code}: {r.text[:300]}")
        return None
    data = r.json()
    if isinstance(data, list):
        for row in data:
            if isinstance(row, dict) and 'source' in row:
                print(row['source'])
            else:
                print(json.dumps(row, ensure_ascii=False))
    elif data is not None:
        print(json.dumps(data, ensure_ascii=False))
    else:
        print("(null)")
    return data

# 1. Enum values in PUBLIC schema
sql("SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid=t.oid JOIN pg_namespace n ON t.typnamespace=n.oid WHERE n.nspname='public' AND t.typname='payment_status' ORDER BY e.enumsortorder", "ENUM public.payment_status VALUES")
sql("SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid=t.oid JOIN pg_namespace n ON t.typnamespace=n.oid WHERE n.nspname='public' AND t.typname='payment_reason' ORDER BY e.enumsortorder", "ENUM public.payment_reason VALUES")
sql("SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid=t.oid JOIN pg_namespace n ON t.typnamespace=n.oid WHERE n.nspname='public' AND t.typname='payment_channel' ORDER BY e.enumsortorder", "ENUM public.payment_channel VALUES")

# 2. Check secrets set via supabase CLI (they use edge-runtime, not vault)
sql("SELECT id, name FROM vault.secrets WHERE name LIKE '%LIGDI%' ORDER BY name", "VAULT raw secrets LIGDICASH")

# 3. List all Edge Functions deployed
print("\n--- EDGE FUNCTIONS (check via management API would need separate call) ---")
print("Skipped - use 'supabase functions list' CLI command instead")
