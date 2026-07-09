"""
Script RPC administrateur pour tester la création de table
Phase B.2 – Test
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

def execute_sql(sql):
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== TEST : CRÉATION TABLE SIMPLE DANS PUBLIC ===\n")

sql = "DROP TABLE IF EXISTS public.test_whiteboard CASCADE"
result = execute_sql(sql)
print(f"DROP: {result}")

sql = "CREATE TABLE public.test_whiteboard (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)"
result = execute_sql(sql)
print(f"CREATE: {result}")

# Vérifier via pg_tables
sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename = 'test_whiteboard'"
result = execute_sql(sql)
print(f"pg_tables: {result}")

# Vérifier via pg_attribute
sql = """
SELECT a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' 
AND c.relname = 'test_whiteboard'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum
"""
result = execute_sql(sql)
print(f"pg_attribute: {result}")

print("\n=== TEST : CRÉATION TABLE SIMPLE DANS APP ===\n")

sql = "DROP TABLE IF EXISTS app.test_whiteboard CASCADE"
result = execute_sql(sql)
print(f"DROP: {result}")

sql = "CREATE TABLE app.test_whiteboard (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)"
result = execute_sql(sql)
print(f"CREATE: {result}")

# Vérifier via pg_tables
sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'app' AND tablename = 'test_whiteboard'"
result = execute_sql(sql)
print(f"pg_tables: {result}")

# Vérifier via pg_attribute
sql = """
SELECT a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'app' 
AND c.relname = 'test_whiteboard'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum
"""
result = execute_sql(sql)
print(f"pg_attribute: {result}")

print("\n=== NETTOYAGE ===\n")

sql = "DROP TABLE IF EXISTS public.test_whiteboard, app.test_whiteboard CASCADE"
result = execute_sql(sql)
print(f"DROP: {result}")
