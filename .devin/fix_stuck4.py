import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
h = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json", "Prefer": "return=representation"}

# PATCH via REST API to reset processing payments
ids = ["5ab2a6d0-8b63-4a4e-9865-99359f7be8e9", "b4b8692e-60b6-446d-88d8-53a741a71ba6"]
for pid in ids:
    r = requests.patch(
        f"{URL}/rest/v1/application_payments?id=eq.{pid}",
        headers={**h, "Accept-Profile": "app"},
        json={"status": "pending"}
    )
    print(f"Reset {pid[:8]}...: {r.status_code} {r.text[:200]}")

# Verify
r2 = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers={
    "Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"
}, json={"sql_query": "SELECT id, status FROM app.application_payments WHERE id IN ('5ab2a6d0-8b63-4a4e-9865-99359f7be8e9','b4b8692e-60b6-446d-88d8-53a741a71ba6')"})
print(f"\nVerify: {json.dumps(r2.json(), indent=2)}")
