import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

# Create a temp function to dump rules as JSON
result = rpc("admin_execute_sql", {"p_sql": """
CREATE OR REPLACE FUNCTION public._tmp_dump_split_rules() RETURNS JSONB LANGUAGE sql SECURITY DEFINER AS $$
  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT(
    'pr', r.payment_reason, 'bt', r.beneficiary_type, 'pct', r.percentage, 'active', r.is_active, 'desc', r.description
  ) ORDER BY r.payment_reason, r.beneficiary_type), '[]'::JSONB)
  FROM app.revenue_split_rules r;
$$;
"""})
print("Create temp function:", result)

# Call it
data = rpc("_tmp_dump_split_rules")
print("\n### ALL REVENUE SPLIT RULES ###")
if isinstance(data, list):
    from collections import defaultdict
    current = None
    totals_active = defaultdict(float)
    for r in data:
        pr = r['pr']
        if pr != current:
            print(f"\n[{pr}]")
            current = pr
        active = "ON " if r['active'] else "OFF"
        pct = float(r['pct']) * 100
        print(f"  {active} {r['bt']:15s} {pct:6.1f}%  {r.get('desc','')}")
        if r['active']:
            totals_active[pr] += float(r['pct'])
    
    print("\n--- TOTALS (active only) ---")
    for pr, total in sorted(totals_active.items()):
        ok = "OK" if abs(total - 1.0) < 0.01 else f"INVALID ({total*100:.1f}%)"
        print(f"  {pr:25s} {total*100:.1f}%  [{ok}]")
elif isinstance(data, dict):
    print(json.dumps(data, indent=2, ensure_ascii=False))

# Drop temp function
rpc("admin_execute_sql", {"p_sql": "DROP FUNCTION IF EXISTS public._tmp_dump_split_rules();"})
