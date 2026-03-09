#!/usr/bin/env python3
"""Get FULL source of app_commercial_get_dashboard to find the p.name bug."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
r = requests.post(url, headers=m.headers, json={"p_sql": """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_commercial_get_dashboard' AND n.nspname IN ('public', 'app')
"""}, timeout=60)
d = r.json()
if d.get('ok') and d.get('rows'):
    src = d['rows'][0]['src']
    print(src)
else:
    print("ERROR:", json.dumps(d, ensure_ascii=False, default=str)[:1000])
