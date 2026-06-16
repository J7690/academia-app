"""Audit partie 5 - RPC confirm source complète via length trick"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    if r.status_code != 200:
        return f"ERROR {r.status_code}: {r.text[:300]}"
    return r.json()

# Get full RPC source - split into parts
data = sql("SELECT length(pg_get_functiondef(p.oid)) AS len FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE p.proname='app_confirm_ligdicash_payment'")
if isinstance(data, list) and len(data) > 0:
    total = data[0].get('len', 0)
    print(f"Total length: {total} chars")
    
    # Get in chunks of 3000
    offset = 0
    chunk = 3000
    full_source = ""
    while offset < total:
        d = sql(f"SELECT substring(pg_get_functiondef(p.oid) FROM {offset+1} FOR {chunk}) AS src FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE p.proname='app_confirm_ligdicash_payment'")
        if isinstance(d, list) and len(d) > 0:
            part = d[0].get('src', '')
            full_source += part
            print(part, end='')
        offset += chunk
    
    print(f"\n\n--- Total chars retrieved: {len(full_source)} ---")
else:
    print(f"ERROR: {data}")
