#!/usr/bin/env python3
"""Get FULL source of app_commercial_get_dashboard in chunks."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

for i, (start, length) in enumerate([(1, 2000), (2001, 2000), (4001, 2000), (6001, 2000)]):
    sql = f"SELECT SUBSTRING(prosrc FROM {start} FOR {length}) AS chunk FROM pg_proc WHERE proname = 'app_commercial_get_dashboard'"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
    d = r.json()
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if rows and rows[0].get('chunk'):
        print(rows[0]['chunk'])
    else:
        break
