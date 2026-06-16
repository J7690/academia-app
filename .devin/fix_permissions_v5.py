"""
FIX permissions using admin_execute_sql or execute_ddl RPCs
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

# Step 1: Check signatures of admin_execute_sql and execute_ddl
print("=" * 60)
print("Checking admin_execute_sql and execute_ddl signatures")

for fn in ['admin_execute_sql', 'execute_ddl']:
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": f"""
SELECT p.proname, pg_get_function_arguments(p.oid) as args, 
       pg_get_function_result(p.oid) as return_type,
       p.prosrc as source
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = '{fn}' AND n.nspname = 'public'
"""}
    )
    if r.status_code == 200:
        data = r.json()
        if data:
            for row in data:
                print(f"\n  {fn}:")
                print(f"    args: {row.get('args', '')}")
                print(f"    returns: {row.get('return_type', '')}")
                src = row.get('source', '')[:500]
                print(f"    source: {src}")

# Step 2: Try execute_ddl
print("\n" + "=" * 60)
print("Trying execute_ddl...")

def try_rpc(fn_name, params, label=""):
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/{fn_name}",
        headers=HEADERS,
        json=params
    )
    print(f"    HTTP {r.status_code}: {r.text[:300]}")
    return r.status_code == 200

# Try various param names
for param_name in ['sql_query', 'query', 'ddl', 'statement', 'sql']:
    try_rpc('execute_ddl', {param_name: "GRANT ALL ON app.challenge_game_live_sessions TO service_role"}, f"execute_ddl with param '{param_name}'")

# Step 3: Try admin_execute_sql
print("\n" + "=" * 60)
print("Trying admin_execute_sql...")

for param_name in ['sql_query', 'query', 'sql', 'statement']:
    try_rpc('admin_execute_sql', {param_name: "GRANT ALL ON app.challenge_game_live_sessions TO service_role"}, f"admin_execute_sql with param '{param_name}'")

print("\n🏁 Done.")
