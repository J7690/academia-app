"""Reset stuck payments - use SET search_path"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={
    "sql_query": "UPDATE app.application_payments SET status = 'pending'::public.payment_status, updated_at = NOW() WHERE status = 'processing'::public.payment_status RETURNING id, amount_due, payment_reason"
}, timeout=30)
print(f"Status: {r.status_code}")
print(json.dumps(r.json(), indent=2, ensure_ascii=False))
