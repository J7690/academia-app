#!/usr/bin/env python3
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/execute_sql"

r = requests.post(url, headers=m.headers, json={"sql_query":
    "SELECT routine_name, parameter_name, data_type "
    "FROM information_schema.parameters "
    "WHERE specific_schema='public' "
    "AND routine_name IN ('execute_ddl','admin_execute_sql','execute_sql') "
    "ORDER BY routine_name, ordinal_position"
}, timeout=30)
print("Params:", r.json())
