import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

headers = {
    "Authorization": f"Bearer {SERVICE_KEY}",
    "apikey": SERVICE_KEY,
    "Content-Type": "application/json",
}

sql = """
SELECT e.enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
JOIN pg_namespace n ON t.typnamespace = n.oid 
WHERE n.nspname = 'app' AND t.typname = 'payment_reason' 
ORDER BY e.enumsortorder
"""

r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": sql}, timeout=10)
print(f"Status: {r.status_code}")
print(f"Response: {r.text[:500]}")
