#!/usr/bin/env python3
"""Quick audit: list all TD tables and RPCs in Supabase."""
from supabase_auto_manager import SupabaseAutoManager
import requests, json

m = SupabaseAutoManager()

def sql(query):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
                      headers=m.headers, json={"p_sql": query}, timeout=30)
    d = r.json()
    if isinstance(d, dict):
        return d.get("rows", [])
    return d if isinstance(d, list) else []

print("=== TD TABLES ===")
for row in sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'td_%' ORDER BY table_name"):
    print(f"  {row.get('table_name')}")

print("\n=== TD RPCs (public + app) ===")
for row in sql("SELECT routine_schema, routine_name FROM information_schema.routines WHERE routine_name ILIKE 'app_td%' ORDER BY routine_name"):
    print(f"  {row.get('routine_schema')}.{row.get('routine_name')}")

print("\n=== TD TABLE COLUMNS (summary) ===")
cols = sql("SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name LIKE 'td_%' ORDER BY table_name, ordinal_position")
current = None
for c in cols:
    t = c.get("table_name")
    if t != current:
        current = t
        print(f"\n  [{t}]")
    print(f"    {c.get('column_name')} ({c.get('data_type')})")
