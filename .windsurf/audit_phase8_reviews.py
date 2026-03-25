#!/usr/bin/env python3
"""Phase 8.2 — Audit reviews RPCs, table, trigger."""
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

# 1. Reviews RPCs
sys.stdout.write("=== 1. Reviews RPCs ===\n")
rpcs = sql("reviews rpcs", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'app_student_add_listing_review',
        'app_student_list_listing_reviews',
        'app_merchant_reply_review',
        'app_admin_moderate_review'
      )
    ORDER BY p.proname
""")
for r in rpcs:
    sys.stdout.write("  %s(%s)\n" % (r["name"], r["args"][:90]))

# 2. Table structure
sys.stdout.write("\n=== 2. marketplace_reviews columns ===\n")
cols = sql("reviews cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_reviews'
    ORDER BY ordinal_position
""")
for c in cols:
    sys.stdout.write("  %-25s %-25s null=%s default=%s\n" % (c["column_name"], c["data_type"], c["is_nullable"], c.get("column_default", "")))

# 3. Trigger
sys.stdout.write("\n=== 3. Rating trigger ===\n")
trigs = sql("triggers", """
    SELECT trigger_name, event_manipulation, action_timing
    FROM information_schema.triggers
    WHERE trigger_schema = 'app' AND event_object_table = 'marketplace_reviews'
""")
for t in trigs:
    sys.stdout.write("  %s: %s %s\n" % (t["trigger_name"], t["action_timing"], t["event_manipulation"]))

# 4. RLS
sys.stdout.write("\n=== 4. RLS on marketplace_reviews ===\n")
rls = sql("rls", """
    SELECT policyname, cmd, roles
    FROM pg_policies
    WHERE schemaname = 'app' AND tablename = 'marketplace_reviews'
    ORDER BY policyname
""")
for r in rls:
    sys.stdout.write("  %s (%s) roles=%s\n" % (r["policyname"], r["cmd"], r["roles"]))

# 5. Data count
sys.stdout.write("\n=== 5. Reviews data ===\n")
cnt = sql("count", "SELECT COUNT(*) AS c FROM app.marketplace_reviews")
sys.stdout.write("  reviews count: %s\n" % (cnt[0]["c"] if cnt else "?"))

# 6. Test RPCs exist via REST
sys.stdout.write("\n=== 6. Functional test ===\n")
for rpc in ["app_student_add_listing_review", "app_student_list_listing_reviews"]:
    r = requests.post(m.url + "/rest/v1/rpc/" + rpc, headers=m.headers,
                      json={"p_listing_id": "00000000-0000-0000-0000-000000000000"}, timeout=10)
    sys.stdout.write("  %s: HTTP %d\n" % (rpc, r.status_code))
