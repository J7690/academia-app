"""Audit partie 6 - première moitié du RPC confirm"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    if r.status_code != 200:
        return f"ERROR {r.status_code}: {r.text[:300]}"
    return r.json()

# Get chars 1-4000 (first half of the RPC)
d = sql("SELECT substring(pg_get_functiondef(p.oid) FROM 1 FOR 4000) AS src FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE p.proname='app_confirm_ligdicash_payment'")
if isinstance(d, list) and len(d) > 0:
    print(d[0].get('src', ''))
