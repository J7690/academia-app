#!/usr/bin/env python3
"""List all TD RPCs with their parameter signatures."""
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

print("=== ALL TD RPCs with params ===")
rows = sql("""
SELECT r.routine_schema, r.routine_name,
       COALESCE(string_agg(p.parameter_name || ' ' || p.data_type, ', ' ORDER BY p.ordinal_position), '()') as params
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p
  ON p.specific_schema = r.specific_schema
  AND p.specific_name = r.specific_name
  AND p.parameter_mode = 'IN'
WHERE r.routine_name ILIKE 'app_td%'
GROUP BY r.routine_schema, r.routine_name
ORDER BY r.routine_name
""")
for row in rows:
    print(f"  {row.get('routine_name')}({row.get('params','')})")

print("\n=== TD RESOURCES table detail ===")
rows2 = sql("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='td_resources' ORDER BY ordinal_position")
for r in rows2:
    print(f"  {r.get('column_name')} {r.get('data_type')} nullable={r.get('is_nullable')} default={r.get('column_default')}")

print("\n=== TD BADGES table detail ===")
rows3 = sql("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='td_badges' ORDER BY ordinal_position")
for r in rows3:
    print(f"  {r.get('column_name')} {r.get('data_type')} nullable={r.get('is_nullable')} default={r.get('column_default')}")

print("\n=== TD STUDENT_PROGRESS table detail ===")
rows4 = sql("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='td_student_progress' ORDER BY ordinal_position")
for r in rows4:
    print(f"  {r.get('column_name')} {r.get('data_type')} nullable={r.get('is_nullable')} default={r.get('column_default')}")

print("\n=== TD PROGRAMS table detail ===")
rows5 = sql("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='td_programs' ORDER BY ordinal_position")
for r in rows5:
    print(f"  {r.get('column_name')} {r.get('data_type')} nullable={r.get('is_nullable')} default={r.get('column_default')}")

print("\n=== TD FIELDS table detail ===")
rows6 = sql("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='td_fields' ORDER BY ordinal_position")
for r in rows6:
    print(f"  {r.get('column_name')} {r.get('data_type')} nullable={r.get('is_nullable')} default={r.get('column_default')}")

print("\n=== Existing data counts ===")
for tbl in ['td_programs','td_fields','td_enrollments','td_resources','td_badges','td_student_progress','td_teachers','td_messages','td_student_requests']:
    cnt = sql(f"SELECT count(*) as c FROM app.{tbl}")
    n = cnt[0].get('c',0) if cnt else '?'
    print(f"  {tbl}: {n} rows")
