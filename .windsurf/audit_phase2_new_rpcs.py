#!/usr/bin/env python3
"""Phase 2 audit — Check which NEW RPCs we need to create."""
import json
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

# 1. Check if review RPCs exist
print("=== 1. Review RPCs ===")
review_rpcs = sql("review rpcs", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname ILIKE '%%review%%'
    ORDER BY p.proname
""")
for r in review_rpcs:
    print("  %s(%s)" % (r["name"], r["args"][:80]))

# 2. Check if listing-based social RPCs exist
print("\n=== 2. Listing-based social RPCs ===")
listing_rpcs = sql("listing social rpcs", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.proname ILIKE '%%listing_toggle_reaction%%'
        OR p.proname ILIKE '%%listing_get_reaction%%'
        OR p.proname ILIKE '%%listing_add_comment%%'
        OR p.proname ILIKE '%%listing_list_comment%%'
        OR p.proname ILIKE '%%listing_delete_comment%%'
        OR p.proname ILIKE '%%listing_detail_v2%%')
    ORDER BY p.proname
""")
for r in listing_rpcs:
    print("  %s(%s)" % (r["name"], r["args"][:80]))

# 3. Test cart RPCs to see if they actually work
print("\n=== 3. Test cart RPCs (call with no auth, expect error but not 404) ===")
for rpc_name in ["app_student_get_cart", "app_student_cart_clear"]:
    test_url = "%s/rest/v1/rpc/%s" % (m.url, rpc_name)
    try:
        resp = requests.post(test_url, headers=m.headers, json={}, timeout=10)
        body = resp.text[:200]
        if resp.status_code == 404 or "PGRST202" in body:
            print("  %s: MISSING (404/PGRST202)" % rpc_name)
        elif resp.status_code >= 400:
            print("  %s: EXISTS but error %d" % (rpc_name, resp.status_code))
        else:
            print("  %s: OK %d" % (rpc_name, resp.status_code))
    except Exception as e:
        print("  %s: EXCEPTION %s" % (rpc_name, e))

# 4. Test set_merchant_verification
print("\n=== 4. Test admin_set_merchant_verification ===")
test_url = "%s/rest/v1/rpc/app_admin_set_merchant_verification" % m.url
resp = requests.post(test_url, headers=m.headers, json={
    "p_merchant_id": "00000000-0000-0000-0000-000000000000",
    "p_is_verified": True,
}, timeout=10)
print("  Status: %d" % resp.status_code)
print("  Body: %s" % resp.text[:200])

# 5. Check cart RPC source to see what tables they use
print("\n=== 5. Cart RPC definitions ===")
cart_defs = sql("cart defs", """
    SELECT p.proname AS name, pg_get_functiondef(p.oid) AS def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('app_student_get_cart','app_student_cart_add_item',
                        'app_student_cart_update_quantity','app_student_cart_remove_item',
                        'app_student_cart_clear','app_student_checkout_create_order_from_cart')
    ORDER BY p.proname
""")
for r in cart_defs:
    defn = r["def"][:300] if r.get("def") else "N/A"
    print("  --- %s ---" % r["name"])
    print("  %s..." % defn)
