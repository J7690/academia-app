#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

# Direct check via pg_attribute (more reliable than information_schema)
sql = """
SELECT a.attname AS col, pg_catalog.format_type(a.atttypid, a.atttypmod) AS type
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'app' AND c.relname = 'support_messages'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY a.attnum
"""
r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
d = r.json() if r.text else {}
rows = d.get("rows", []) if isinstance(d, dict) else []
print("support_messages columns:")
for row in rows:
    print(f"  {row.get('col')}: {row.get('type')}")
cols = [row.get("col") for row in rows] if isinstance(rows, list) else []
print(f"\ntype: {'✅' if 'type' in cols else '❌'}")
print(f"media_url: {'✅' if 'media_url' in cols else '❌'}")

# Check RPC signatures
sql2 = """
SELECT p.proname, pg_get_function_arguments(p.oid) AS args
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname='public' AND p.proname IN ('app_send_support_message','app_admin_send_support_message')
ORDER BY p.proname
"""
r2 = requests.post(url, headers=m.headers, json={"p_sql": sql2.strip()}, timeout=30)
d2 = r2.json() if r2.text else {}
rows2 = d2.get("rows", []) if isinstance(d2, dict) else []
print("\nRPC signatures:")
for row in rows2:
    print(f"  {row.get('proname')}({row.get('args')})")
