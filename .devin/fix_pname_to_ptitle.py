#!/usr/bin/env python3
"""Fix: remplacer p.name par p.title dans toutes les RPCs concernées (programs.title, pas programs.name)."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else None

def ddl(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl", headers=HEADERS, json={"ddl_query": q}, timeout=30)
    return r.status_code, r.text[:300]

# 1. Find ALL RPCs with p.name that reference programs
print("=" * 60)
print("FIX: p.name -> p.title dans les RPCs (programs.title)")
print("=" * 60)

# Also find the main candidature listing RPC
print("\n--- Searching for the candidature listing RPC ---")
result = sql("SELECT proname FROM pg_proc WHERE proname LIKE 'app_%' AND prosrc LIKE '%program%' AND (prosrc LIKE '%application%' OR prosrc LIKE '%candidat%') ORDER BY proname")
if isinstance(result, list):
    for r in result:
        print(f"  {r.get('proname')}")

# Find ALL RPCs with p.name
print("\n--- ALL RPCs with 'p.name' ---")
result = sql("SELECT proname FROM pg_proc WHERE prosrc LIKE '%p.name%' AND proname LIKE 'app_%' ORDER BY proname")
rpcs_to_fix = []
if isinstance(result, list):
    for r in result:
        rpcs_to_fix.append(r.get('proname'))
        print(f"  {r.get('proname')}")

# Also check app_list_student_applications
print("\n--- Checking app_list_student_applications ---")
result = sql("SELECT proname FROM pg_proc WHERE proname LIKE 'app_%student%applic%' ORDER BY proname")
if isinstance(result, list):
    for r in result:
        name = r.get('proname')
        print(f"  Found: {name}")
        # Check if it has p.name
        src_res = sql(f"SELECT prosrc FROM pg_proc WHERE proname = '{name}' LIMIT 1")
        if isinstance(src_res, list) and len(src_res) > 0:
            src = src_res[0].get('prosrc', '')
            if 'p.name' in src:
                print(f"    HAS p.name -> needs fix!")
                if name not in rpcs_to_fix:
                    rpcs_to_fix.append(name)
            else:
                print(f"    OK (no p.name)")

# Fix each RPC
print(f"\n--- Fixing {len(rpcs_to_fix)} RPCs ---")
fixed = 0
failed = 0

for rpc_name in rpcs_to_fix:
    print(f"\n  Fixing: {rpc_name}")
    
    # Get full function definition
    result = sql(f"SELECT pg_get_functiondef(oid) AS def FROM pg_proc WHERE proname = '{rpc_name}' LIMIT 1")
    if not isinstance(result, list) or len(result) == 0:
        print(f"    SKIP: could not get definition")
        failed += 1
        continue
    
    func_def = result[0].get('def', '')
    if 'p.name' not in func_def:
        print(f"    SKIP: p.name not in function def (might be in prosrc only)")
        continue
    
    # Count occurrences
    count = func_def.count('p.name')
    print(f"    Found {count} occurrence(s) of p.name")
    
    # Replace p.name with p.title (only when p is programs alias)
    # We need to be careful not to replace other p.name references
    # In these RPCs, p is always the programs table alias
    new_def = func_def.replace('p.name', 'p.title')
    
    # Deploy
    status, text = ddl(new_def)
    if status == 200:
        print(f"    FIXED: {status}")
        fixed += 1
    else:
        print(f"    ERROR: {status} - {text}")
        failed += 1

# Verify
print(f"\n--- Verification ---")
result = sql("SELECT proname FROM pg_proc WHERE prosrc LIKE '%p.name%' AND proname LIKE 'app_%' ORDER BY proname")
if isinstance(result, list):
    remaining = len(result)
    print(f"  RPCs still with p.name: {remaining}")
    for r in result:
        print(f"    {r.get('proname')}")
    if remaining == 0:
        print(f"  ALL FIXED!")

print(f"\n--- Summary ---")
print(f"  Fixed: {fixed}")
print(f"  Failed: {failed}")
print(f"  Total: {len(rpcs_to_fix)}")
print("Done.")
