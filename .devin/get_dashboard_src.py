#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
# Use REST API directly to query pg_proc
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
sql = "SELECT LEFT(prosrc, 2000) AS part1 FROM pg_proc WHERE proname = 'app_commercial_get_dashboard'"
r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=60)
d = r.json()
rows = d.get('rows', []) if isinstance(d, dict) else []
if rows:
    print(rows[0].get('part1', 'EMPTY'))
elif d.get('ok'):
    # Try different approach - the admin_execute_sql might wrap SELECT
    print("No rows returned, trying alternative...")
    sql2 = """
    DO $do$
    DECLARE v_src TEXT;
    BEGIN
      SELECT prosrc INTO v_src FROM pg_proc WHERE proname = 'app_commercial_get_dashboard' LIMIT 1;
      RAISE NOTICE '%', LEFT(v_src, 3000);
    END;
    $do$
    """
    r2 = requests.post(url, headers=m.headers, json={"p_sql": sql2}, timeout=60)
    print(json.dumps(r2.json(), ensure_ascii=False, default=str)[:3000])
else:
    print(json.dumps(d, ensure_ascii=False, default=str)[:3000])
