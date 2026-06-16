import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql_exec(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    return r.json()

# Use DO block to check rules via RAISE NOTICE, or use a known working pattern
# Let's check how admin_execute_sql returns SELECT results — the issue is it only returns affected_rows for DML

# Alternative: use the app_resolve_revenue_split RPC directly for each payment_reason
reasons = ['application_fee', 'registration_fee', 'tuition_deposit', 'td_access', 'online_course', 'subscription', 'credit_purchase']

for reason in reasons:
    r = requests.post(f"{URL}/rest/v1/rpc/app_resolve_revenue_split",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_payment_reason": reason})
    data = r.json()
    print(f"\n[{reason}]")
    if isinstance(data, list):
        total = 0
        for rule in data:
            pct = float(rule.get('percentage', 0)) * 100
            total += float(rule.get('percentage', 0))
            print(f"  {rule.get('beneficiary_type','?'):15s} {pct:6.1f}%  max={rule.get('max_amount','n/a')}  min={rule.get('min_amount','n/a')}")
        ok = "OK" if abs(total - 1.0) < 0.01 else f"INVALID ({total*100:.1f}%)"
        print(f"  TOTAL: {total*100:.1f}% [{ok}]")
    else:
        print(f"  {data}")
