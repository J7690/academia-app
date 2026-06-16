#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
for start in [5001, 6001, 7001, 8001]:
    sql = f"SELECT SUBSTRING(prosrc FROM {start} FOR 2000) AS chunk FROM pg_proc WHERE proname = 'app_commercial_get_dashboard'"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
    d = r.json()
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if rows and rows[0].get('chunk'):
        print(f"\n--- OFFSET {start} ---")
        print(rows[0]['chunk'])
    else:
        break
