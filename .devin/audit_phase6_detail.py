#!/usr/bin/env python3
"""Phase 6.2 — Compare old vs new detail RPCs."""
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def sql(label, query):
    resp = requests.post(url, headers=m.headers, json={"p_sql": query.strip()}, timeout=60)
    data = resp.json()
    rows = data.get("rows", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
    err = data.get("error") if isinstance(data, dict) else None
    print("%s %s: %d rows%s" % ("OK" if not err else "ERR", label, len(rows), (" - " + str(err)) if err else ""))
    return rows

# 1. Old RPC signature
print("=== 1. Old RPC: app_student_get_marketplace_listing_detail ===")
old = sql("old rpc", """
    SELECT p.proname, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'app_student_get_marketplace_listing_detail'
""")
for r in old:
    print("  %s(%s)" % (r["proname"], r["args"]))

# 2. New RPC signature
print("\n=== 2. New RPC: app_student_get_listing_detail_v2 ===")
new = sql("new rpc", """
    SELECT p.proname, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'app_student_get_listing_detail_v2'
""")
for r in new:
    print("  %s(%s)" % (r["proname"], r["args"]))

# 3. Old RPC source (first 1500 chars)
print("\n=== 3. Old RPC source (truncated) ===")
src = sql("old src", """
    SELECT pg_get_functiondef(p.oid) AS def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'app_student_get_marketplace_listing_detail'
""")
if src:
    print(src[0].get("def", "")[:1500])

# 4. Test new RPC with a real listing
print("\n=== 4. Test v2 with real listing (via SQL) ===")
rows = sql("real listing", """
    SELECT id FROM app.marketplace_listings WHERE is_active = true AND review_status = 'approved' LIMIT 1
""")
if rows:
    lid = rows[0]["id"]
    # Call v2 via SQL to bypass auth
    test = sql("v2 call", """
        SELECT public.app_student_get_listing_detail_v2('%s'::uuid) AS result
    """ % lid)
    if test:
        import json
        result = test[0].get("result")
        if isinstance(result, str):
            result = json.loads(result)
        if isinstance(result, dict):
            print("  success: %s" % result.get("success"))
            listing = result.get("listing", {})
            if listing:
                print("  listing keys: %s" % sorted(listing.keys()))
            media = result.get("media", [])
            print("  media count: %d" % len(media))
            merchant = result.get("merchant")
            print("  merchant: %s" % ("present" if merchant else "NULL"))
            if merchant:
                print("  merchant keys: %s" % sorted(merchant.keys()))
            reviews = result.get("reviews", [])
            print("  reviews count: %d" % len(reviews))
            print("  my_reaction: %s" % result.get("my_reaction"))
            print("  is_bookmarked: %s" % result.get("is_bookmarked"))
        else:
            print("  raw: %s" % str(result)[:300])
