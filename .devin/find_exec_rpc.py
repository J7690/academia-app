#!/usr/bin/env python3
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/execute_sql"

# Chercher toutes les RPCs qui font de l'exécution SQL
r = requests.post(url, headers=m.headers, json={"sql_query":
    "SELECT routine_schema, routine_name FROM information_schema.routines "
    "WHERE routine_name ILIKE '%execute%' OR routine_name ILIKE '%exec_sql%' "
    "OR routine_name ILIKE '%run_sql%' OR routine_name ILIKE '%admin_sql%' "
    "ORDER BY routine_schema, routine_name"
}, timeout=30)
print("RPCs exec:", r.json())

# Aussi chercher execute_sql dans tous les schémas
r2 = requests.post(url, headers=m.headers, json={"sql_query":
    "SELECT routine_schema, routine_name, routine_type "
    "FROM information_schema.routines "
    "WHERE routine_name = 'execute_sql' OR routine_name = 'admin_execute_sql' "
    "ORDER BY routine_schema"
}, timeout=30)
print("execute_sql RPCs:", r2.json())
