#!/usr/bin/env python3
import json, requests
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
r = requests.post(url, headers=m.headers, json={"p_sql": """
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='programs' ORDER BY ordinal_position
"""}, timeout=30)
d = r.json()
for row in d.get('rows', []):
    print(f"  {row['column_name']} ({row['data_type']})")
