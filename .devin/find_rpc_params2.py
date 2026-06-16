#!/usr/bin/env python3
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/execute_sql"

# Chercher les paramètres via pg_proc
r = requests.post(url, headers=m.headers, json={"sql_query":
    "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
    "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
    "WHERE n.nspname = 'public' "
    "AND p.proname IN ('execute_ddl', 'admin_execute_sql', 'execute_sql') "
    "ORDER BY p.proname"
}, timeout=30)
print("pg_proc params:", r.json())

# Test execute_ddl avec sql_query
r2 = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
    headers=m.headers,
    json={"sql_query": "SELECT 1"},
    timeout=10)
print("execute_ddl sql_query:", r2.status_code, r2.text[:200])

# Test execute_ddl avec sql
r3 = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
    headers=m.headers,
    json={"sql": "SELECT 1"},
    timeout=10)
print("execute_ddl sql:", r3.status_code, r3.text[:200])

# Test admin_execute_sql avec sql
r4 = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
    headers=m.headers,
    json={"sql": "SELECT 1"},
    timeout=10)
print("admin_execute_sql sql:", r4.status_code, r4.text[:200])
