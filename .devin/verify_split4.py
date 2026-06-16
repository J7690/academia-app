import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    return r.json()

# Wrap in a function that returns JSONB to ensure we get data back
result = sql("""
  SELECT (
    SELECT JSONB_AGG(JSONB_BUILD_OBJECT(
      'pr', payment_reason,
      'bt', beneficiary_type,
      'pct', percentage,
      'on', is_active
    ) ORDER BY payment_reason, beneficiary_type)
    FROM app.revenue_split_rules
  ) as rules
""")
print("### RAW RESULT ###")
print(json.dumps(result, indent=2, ensure_ascii=False)[:3000])

# If rows are there, parse
if isinstance(result, dict) and result.get('ok'):
    rows = result.get('rows', [])
    if rows and rows[0].get('rules'):
        rules = rows[0]['rules']
        if isinstance(rules, str):
            rules = json.loads(rules)
        current = None
        for r in rules:
            pr = r['pr']
            if pr != current:
                print(f"\n[{pr}]")
                current = pr
            active = "ON " if r['on'] else "OFF"
            pct = float(r['pct']) * 100
            print(f"  {active} {r['bt']:15s} {pct:6.1f}%")
        
        # Compute totals for active rules
        print("\n--- TOTALS (active only) ---")
        from collections import defaultdict
        totals = defaultdict(float)
        for r in rules:
            if r['on']:
                totals[r['pr']] += float(r['pct'])
        for pr, total in sorted(totals.items()):
            ok = "OK" if abs(total - 1.0) < 0.01 else f"WARN ({total*100:.1f}%)"
            print(f"  {pr:25s} {total*100:.1f}%  [{ok}]")
