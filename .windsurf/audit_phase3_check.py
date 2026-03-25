#!/usr/bin/env python3
"""Phase 3.2 — Verify listing-based RPCs are ready for Flutter rebranchement."""
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

resp = requests.post(url, headers=m.headers, json={"p_sql": """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'app_listing_toggle_reaction',
        'app_listing_get_reactions',
        'app_student_add_listing_review',
        'app_student_list_listing_reviews',
        'app_merchant_reply_review',
        'app_admin_moderate_review',
        'app_student_get_listing_detail_v2'
      )
    ORDER BY p.proname
"""}, timeout=30)
data = resp.json()
rows = data.get("rows", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
err = data.get("error") if isinstance(data, dict) else None

print("=== LISTING-BASED RPCs READY FOR FLUTTER ===")
if err:
    print("ERROR:", err)
for r in rows:
    print("  OK  %s(%s)" % (r["name"], r["args"][:90]))
print("Total: %d RPCs" % len(rows))

# Also test each RPC via REST to confirm they respond
print("\n=== FUNCTIONAL TESTS ===")
test_rpcs = [
    "app_listing_toggle_reaction",
    "app_listing_get_reactions",
    "app_student_list_listing_reviews",
    "app_student_get_listing_detail_v2",
]
for rpc_name in test_rpcs:
    test_url = f"{m.url}/rest/v1/rpc/{rpc_name}"
    try:
        resp = requests.post(test_url, headers=m.headers, json={"p_listing_id": "00000000-0000-0000-0000-000000000000"}, timeout=10)
        if resp.status_code == 404 or "PGRST202" in resp.text:
            print("  MISS  %s (404/PGRST202)" % rpc_name)
        else:
            print("  OK    %s (HTTP %d)" % (rpc_name, resp.status_code))
    except Exception as e:
        print("  ERR   %s: %s" % (rpc_name, e))
