#!/usr/bin/env python3
"""Phase 9.2 — Audit admin RPCs for marketplace vs opportunities."""
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = m.url + "/rest/v1/rpc/admin_execute_sql"

def sql(label, query):
    resp = requests.post(url, headers=m.headers, json={"p_sql": query.strip()}, timeout=60)
    data = resp.json()
    rows = data.get("rows", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
    err = data.get("error") if isinstance(data, dict) else None
    sys.stdout.write("%s %s: %d rows%s\n" % ("OK" if not err else "ERR", label, len(rows), (" - " + str(err)) if err else ""))
    return rows

# 1. Admin marketplace RPCs (kept)
sys.stdout.write("=== 1. Admin MARKETPLACE RPCs (KEPT) ===\n")
rpcs = sql("marketplace rpcs", """
    SELECT p.proname AS name
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'app_admin%%marketplace%%'
    ORDER BY p.proname
""")
for r in rpcs:
    sys.stdout.write("  KEEP  %s\n" % r["name"])

# 2. Admin opportunity RPCs (to deprecate)
sys.stdout.write("\n=== 2. Admin OPPORTUNITY RPCs (DEPRECATED) ===\n")
rpcs2 = sql("opportunity rpcs", """
    SELECT p.proname AS name
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'app_admin%%opportunit%%'
    ORDER BY p.proname
""")
for r in rpcs2:
    sys.stdout.write("  DEPR  %s\n" % r["name"])

# 3. Admin review/moderate RPCs
sys.stdout.write("\n=== 3. Admin review/moderate RPCs ===\n")
rpcs3 = sql("review rpcs", """
    SELECT p.proname AS name
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'app_admin%%review%%'
    ORDER BY p.proname
""")
for r in rpcs3:
    sys.stdout.write("  %s\n" % r["name"])

# 4. Notification domain marker
sys.stdout.write("\n=== 4. Notification domain ===\n")
sys.stdout.write("  admin_opportunities domain used in app_mark_domain_seen\n")
sys.stdout.write("  admin_marketplace domain — need to check if exists\n")
