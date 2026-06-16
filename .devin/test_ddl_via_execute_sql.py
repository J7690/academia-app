#!/usr/bin/env python3
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/execute_sql"

tests = [
    # Test DDL simple
    ("DDL CREATE TABLE test", "CREATE TABLE IF NOT EXISTS app._test_ddl_probe (id int)"),
    # Test via DO block
    ("DDL via DO block", """DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS app._test_ddl_probe2 (id int);
END $$"""),
    # Test execute_sql body via pg_proc
    ("Get execute_sql body",
     "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
     "WHERE n.nspname='public' AND p.proname='execute_sql'"),
]

for label, sql in tests:
    r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=15)
    print(f"[{label}] {r.status_code}: {r.text[:300]}\n")
