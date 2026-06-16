"""Audit LigdiCash partie 3 - enums + RPC confirm + secrets"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

def sql(query, label):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    print(f"\n--- {label} ---")
    if r.status_code != 200:
        print(f"ERROR {r.status_code}: {r.text[:300]}")
        return
    data = r.json()
    if isinstance(data, list):
        for row in data:
            if 'source' in row:
                print(row['source'][:2000])
            else:
                print(json.dumps(row, ensure_ascii=False))
    elif data is not None:
        print(json.dumps(data, ensure_ascii=False))
    else:
        print("(null)")

# 1
sql("SELECT n.nspname||'.'||t.typname AS t, string_agg(e.enumlabel,', ' ORDER BY e.enumsortorder) AS v FROM pg_enum e JOIN pg_type t ON e.enumtypid=t.oid JOIN pg_namespace n ON t.typnamespace=n.oid WHERE t.typname IN('payment_status','payment_reason','payment_channel') GROUP BY 1 ORDER BY 1", "ENUMS")

# 2
sql("SELECT column_name,data_type,udt_schema,udt_name FROM information_schema.columns WHERE table_schema='app' AND table_name='application_payments' AND column_name IN('status','payment_reason','channel') ORDER BY column_name", "COL TYPES status/reason/channel")

# 3 - RPC confirm source (first 2000 chars)
sql("SELECT pg_get_functiondef(p.oid) AS source FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE p.proname='app_confirm_ligdicash_payment'", "RPC app_confirm_ligdicash_payment")

# 4 - Secrets via vault
sql("SELECT name FROM vault.decrypted_secrets WHERE name LIKE '%LIGDI%' OR name LIKE '%ligdi%' ORDER BY name", "VAULT SECRETS LIGDICASH")

# 5 - Edge functions secrets via Deno env (won't work from SQL, just check vault)
sql("SELECT name, description FROM vault.decrypted_secrets WHERE name IN('LIGDICASH_API_KEY','LIGDICASH_BEARER_TOKEN','LIGDICASH_MODE','LIGDICASH_CALLBACK_URL') ORDER BY name", "VAULT SECRETS DETAILS")
