import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

# Use admin RPC to validate splits
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_validate_split_totals", headers=H, json={})
print("### SPLIT VALIDATION ###")
data = r.json()
if isinstance(data, dict) and data.get('success'):
    for v in data.get('validations', []):
        print(f"  {v['payment_reason']:25s} total={float(v['total_percentage'])*100:.1f}%  rules={v['rule_count']}  valid={v['is_valid']}")
else:
    print(f"  {data}")

# Use admin RPC to list rules
print("\n### LIST ALL RULES ###")
r2 = requests.post(f"{URL}/rest/v1/rpc/app_admin_list_revenue_split_rules", headers=H, json={})
data2 = r2.json()
if isinstance(data2, dict) and data2.get('success'):
    rules = data2.get('rules', [])
    current = None
    for rule in rules:
        pr = rule.get('payment_reason', '?')
        if pr != current:
            print(f"\n  [{pr}]")
            current = pr
        active = "ON " if rule.get('is_active') else "OFF"
        pct = float(rule.get('percentage', 0)) * 100
        print(f"    {active} {rule.get('beneficiary_type','?'):15s} {pct:6.1f}%  {rule.get('description','')}")
else:
    print(f"  {data2}")
