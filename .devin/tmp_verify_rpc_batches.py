#!/usr/bin/env python3
"""Verifier RPC Flutter par lots de 50"""
import json, requests, time
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

with open('flutter_rpc_list.json') as f:
    rpc_list = json.load(f)

flutter_rpc = [r for r in rpc_list if r != 'admin_execute_sql']

all_rows = []
# Process in batches of 50
batch_size = 50
for i in range(0, len(flutter_rpc), batch_size):
    batch = flutter_rpc[i:i+batch_size]
    names = ",".join([f"'{r}'" for r in batch])
    sql = f"""
    WITH rpcs(name) AS (SELECT unnest(ARRAY[{names}]))
    SELECT r.name,
           EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='public' AND routine_name=r.name) as in_public,
           EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='app' AND routine_name=r.name) as in_app
    FROM rpcs r
    ORDER BY r.name
    """
    try:
        r = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql}, timeout=30)
        data = r.json()
        rows = data.get('rows', [])
        all_rows.extend(rows)
        print(f"Batch {i//batch_size + 1}: {len(rows)} rows")
    except Exception as e:
        print(f"Batch {i//batch_size + 1} error: {e}")
    time.sleep(1)

in_public = [r for r in all_rows if r.get('in_public')]
missing_public = [r for r in all_rows if not r.get('in_public')]
in_app_only = [r for r in all_rows if not r.get('in_public') and r.get('in_app')]
completely_missing = [r for r in all_rows if not r.get('in_public') and not r.get('in_app')]

output = {
    'total_checked': len(all_rows),
    'in_public_count': len(in_public),
    'missing_public_count': len(missing_public),
    'in_app_only': [{'name': r['name']} for r in in_app_only],
    'completely_missing': [{'name': r['name']} for r in completely_missing],
}

with open('rpc_verification_batches.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f"Done. Total: {len(all_rows)}, In public: {len(in_public)}, App only: {len(in_app_only)}, Missing: {len(completely_missing)}")
