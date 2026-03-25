#!/usr/bin/env python3
"""Verify Phase 2 RPCs were created correctly."""
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def sql(label, query):
    resp = requests.post(url, headers=m.headers, json={"p_sql": query.strip()}, timeout=60)
    data = resp.json()
    rows = data.get("rows", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
    ok = data.get("ok", True) if isinstance(data, dict) else True
    err = data.get("error") if isinstance(data, dict) else None
    print("%s %s: %d rows%s" % ("OK" if ok else "ERR", label, len(rows), (" - " + str(err)) if err else ""))
    return rows

# 1. Check new RPCs exist
print("=== 1. New RPCs created ===")
new_rpcs = sql("new rpcs", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'app_student_add_listing_review',
        'app_student_list_listing_reviews',
        'app_merchant_reply_review',
        'app_admin_moderate_review',
        'app_listing_toggle_reaction',
        'app_listing_get_reactions',
        'app_student_get_listing_detail_v2',
        'app_trigger_update_listing_rating'
      )
    ORDER BY p.proname
""")
for r in new_rpcs:
    print("  %s(%s)" % (r["name"], r["args"][:80]))

# 2. Check trigger exists
print("\n=== 2. Trigger on marketplace_reviews ===")
triggers = sql("triggers", """
    SELECT trigger_name, event_manipulation, action_timing
    FROM information_schema.triggers
    WHERE trigger_schema = 'app'
      AND event_object_table = 'marketplace_reviews'
""")
for r in triggers:
    print("  %s: %s %s" % (r["trigger_name"], r["action_timing"], r["event_manipulation"]))

# 3. Test RPCs via REST (should return error but not 404)
print("\n=== 3. Functional test RPCs ===")
test_rpcs = [
    ("app_student_add_listing_review", {"p_listing_id": "00000000-0000-0000-0000-000000000000"}),
    ("app_student_list_listing_reviews", {"p_listing_id": "00000000-0000-0000-0000-000000000000"}),
    ("app_listing_toggle_reaction", {"p_listing_id": "00000000-0000-0000-0000-000000000000"}),
    ("app_listing_get_reactions", {"p_listing_id": "00000000-0000-0000-0000-000000000000"}),
    ("app_student_get_listing_detail_v2", {"p_listing_id": "00000000-0000-0000-0000-000000000000"}),
]
for rpc_name, params in test_rpcs:
    test_url = "%s/rest/v1/rpc/%s" % (m.url, rpc_name)
    resp = requests.post(test_url, headers=m.headers, json=params, timeout=10)
    body = resp.text[:150]
    if resp.status_code == 404 or "PGRST202" in body:
        print("  MISS %s (404)" % rpc_name)
    else:
        print("  OK   %s (HTTP %d)" % (rpc_name, resp.status_code))

# 4. Test detail_v2 with real listing
print("\n=== 4. Test detail_v2 with real listing ===")
listings = sql("real listings", """
    SELECT id, title FROM app.marketplace_listings
    WHERE is_active = true AND review_status = 'approved'
    LIMIT 1
""")
if listings:
    lid = listings[0]["id"]
    print("  Testing with listing: %s" % listings[0]["title"])
    test_url = "%s/rest/v1/rpc/app_student_get_listing_detail_v2" % m.url
    resp = requests.post(test_url, headers=m.headers, json={"p_listing_id": lid}, timeout=10)
    data = resp.json()
    if isinstance(data, dict) and data.get("success"):
        listing = data.get("listing", {})
        media = data.get("media", [])
        merchant = data.get("merchant", {})
        reviews = data.get("reviews", [])
        print("  Listing: %s" % listing.get("title", "N/A"))
        print("  Media count: %d" % len(media))
        print("  Merchant: %s (verified=%s)" % (merchant.get("name", "N/A"), merchant.get("is_verified")))
        print("  Reviews count: %d" % len(reviews))
        print("  Rating: %s (%s reviews)" % (listing.get("rating_avg"), listing.get("rating_count")))
    else:
        print("  Response: %s" % str(data)[:200])

print("\n=== VERIFICATION COMPLETE ===")
