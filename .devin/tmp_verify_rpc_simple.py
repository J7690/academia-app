#!/usr/bin/env python3
"""Verifier RPC Flutter - approche simple: lister toutes les fonctions public/app puis comparer en Python"""
import json, requests
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

with open('flutter_rpc_list.json') as f:
    rpc_list = json.load(f)
flutter_rpc = set(r for r in rpc_list if r != 'admin_execute_sql')

# Get all public functions
r1 = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h,
    json={'p_sql': "SELECT routine_name FROM information_schema.routines WHERE routine_schema='public'"}, timeout=30)
public_funcs = {row['routine_name'] for row in r1.json().get('rows', [])}

# Get all app functions
r2 = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h,
    json={'p_sql': "SELECT routine_name FROM information_schema.routines WHERE routine_schema='app'"}, timeout=30)
app_funcs = {row['routine_name'] for row in r2.json().get('rows', [])}

in_public = sorted(flutter_rpc & public_funcs)
in_app_only = sorted((flutter_rpc & app_funcs) - public_funcs)
completely_missing = sorted(flutter_rpc - public_funcs - app_funcs)

output = {
    'total_flutter_rpc': len(flutter_rpc),
    'in_public_count': len(in_public),
    'in_app_only': in_app_only,
    'completely_missing': completely_missing,
}

with open('rpc_verification_simple.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f"Done. Total: {len(flutter_rpc)}, In public: {len(in_public)}, App only: {len(in_app_only)}, Missing: {len(completely_missing)}")
print(f"App only examples: {in_app_only[:10]}")
print(f"Missing examples: {completely_missing[:10]}")
