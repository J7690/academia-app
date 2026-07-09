"""
Script RPC administrateur pour déboguer la migration
Phase B.2 – Tables Execution
"""

import requests
import json

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== TEST SIMPLE : CRÉATION TABLE TEST ===\n")

# Test simple : créer une table test
sql = """
CREATE TABLE app.whiteboard_test (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL
)
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)

print("\n=== VÉRIFICATION TABLE TEST ===\n")

sql = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_test'
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("✅ whiteboard_test existe")
else:
    print("❌ whiteboard_test n'existe pas")

print("\n=== SUPPRESSION TABLE TEST ===\n")

sql = "DROP TABLE IF EXISTS app.whiteboard_test"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
