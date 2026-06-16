import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    j = r.json()
    if isinstance(j, dict) and j.get('ok'):
        return j.get('rows', [])
    return j

# Verify all rules
print("### ALL REVENUE SPLIT RULES ###")
rows = sql("""
  SELECT payment_reason, beneficiary_type, percentage, is_active, description
  FROM app.revenue_split_rules
  ORDER BY payment_reason, beneficiary_type
""")
if isinstance(rows, list):
    current_reason = None
    for r in rows:
        reason = r['payment_reason']
        if reason != current_reason:
            print(f"\n  [{reason}]")
            current_reason = reason
        active = "ACTIVE" if r['is_active'] else "OFF"
        print(f"    {r['beneficiary_type']:15s} {float(r['percentage'])*100:6.1f}%  {active:6s}  {r.get('description','')}")

# Verify totals for active rules
print("\n### ACTIVE RULES TOTALS ###")
rows2 = sql("""
  SELECT payment_reason, 
         ROUND(SUM(percentage)::numeric, 4) AS total_pct,
         COUNT(*) AS cnt
  FROM app.revenue_split_rules 
  WHERE is_active = TRUE
  GROUP BY payment_reason
  ORDER BY payment_reason
""")
if isinstance(rows2, list):
    for r in rows2:
        total = float(r['total_pct'])
        valid = "OK" if abs(total - 1.0) < 0.01 else "INVALID!"
        print(f"  {r['payment_reason']:25s} total={total*100:.1f}%  rules={r['cnt']}  [{valid}]")

# Check if application_fee exists
print("\n### CHECK application_fee rule ###")
rows3 = sql("SELECT * FROM app.revenue_split_rules WHERE payment_reason = 'application_fee'")
if isinstance(rows3, list):
    if rows3:
        for r in rows3:
            print(f"  EXISTS: {r['beneficiary_type']} {float(r['percentage'])*100}% active={r['is_active']}")
    else:
        print("  NOT FOUND - need to insert")
