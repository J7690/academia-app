#!/usr/bin/env python3
"""Phase 10.2 — Audit merchant RPCs."""
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

sys.stdout.write("=== 1. All Merchant RPCs ===\n")
rpcs = sql("merchant rpcs", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname LIKE 'app_merchant%%'
    ORDER BY p.proname
""")
for r in rpcs:
    sys.stdout.write("  %s(%s)\n" % (r["name"], r["args"][:70]))

sys.stdout.write("\n=== 2. Check app_merchant_reply_review exists ===\n")
review_rpc = sql("reply review", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'app_merchant_reply_review'
""")
for r in review_rpc:
    sys.stdout.write("  %s(%s)\n" % (r["name"], r["args"]))

sys.stdout.write("\n=== 3. Reviews awaiting merchant reply ===\n")
pending = sql("pending reviews", """
    SELECT COUNT(*) AS cnt FROM app.marketplace_reviews
    WHERE seller_reply IS NULL AND is_active = true
""")
for r in pending:
    sys.stdout.write("  pending replies: %s\n" % r["cnt"])
