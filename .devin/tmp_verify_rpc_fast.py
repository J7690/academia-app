#!/usr/bin/env python3
"""Verifier RPC Flutter en masse via une seule requete SQL"""
import json, requests
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

with open('flutter_rpc_list.json') as f:
    rpc_list = json.load(f)

# Exclude internal admin tool
flutter_rpc = [r for r in rpc_list if r != 'admin_execute_sql']

# Build a single query using array overlap
names = ",".join([f"'{r}'" for r in flutter_rpc])

sql = f"""
WITH flutter_rpc(name) AS (
  SELECT unnest(ARRAY[{names}])
),
public_funcs AS (
  SELECT routine_name FROM information_schema.routines WHERE routine_schema='public'
),
app_funcs AS (
  SELECT routine_name FROM information_schema.routines WHERE routine_schema='app'
)
SELECT
  f.name,
  EXISTS (SELECT 1 FROM public_funcs p WHERE p.routine_name = f.name) as in_public,
  EXISTS (SELECT 1 FROM app_funcs a WHERE a.routine_name = f.name) as in_app
FROM flutter_rpc f
ORDER BY f.name
"""

r = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql}, timeout=60)
data = r.json()
rows = data.get('rows', [])

in_public = [r for r in rows if r.get('in_public')]
missing_public = [r for r in rows if not r.get('in_public')]
in_app_only = [r for r in rows if not r.get('in_public') and r.get('in_app')]
completely_missing = [r for r in rows if not r.get('in_public') and not r.get('in_app')]

output = {
    'total_checked': len(rows),
    'in_public_count': len(in_public),
    'missing_public_count': len(missing_public),
    'in_app_only': [{'name': r['name']} for r in in_app_only],
    'completely_missing': [{'name': r['name']} for r in completely_missing],
}

with open('rpc_verification_fast.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f"Done. In public: {output['in_public_count']}, Missing public: {output['missing_public_count']}, App only: {len(in_app_only)}, Completely missing: {len(completely_missing)}")
