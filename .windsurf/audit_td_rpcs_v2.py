#!/usr/bin/env python3
"""List all TD RPCs - try broader search."""
from supabase_auto_manager import SupabaseAutoManager
import requests

m = SupabaseAutoManager()

def sql(query):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
                      headers=m.headers, json={"p_sql": query}, timeout=30)
    d = r.json()
    if isinstance(d, dict):
        return d.get("rows", [])
    return d if isinstance(d, list) else []

print("=== ALL routines with 'td' in name ===")
rows = sql("""
SELECT routine_schema, routine_name
FROM information_schema.routines
WHERE routine_name ILIKE '%td%'
   OR routine_name ILIKE '%_td_%'
ORDER BY routine_name
""")
for row in rows:
    print(f"  {row.get('routine_schema')}.{row.get('routine_name')}")

print("\n=== td_resources kind enum values ===")
rows2 = sql("""
SELECT e.enumlabel
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typname = 'td_resource_kind'
ORDER BY e.enumsortorder
""")
for r in rows2:
    print(f"  {r.get('enumlabel')}")

print("\n=== td_programs modality enum ===")
rows3 = sql("""
SELECT e.enumlabel
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typname = 'td_modality'
ORDER BY e.enumsortorder
""")
for r in rows3:
    print(f"  {r.get('enumlabel')}")

print("\n=== td_programs status enum ===")
rows4 = sql("""
SELECT e.enumlabel
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typname = 'td_program_status'
ORDER BY e.enumsortorder
""")
for r in rows4:
    print(f"  {r.get('enumlabel')}")

print("\n=== Existing badges ===")
rows5 = sql("SELECT code, title, emoji, xp_reward, condition_type, condition_value FROM app.td_badges ORDER BY code")
for r in rows5:
    print(f"  {r.get('emoji','')} {r.get('code')}: {r.get('title')} (xp={r.get('xp_reward')}, cond={r.get('condition_type')}={r.get('condition_value')})")

print("\n=== Existing fields ===")
rows6 = sql("SELECT id, name, status FROM app.td_fields ORDER BY name")
for r in rows6:
    print(f"  {r.get('id')}: {r.get('name')} ({r.get('status')})")

print("\n=== Existing programs ===")
rows7 = sql("SELECT id, title, level, modality, price, currency, status FROM app.td_programs ORDER BY title")
for r in rows7:
    print(f"  {r.get('title')} | {r.get('level')} | {r.get('modality')} | {r.get('price')} {r.get('currency')} | {r.get('status')}")
