import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    return r.json()

# Full dump
result = sql("""
  SELECT payment_reason, beneficiary_type, percentage, is_active
  FROM app.revenue_split_rules
  ORDER BY payment_reason, beneficiary_type
""")
if isinstance(result, dict) and result.get('ok'):
    rows = result.get('rows', [])
    current = None
    for r in rows:
        pr = r['payment_reason']
        if pr != current:
            print(f"\n[{pr}]")
            current = pr
        active = "ON " if r['is_active'] else "OFF"
        pct = float(r['percentage']) * 100
        print(f"  {active} {r['beneficiary_type']:15s} {pct:6.1f}%")

# Totals
print("\n--- TOTALS (active only) ---")
result2 = sql("""
  SELECT payment_reason, SUM(percentage) as total
  FROM app.revenue_split_rules WHERE is_active = TRUE
  GROUP BY payment_reason ORDER BY payment_reason
""")
if isinstance(result2, dict) and result2.get('ok'):
    for r in result2.get('rows', []):
        t = float(r['total']) * 100
        ok = "OK" if abs(t - 100) < 1 else "WARN"
        print(f"  {r['payment_reason']:25s} {t:6.1f}% [{ok}]")
