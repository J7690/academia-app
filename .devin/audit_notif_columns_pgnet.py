#!/usr/bin/env python3
"""Check notification_events columns + try to enable pg_net extension."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def sql(m, label, q):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": q.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    if not isinstance(rows, list): rows = []
    print(f"\n-- {label} --")
    if ok:
        for row in rows[:10]:
            print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:300]}")
        if not rows: print("  (0 rows / OK)")
    else:
        print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:400]}")
    return ok, rows

m = SupabaseAutoManager()

# 1. notification_events columns
sql(m, "1. notification_events ALL columns",
    """SELECT column_name, data_type, column_default, is_nullable
       FROM information_schema.columns
       WHERE table_schema='app' AND table_name='notification_events'
       ORDER BY ordinal_position""")

# 2. user_device_tokens columns
sql(m, "2. user_device_tokens ALL columns",
    """SELECT column_name, data_type, column_default
       FROM information_schema.columns
       WHERE table_schema='app' AND table_name='user_device_tokens'
       ORDER BY ordinal_position""")

# 3. Try enabling pg_net extension
ok, _ = sql(m, "3. Try CREATE EXTENSION pg_net",
    """CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions""")
if not ok:
    sql(m, "3b. Try pg_net in public schema",
        """CREATE EXTENSION IF NOT EXISTS pg_net""")

# 4. Verify pg_net
sql(m, "4. Verify pg_net installed",
    """SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_net'""")

# 5. Check available extensions
sql(m, "5. pg_net in available extensions",
    """SELECT name, default_version, installed_version
       FROM pg_available_extensions
       WHERE name = 'pg_net'""")

# 6. Check if supabase_functions schema exists
sql(m, "6. supabase_functions schema exists?",
    """SELECT schema_name FROM information_schema.schemata
       WHERE schema_name = 'supabase_functions'""")

# 7. Try creating database webhook via supabase_functions.hooks
sql(m, "7. supabase_functions.hooks table exists?",
    """SELECT EXISTS(
         SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'supabase_functions' AND table_name = 'hooks'
       ) AS exists""")

print("\n-- DONE --")
