#!/usr/bin/env python3
"""Fix app_commercial_get_dashboard: replace p.name with p.title."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"{'YES' if ok else 'NO'} {label}")
    if not ok:
        print(f"  {json.dumps(d, ensure_ascii=False, default=str)[:800]}")
    return ok

m = SupabaseAutoManager()

# Step 1: Get the full source
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
full_src = ""
for start in [1, 2001, 4001, 6001, 8001]:
    r = requests.post(url, headers=m.headers, json={"p_sql": f"SELECT SUBSTRING(prosrc FROM {start} FOR 2000) AS chunk FROM pg_proc WHERE proname = 'app_commercial_get_dashboard'"}, timeout=30)
    d = r.json()
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if rows and rows[0].get('chunk'):
        full_src += rows[0]['chunk']
    else:
        break

print(f"Original source length: {len(full_src)} chars")
print(f"Contains 'p.name': {'p.name' in full_src}")

# Step 2: Fix p.name -> p.title
fixed_src = full_src.replace("p.name AS program_name", "p.title AS program_name")
print(f"Fixed source contains 'p.title AS program_name': {'p.title AS program_name' in fixed_src}")

# Step 3: Rebuild the CREATE OR REPLACE FUNCTION
fix_sql = f"""
CREATE OR REPLACE FUNCTION public.app_commercial_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
{fixed_src}
$function$;
"""

# Step 4: Deploy
ok = run(m, "Deploy fixed app_commercial_get_dashboard", fix_sql)

if ok:
    # Step 5: Test
    print("\nTesting RPC with service role...")
    # Find a commercial user
    r = requests.post(url, headers=m.headers, json={"p_sql": "SELECT user_id FROM app.commercial_profiles WHERE is_active = true LIMIT 1"}, timeout=30)
    d = r.json()
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if rows:
        uid = rows[0]['user_id']
        print(f"  Testing with commercial user: {uid}")
        # We can't call it as that user from here, but at least confirm the function exists
        r2 = requests.post(url, headers=m.headers, json={"p_sql": f"SELECT proname FROM pg_proc WHERE proname = 'app_commercial_get_dashboard'"}, timeout=30)
        d2 = r2.json()
        if d2.get('rows'):
            print("  RPC exists and was updated successfully")
        else:
            print("  WARNING: RPC not found after update")
    print("\nDone! The commercial dashboard should now work.")
