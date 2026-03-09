#!/usr/bin/env python3
"""Debug: test exact format of admin_execute_sql responses."""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager
import requests

manager = SupabaseAutoManager()
url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

# Test 1: simple query
print("=== Test 1: SELECT 1 ===")
r = requests.post(url, headers=manager.headers, json={"p_sql": "SELECT 1 as ok"}, timeout=15)
print(f"Status: {r.status_code}")
print(f"Response: {r.text[:500]}")

# Test 2: list ALL public functions starting with app_
print("\n=== Test 2: List all app_* functions ===")
sql = "SELECT proname FROM pg_proc WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public') AND proname LIKE 'app_%' ORDER BY proname"
r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=15)
print(f"Status: {r.status_code}")
print(f"Response: {r.text[:2000]}")

# Test 3: list all public tables
print("\n=== Test 3: List all public tables ===")
sql2 = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
r2 = requests.post(url, headers=manager.headers, json={"p_sql": sql2}, timeout=15)
print(f"Status: {r2.status_code}")
print(f"Response: {r2.text[:2000]}")
