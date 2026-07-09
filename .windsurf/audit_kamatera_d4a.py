import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT KAMATERA - PHASE D.4A")
print("=" * 80)

results = {}

# 1. Chercher des tables liées à Kamatera
print("\n1. Tables liées à Kamatera...")
sql = """
SELECT 
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_name LIKE '%kamatera%'
   OR table_name LIKE '%render%'
   OR table_name LIKE '%video%'
ORDER BY table_schema, table_name;
"""

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    results['kamatera_tables'] = tables
    print(f"  Tables trouvées: {len(tables)}")
    for table in tables:
        print(f"    - {table[0]}.{table[1]}")
else:
    results['kamatera_tables'] = []
    print(f"  ❌ Error: {resp.text}")

# 2. Chercher des RPCs liées à Kamatera
print("\n2. RPCs liées à Kamatera...")
sql = """
SELECT 
  routine_schema,
  routine_name,
  routine_type,
  created
FROM information_schema.routines
WHERE routine_name LIKE '%kamatera%'
   OR routine_name LIKE '%render%'
   OR routine_name LIKE '%video%'
ORDER BY routine_schema, routine_name;
"""

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results['kamatera_rpcs'] = rpcs
    print(f"  RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        print(f"    - {rpc[0]}.{rpc[1]} ({rpc[2]}) - Created: {rpc[3]}")
else:
    results['kamatera_rpcs'] = []
    print(f"  ❌ Error: {resp.text}")

# 3. Chercher des Edge Functions liées à Kamatera
print("\n3. Edge Functions liées à Kamatera...")
# Note: On ne peut pas lister les Edge Functions via SQL
# On peut seulement tester si des Edge Functions spécifiques existent
ef_names = ['kamatera-render', 'kamatera-worker', 'render-video', 'video-render']
results['kamatera_edge_functions'] = {}

for ef_name in ef_names:
    ef_url = f"{url}/functions/v1/{ef_name}"
    resp = requests.post(ef_url, headers=headers, json={}, timeout=10)
    if resp.status_code == 401 or resp.status_code == 400:
        results['kamatera_edge_functions'][ef_name] = {'exists': True, 'status': 'exists'}
        print(f"  ✅ Edge Function {ef_name} existe")
    elif resp.status_code == 404:
        results['kamatera_edge_functions'][ef_name] = {'exists': False}
        print(f"  ❌ Edge Function {ef_name} n'existe pas")
    else:
        results['kamatera_edge_functions'][ef_name] = {'exists': True, 'status': 'unknown', 'code': resp.status_code}
        print(f"  ⚠️ Edge Function {ef_name} status: {resp.status_code}")

# Sauvegarder les résultats
with open('audit_kamatera_d4a_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\n" + "=" * 80)
print("RÉSULTATS SAUVEGARDÉS DANS audit_kamatera_d4a_results.json")
print("=" * 80)
