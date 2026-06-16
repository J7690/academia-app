#!/usr/bin/env python3
"""Audit: trouver 'p.name' dans les RPCs liées aux candidatures/programmes."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:300]}

# 1. Find all RPCs that contain 'p.name'
print("=== RPCs containing 'p.name' ===")
result = sql("SELECT proname FROM pg_proc WHERE prosrc LIKE '%p.name%' AND proname LIKE 'app_%' ORDER BY proname")
if isinstance(result, list):
    for r in result:
        print(f"  {r.get('proname')}")
    print(f"  Total: {len(result)} RPCs")
else:
    print(f"  Error: {result}")

# 2. Check actual columns of programs table
print("\n=== Columns of app.programs ===")
result = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='programs' ORDER BY ordinal_position")
if isinstance(result, list):
    cols = [r.get('column_name') for r in result]
    print(f"  {cols}")
    has_name = 'name' in cols
    has_title = 'title' in cols
    print(f"  Has 'name': {has_name}")
    print(f"  Has 'title': {has_title}")
else:
    print(f"  Error: {result}")

# 3. Find RPCs related to candidature/application that use programs
print("\n=== RPCs candidature + programmes ===")
result = sql("""
    SELECT proname FROM pg_proc 
    WHERE proname LIKE 'app_%' 
    AND (prosrc LIKE '%application%' OR prosrc LIKE '%candidat%')
    AND prosrc LIKE '%program%'
    AND prosrc LIKE '%p.name%'
    ORDER BY proname
""")
if isinstance(result, list):
    print(f"  RPCs with p.name + application + program:")
    for r in result:
        print(f"    - {r.get('proname')}")
    if not result:
        print(f"    (none found)")

# 4. Also check RPCs called during student application listing
print("\n=== RPCs student list applications ===")
for rpc_name in [
    "app_student_list_applications",
    "app_student_list_my_applications",
    "app_student_get_application_detail",
    "app_student_apply_to_program",
    "app_student_list_programs",
    "app_list_programs",
    "app_student_list_university_programs",
]:
    result = sql(f"SELECT prosrc FROM pg_proc WHERE proname = '{rpc_name}' LIMIT 1")
    if isinstance(result, list) and len(result) > 0:
        src = result[0].get('prosrc', '')
        has_pname = 'p.name' in src
        print(f"  {'!!!' if has_pname else '   '} {rpc_name}: {'CONTAINS p.name' if has_pname else 'ok'} ({len(src)} chars)")
    else:
        print(f"     {rpc_name}: not found")

# 5. Check Flutter side - which RPC is called for candidature screen
print("\n=== Flutter candidature flow ===")
print("  student_application_detail_screen.dart uses:")
print("    - StudentApplicationsProvider.loadApplications()")
print("    - app_student_list_my_applications or similar")

print("\nDone.")
