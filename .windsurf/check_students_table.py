#!/usr/bin/env python3
import requests, json
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
q = "SELECT table_schema, table_name FROM information_schema.tables WHERE table_name='students' ORDER BY table_schema"
r = requests.post(url, headers=m.headers, json={"p_sql": q}, timeout=30)
print(r.status_code)
print(json.dumps(r.json(), indent=2, ensure_ascii=False))
