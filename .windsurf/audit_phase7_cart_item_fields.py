#!/usr/bin/env python3
"""Check what fields the cart RPC returns per item."""
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = m.url + "/rest/v1/rpc/admin_execute_sql"

query = "SELECT pg_get_functiondef(p.oid) AS def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'app_student_get_cart'"

resp = requests.post(url, headers=m.headers, json={"p_sql": query}, timeout=60)
data = resp.json()

if isinstance(data, dict) and data.get("rows"):
    defn = data["rows"][0].get("def", "")
    sys.stdout.write(defn[:3000] + "\n")
    if len(defn) > 3000:
        sys.stdout.write("... [truncated, total %d chars]\n" % len(defn))
elif isinstance(data, dict) and data.get("error"):
    sys.stdout.write("ERROR: %s\n" % data["error"])
else:
    sys.stdout.write("Unexpected: %s\n" % str(data)[:300])
