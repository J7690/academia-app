#!/usr/bin/env python3
"""PHASE 2: Inventaire complet des RPC existants en base"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

# 1. All functions in public
print("Fetching public functions...")
res1 = rpc_sql("SELECT routine_name, data_type as return_type FROM information_schema.routines WHERE routine_schema='public' AND routine_type='FUNCTION' ORDER BY routine_name")

# 2. All functions in app  
print("Fetching app functions...")
res2 = rpc_sql("SELECT routine_name, data_type as return_type FROM information_schema.routines WHERE routine_schema='app' AND routine_type='FUNCTION' ORDER BY routine_name")

# 3. Parameters for all public functions (get as text)
print("Fetching public parameters...")
res3 = rpc_sql("""
SELECT p.routine_name,
       p.parameter_name,
       p.data_type,
       p.parameter_mode,
       p.ordinal_position
FROM information_schema.parameters p
JOIN information_schema.routines r ON r.specific_name = p.specific_name
WHERE r.routine_schema = 'public' AND r.routine_type = 'FUNCTION'
ORDER BY p.routine_name, p.ordinal_position
""")

# 4. Parameters for all app functions
print("Fetching app parameters...")
res4 = rpc_sql("""
SELECT p.routine_name,
       p.parameter_name,
       p.data_type,
       p.parameter_mode,
       p.ordinal_position
FROM information_schema.parameters p
JOIN information_schema.routines r ON r.specific_name = p.specific_name
WHERE r.routine_schema = 'app' AND r.routine_type = 'FUNCTION'
ORDER BY p.routine_name, p.ordinal_position
""")

# 5. Grants for public functions
print("Fetching public grants...")
res5 = rpc_sql("""
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
ORDER BY routine_name
""")

# 6. Grants for app functions
print("Fetching app grants...")
res6 = rpc_sql("""
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'app'
ORDER BY routine_name
""")

output = {
    'public_functions': res1,
    'app_functions': res2,
    'public_parameters': res3,
    'app_parameters': res4,
    'public_grants': res5,
    'app_grants': res6,
}

with open('audit_inventory_base.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)
print("OK")
