#!/usr/bin/env python3
"""Get FULL source of app_commercial_get_dashboard — use raw SELECT."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

# Use a wrapper that returns the source as a row
r = requests.post(url, headers=m.headers, json={"p_sql": """
SELECT prosrc
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_commercial_get_dashboard' AND n.nspname IN ('public', 'app')
LIMIT 1
"""}, timeout=60)
d = r.json()
if d.get('ok') and d.get('rows'):
    print(d['rows'][0].get('prosrc', 'NO prosrc'))
else:
    print("ERROR:", json.dumps(d, ensure_ascii=False, default=str)[:2000])
