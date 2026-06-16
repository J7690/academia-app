import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
h = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json", "Content-Profile": "app", "Prefer": "return=representation"}

# Check current processing payments
r0 = requests.get(f"{URL}/rest/v1/application_payments?status=eq.processing&select=id,amount_due,payment_reason,status",
    headers={**h, "Accept-Profile": "app"})
print(f"Processing payments: {r0.status_code}")
for p in r0.json():
    pid = p['id']
    print(f"  Resetting {pid[:8]}... ({p['amount_due']} {p['payment_reason']})")
    r = requests.patch(f"{URL}/rest/v1/application_payments?id=eq.{pid}",
        headers=h, json={"status": "pending"})
    print(f"    -> {r.status_code}")

# Verify
r2 = requests.get(f"{URL}/rest/v1/application_payments?status=in.(pending,processing)&select=id,status,amount_due&order=created_at.desc&limit=5",
    headers={**h, "Accept-Profile": "app"})
print(f"\nCurrent payments:")
for p in r2.json():
    print(f"  {p['id'][:8]}... status={p['status']} amount={p['amount_due']}")
