#!/usr/bin/env python3
"""Phase 7.2 — Audit cart/checkout/orders RPCs and data."""
import json
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

# 1. Cart RPCs signatures
print("=== 1. Cart/Checkout RPCs ===")
rpcs = sql("cart rpcs", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'app_student_get_cart',
        'app_student_cart_add_item',
        'app_student_cart_update_quantity',
        'app_student_cart_remove_item',
        'app_student_cart_clear',
        'app_student_checkout_create_order_from_cart',
        'app_student_list_my_marketplace_orders',
        'app_student_get_marketplace_order_detail'
      )
    ORDER BY p.proname
""")
for r in rpcs:
    print("  %s(%s)" % (r["name"], r["args"][:80]))

# 2. Cart tables structure
print("\n=== 2. Cart tables ===")
for t in ["marketplace_carts", "marketplace_cart_items"]:
    cols = sql(t, """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='%s'
        ORDER BY ordinal_position
    """ % t)
    for c in cols:
        print("  %s.%-25s %s null=%s" % (t[:10], c["column_name"], c["data_type"][:20], c["is_nullable"]))

# 3. Order tables structure
print("\n=== 3. Order tables ===")
for t in ["marketplace_orders", "marketplace_order_items"]:
    cols = sql(t, """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='%s'
        ORDER BY ordinal_position
    """ % t)
    for c in cols:
        print("  %s.%-25s %s null=%s" % (t[:10], c["column_name"], c["data_type"][:20], c["is_nullable"]))

# 4. Data counts
print("\n=== 4. Data counts ===")
counts = sql("counts", """
    SELECT
        (SELECT COUNT(*) FROM app.marketplace_carts) AS carts,
        (SELECT COUNT(*) FROM app.marketplace_cart_items) AS cart_items,
        (SELECT COUNT(*) FROM app.marketplace_orders) AS orders,
        (SELECT COUNT(*) FROM app.marketplace_order_items) AS order_items
""")
for r in counts:
    for k, v in sorted(r.items()):
        print("  %s: %s" % (k, v))

# 5. Test get_cart returns what Flutter expects
print("\n=== 5. Functional test: app_student_get_cart ===")
test_url = f"{m.url}/rest/v1/rpc/app_student_get_cart"
resp = requests.post(test_url, headers=m.headers, json={}, timeout=10)
print("  HTTP %d" % resp.status_code)
body = resp.json()
if isinstance(body, dict):
    print("  success=%s" % body.get("success"))
    print("  keys=%s" % sorted(body.keys()) if body.get("success") else "  error=%s" % body.get("error"))

# 6. Check what checkout RPC returns
print("\n=== 6. Checkout RPC source (first 800 chars) ===")
src = sql("checkout src", """
    SELECT pg_get_functiondef(p.oid) AS def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'app_student_checkout_create_order_from_cart'
""")
if src:
    print(src[0].get("def", "")[:800])
