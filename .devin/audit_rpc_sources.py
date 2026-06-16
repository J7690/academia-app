"""Get full RPC sources for game live RPCs."""
import requests
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

for rpc in ['challenge_game_start_live', 'challenge_game_end_live', 'challenge_game_list_live']:
    print(f"\n{'='*70}")
    print(f"RPC: {rpc}")
    print('='*70)
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={
        "sql_query": f"SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = '{rpc}' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public') LIMIT 1"
    })
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list) and data:
            src = data[0].get('pg_get_functiondef', '')
            # Pretty print
            for line in src.split('\n'):
                print(f"  {line}")
        else:
            print(f"  Empty: {data}")
    else:
        print(f"  ❌ {r.status_code}: {r.text[:200]}")

# Also check the livekit_lookup_session to see what it returns for game sessions
print(f"\n{'='*70}")
print("RPC: livekit_lookup_session")
print('='*70)
r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={
    "sql_query": "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'livekit_lookup_session' LIMIT 1"
})
if r.status_code == 200:
    data = r.json()
    if isinstance(data, list) and data:
        src = data[0].get('pg_get_functiondef', '')
        for line in src.split('\n'):
            print(f"  {line}")
