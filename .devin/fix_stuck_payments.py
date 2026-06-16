"""Reset stuck payments back to pending so user can retry"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

def sql(query, label):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    print(f"\n--- {label} ---")
    if r.status_code != 200:
        print(f"ERROR {r.status_code}: {r.text[:300]}")
        return
    data = r.json()
    if isinstance(data, list):
        for row in data:
            print(json.dumps(row, ensure_ascii=False))
    else:
        print(data)

# Reset stuck 'processing' payments back to 'pending'
sql("""
UPDATE app.application_payments 
SET status = 'pending', updated_at = NOW()
WHERE status = 'processing'
RETURNING id, amount_due, payment_reason, status
""", "RESET processing to pending")

# Verify
sql("""
SELECT id, status, amount_due, payment_reason 
FROM app.application_payments 
WHERE status IN ('pending','processing')
ORDER BY created_at DESC LIMIT 10
""", "Current pending/processing payments")
