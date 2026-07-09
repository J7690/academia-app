import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT RPCS - PHASE D.4A")
print("=" * 80)

results = {}

# 1. Lister toutes les RPCs contenant "whiteboard"
print("\n1. RPCs contenant 'whiteboard'...")
sql = """
SELECT 
  routine_schema,
  routine_name,
  routine_type,
  created
FROM information_schema.routines
WHERE routine_name LIKE '%whiteboard%'
ORDER BY routine_schema, routine_name;
"""

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results['whiteboard_rpcs'] = rpcs
    print(f"  RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        print(f"    - {rpc[0]}.{rpc[1]} ({rpc[2]}) - Created: {rpc[3]}")
else:
    results['whiteboard_rpcs'] = []
    print(f"  ❌ Error: {resp.text}")

# 2. Lister toutes les RPCs contenant "storyboard"
print("\n2. RPCs contenant 'storyboard'...")
sql = """
SELECT 
  routine_schema,
  routine_name,
  routine_type,
  created
FROM information_schema.routines
WHERE routine_name LIKE '%storyboard%'
ORDER BY routine_schema, routine_name;
"""

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results['storyboard_rpcs'] = rpcs
    print(f"  RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        print(f"    - {rpc[0]}.{rpc[1]} ({rpc[2]}) - Created: {rpc[3]}")
else:
    results['storyboard_rpcs'] = []
    print(f"  ❌ Error: {resp.text}")

# 3. Lister toutes les RPCs du schéma 'app'
print("\n3. Toutes les RPCs du schéma 'app'...")
sql = """
SELECT 
  routine_schema,
  routine_name,
  routine_type,
  created
FROM information_schema.routines
WHERE routine_schema = 'app'
ORDER BY routine_name;
"""

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results['app_rpcs'] = rpcs
    print(f"  RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        print(f"    - {rpc[1]} ({rpc[2]}) - Created: {rpc[3]}")
else:
    results['app_rpcs'] = []
    print(f"  ❌ Error: {resp.text}")

# Sauvegarder les résultats
with open('audit_rpcs_d4a_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\n" + "=" * 80)
print("RÉSULTATS SAUVEGARDÉS DANS audit_rpcs_d4a_results.json")
print("=" * 80)
