#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get('rows', []) if isinstance(d, dict) else []
    print(f"\n{label}")
    for row in (rows or [])[:20]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:400]}")
    if not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

q(m, "app.programs ALL columns", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='programs'
ORDER BY ordinal_position
""")

q(m, "app.programs sample (first 3)", """
SELECT * FROM app.programs LIMIT 3
""")
