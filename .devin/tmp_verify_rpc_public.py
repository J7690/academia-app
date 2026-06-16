#!/usr/bin/env python3
"""Verifier quels RPC Flutter existent dans public vs app"""
import json, requests, time
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

with open('flutter_rpc_list.json') as f:
    rpc_list = json.load(f)

# Exclude admin_execute_sql (internal) and edge function calls
flutter_rpc = [r for r in rpc_list if r not in ('admin_execute_sql',)]

def check_rpc(name):
    try:
        # Check public
        sql_pub = f"SELECT routine_name FROM information_schema.routines WHERE routine_schema='public' AND routine_name='{name}'"
        r = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql_pub}, timeout=15)
        pub_rows = r.json().get('rows', [])
        # Check app
        sql_app = f"SELECT routine_name FROM information_schema.routines WHERE routine_schema='app' AND routine_name='{name}'"
        r2 = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql_app}, timeout=15)
        app_rows = r2.json().get('rows', [])
        return {'name': name, 'public': len(pub_rows)>0, 'app': len(app_rows)>0}
    except Exception as e:
        return {'name': name, 'error': str(e)}

results = []
# Process in batches of 5 to avoid overwhelming connection
for i in range(0, len(flutter_rpc), 5):
    batch = flutter_rpc[i:i+5]
    for name in batch:
        res = check_rpc(name)
        results.append(res)
        time.sleep(0.5)
    time.sleep(1)

missing_public = [r for r in results if not r.get('public') and not r.get('error')]
in_app_only = [r for r in results if not r.get('public') and r.get('app') and not r.get('error')]
completely_missing = [r for r in results if not r.get('public') and not r.get('app') and not r.get('error')]
errors = [r for r in results if r.get('error')]

output = {
    'total_checked': len(results),
    'in_public': len([r for r in results if r.get('public')]),
    'missing_public': len(missing_public),
    'in_app_only': [{'name': r['name']} for r in in_app_only],
    'completely_missing': [{'name': r['name']} for r in completely_missing],
    'errors': errors[:5]
}

with open('rpc_verification_results.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)
print(f"Done. In public: {output['in_public']}, Missing public: {output['missing_public']}, App only: {len(in_app_only)}, Completely missing: {len(completely_missing)}")
