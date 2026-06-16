"""Call the diagnostic Edge Function and display raw results"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-diagnostic"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

r = requests.post(URL, headers={
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
}, json={}, timeout=60)

print(f"Status: {r.status_code}")
try:
    data = r.json()
    print(json.dumps(data, indent=2, ensure_ascii=False))
except:
    print(f"Raw: {r.text[:2000]}")
