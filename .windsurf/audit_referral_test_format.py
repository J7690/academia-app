"""
Test du format de réponse de admin_execute_sql
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== TEST FORMAT admin_execute_sql ===\n")

# Test 1: SELECT simple
print("Test 1: SELECT simple")
sql = "SELECT 1 as test_col, 'hello' as test_str"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
print()

# Test 2: SELECT depuis pg_class
print("Test 2: SELECT depuis pg_namespace")
sql = """
SELECT nspname 
FROM pg_namespace 
WHERE nspname = 'app';
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
print()

# Test 3: SELECT depuis information_schema
print("Test 3: SELECT depuis information_schema")
sql = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
LIMIT 5;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
print()

# Test 4: Vérifier si le schéma app existe
print("Test 4: Vérifier existence schéma app")
sql = """
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name = 'app';
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
print()

print("=== TEST TERMINÉ ===")
