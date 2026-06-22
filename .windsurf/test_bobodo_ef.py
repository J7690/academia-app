import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/bobodo-chat"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}
payload = {
    "session_id": "a5eea5b6-7477-4035-b332-444d94de3125",
    "message": "Bonjour"
}

resp = requests.post(url, headers=headers, json=payload, timeout=45)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text[:1000]}")

if resp.status_code == 200:
    try:
        data = resp.json()
        print(f"REPLY: {data.get('reply', 'N/A')[:500]}")
    except Exception as e:
        print(f"JSON PARSE ERROR: {e}")
