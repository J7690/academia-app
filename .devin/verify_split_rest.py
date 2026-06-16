import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Accept-Profile": "app"}

r = requests.get(f"{URL}/rest/v1/revenue_split_rules?select=payment_reason,beneficiary_type,percentage,is_active,description&order=payment_reason,beneficiary_type", headers=H)
rules = r.json()

if isinstance(rules, list):
    current = None
    for rule in rules:
        pr = rule['payment_reason']
        if pr != current:
            print(f"\n[{pr}]")
            current = pr
        active = "ON " if rule['is_active'] else "OFF"
        pct = float(rule['percentage']) * 100
        print(f"  {active} {rule['beneficiary_type']:15s} {pct:6.1f}%  {rule.get('description','')}")
    
    # Totals active
    print("\n--- TOTALS (active only) ---")
    from collections import defaultdict
    totals = defaultdict(float)
    for rule in rules:
        if rule['is_active']:
            totals[rule['payment_reason']] += float(rule['percentage'])
    for pr, total in sorted(totals.items()):
        ok = "OK" if abs(total - 1.0) < 0.01 else f"INVALID ({total*100:.1f}%)"
        print(f"  {pr:25s} {total*100:.1f}%  [{ok}]")
else:
    print(f"ERROR: {rules}")
