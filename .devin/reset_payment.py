import requests, json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

# Reset le paiement bloque pour re-test
r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
    headers=HEADERS,
    json={"sql_query": "SELECT id, status FROM app.application_payments WHERE id = 'ab8dc18d-2367-40a8-a7e3-4fe5a6f38f99'"},
    timeout=15,
)
print(f"Status: {r.status_code}")
print(f"Response: {r.text[:300]}")
