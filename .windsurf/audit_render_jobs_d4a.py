import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT RENDER JOBS - PHASE D.4A")
print("=" * 80)

results = {}

# 1. Chercher des tables de render jobs
print("\n1. Tables de render jobs...")
sql = """
SELECT 
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_name LIKE '%render%'
   OR table_name LIKE '%job%'
ORDER BY table_schema, table_name;
"""

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    results['render_job_tables'] = tables
    print(f"  Tables trouvées: {len(tables)}")
    for table in tables:
        print(f"    - {table[0]}.{table[1]}")
else:
    results['render_job_tables'] = []
    print(f"  ❌ Error: {resp.text}")

# 2. Si une table existe, lister les 20 derniers jobs
if results.get('render_job_tables'):
    for table in results['render_job_tables']:
        schema = table[0]
        table_name = table[1]
        
        print(f"\n2. 20 derniers jobs dans {schema}.{table_name}...")
        sql = f"""
        SELECT 
          id,
          status,
          created_at,
          completed_at
        FROM {schema}.{table_name}
        ORDER BY created_at DESC
        LIMIT 20;
        """
        
        resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
        print(f"STATUS: {resp.status_code}")
        
        if resp.status_code == 200:
            data = resp.json()
            jobs = data.get('data', [])
            results[f'jobs_{table_name}'] = jobs
            print(f"  Jobs trouvés: {len(jobs)}")
            for job in jobs:
                print(f"    - ID: {job[0]}, Status: {job[1]}, Created: {job[2]}, Completed: {job[3]}")
        else:
            print(f"  ❌ Error: {resp.text}")
else:
    print("\n2. Aucune table de render jobs trouvée, impossible de lister les jobs")

# Sauvegarder les résultats
with open('audit_render_jobs_d4a_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\n" + "=" * 80)
print("RÉSULTATS SAUVEGARDÉS DANS audit_render_jobs_d4a_results.json")
print("=" * 80)
