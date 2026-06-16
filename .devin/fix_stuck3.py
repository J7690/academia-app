import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
h = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

# Use DO block to set search_path
q = "DO $$ BEGIN SET LOCAL search_path TO app, public; UPDATE application_payments SET status = 'pending', updated_at = NOW() WHERE status = 'processing'; END $$"
r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=h, json={"sql_query": q}, timeout=30)
print(f"Update: {r.status_code} {r.text[:300]}")

# Verify
q2 = "SELECT id, status, amount_due, payment_reason FROM app.application_payments WHERE status IN ('pending','processing') ORDER BY created_at DESC LIMIT 10"
r2 = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=h, json={"sql_query": q2}, timeout=30)
print(f"\nVerify:")
for row in r2.json():
    print(json.dumps(row, ensure_ascii=False))
