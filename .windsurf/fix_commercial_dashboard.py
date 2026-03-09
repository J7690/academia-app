#!/usr/bin/env python3
"""Fix app_commercial_get_dashboard: column p.name does not exist → find real column name in programs table."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    print(f"\n{'OK' if ok else 'ERR'} {label}")
    if not ok: print(f"  {json.dumps(d, ensure_ascii=False, default=str)[:500]}")
    for row in (rows or [])[:20]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:400]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

# 1. Find ALL tables with 'program' in name
q(m, "Tables with 'program' in name", """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%program%'
ORDER BY table_schema, table_name
""")

# 2. Check app.university_programs (likely the correct table)
q(m, "app.university_programs columns", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='university_programs'
ORDER BY ordinal_position
""")

# 3. Check if applications has program_id and what it references
q(m, "applications columns with 'program'", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='applications'
AND column_name LIKE '%program%'
""")

# 4. Check application_payments columns
q(m, "application_payments columns", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='application_payments'
ORDER BY ordinal_position
""")
