#!/usr/bin/env python3
"""Test accès aux catalogues PostgreSQL via admin_execute_sql"""
import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"

print("=== TEST 1 : pg_namespace ===")
sql = "SELECT nspname FROM pg_namespace LIMIT 5;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n=== TEST 2 : pg_class ===")
sql = "SELECT relname FROM pg_class LIMIT 5;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n=== TEST 3 : pg_proc ===")
sql = "SELECT proname FROM pg_proc LIMIT 5;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n=== TEST 4 : pg_tables ===")
sql = "SELECT schemaname, tablename FROM pg_tables LIMIT 5;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n=== TEST 5 : information_schema.tables ===")
sql = "SELECT table_schema, table_name FROM information_schema.tables LIMIT 5;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n=== TEST 6 : information_schema.routines ===")
sql = "SELECT routine_schema, routine_name FROM information_schema.routines LIMIT 5;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")
