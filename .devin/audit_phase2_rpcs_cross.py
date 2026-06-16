#!/usr/bin/env python3
"""Phase 2 audit — Cross-check Flutter RPCs vs Supabase RPCs."""
import json
from pathlib import Path
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def sql(query):
    resp = requests.post(url, headers=m.headers, json={"p_sql": query.strip()}, timeout=60)
    data = resp.json()
    if isinstance(data, dict):
        return data.get("rows", [])
    return data if isinstance(data, list) else []

# All RPCs called by Flutter (from Phase 2.1 audit)
flutter_rpcs = [
    # Student - Marketplace Listings
    "app_student_list_marketplace_listings",
    "app_marketplace_listing_toggle_bookmark",
    "app_student_get_marketplace_listing_detail",
    "app_student_list_bookmarked_marketplace_listings",
    "app_list_marketplace_categories",
    "app_get_public_merchant_profile",
    # Student - Cart (6 RPCs)
    "app_student_get_cart",
    "app_student_cart_add_item",
    "app_student_cart_update_quantity",
    "app_student_cart_remove_item",
    "app_student_cart_clear",
    "app_student_checkout_create_order_from_cart",
    # Student - Orders
    "app_student_list_my_marketplace_orders",
    "app_student_get_marketplace_order_detail",
    # Student - Inquiries
    "app_student_list_my_opportunity_inquiries",
    "app_student_create_marketplace_listing_inquiry",
    "app_list_opportunity_inquiry_messages",
    "app_student_reply_opportunity_inquiry",
    # Student - Opportunities (code mort mais encore enregistré)
    "app_student_list_opportunities",
    "app_student_list_bookmarked_opportunities",
    "app_opportunity_count_new",
    "app_opportunity_toggle_bookmark",
    "app_opportunity_mark_viewed",
    "app_list_opportunity_types",
    "app_student_list_my_opportunity_applications",
    "app_student_apply_for_opportunity",
    # Student - Social (reactions/comments)
    "app_opportunity_toggle_reaction",
    "app_opportunity_get_my_reaction",
    "app_opportunity_get_reactions",
    "app_opportunity_list_comments",
    "app_opportunity_add_comment",
    "app_opportunity_delete_comment",
    # Merchant
    "app_merchant_list_my_marketplace_listings",
    "app_merchant_upsert_marketplace_listing",
    "app_merchant_submit_marketplace_listing_for_review",
    "app_merchant_list_marketplace_listing_media",
    "app_merchant_add_marketplace_listing_media",
    "app_merchant_disable_marketplace_listing_media",
    "app_merchant_list_my_marketplace_orders",
    "app_merchant_get_marketplace_order_detail",
    "app_merchant_update_marketplace_order_status",
    "app_merchant_list_inquiries",
    "app_merchant_reply_inquiry",
    # Admin - Opportunities (code mort)
    "app_admin_list_opportunities",
    "app_admin_upsert_opportunity",
    "app_admin_list_opportunity_types",
    "app_admin_upsert_opportunity_type",
    "app_admin_update_opportunity_status",
    "app_admin_list_opportunity_applications",
    "app_admin_update_application_status",
    # Admin - Marketplace
    "app_admin_list_marketplace_orders",
    "app_admin_list_published_marketplace_listings",
    "app_admin_list_pending_marketplace_listings",
    "app_admin_review_marketplace_listing",
    "app_admin_list_marketplace_merchants",
    "app_admin_set_merchant_verification",
    "app_admin_update_marketplace_merchant_status",
    "app_admin_list_marketplace_listing_media",
    "app_admin_disable_marketplace_listing_media",
    "app_admin_add_marketplace_listing_media",
]

# Get all existing RPCs from Supabase
rows = sql("""
    SELECT p.proname AS name,
           pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
    ORDER BY p.proname
""")

supabase_rpcs = {}
for r in rows:
    name = r["name"]
    if name not in supabase_rpcs:
        supabase_rpcs[name] = r["args"]
    else:
        supabase_rpcs[name] += " | OVERLOAD: " + r["args"]

# Cross-check
missing = []
exists = []
for rpc in flutter_rpcs:
    if rpc in supabase_rpcs:
        exists.append({"name": rpc, "args": supabase_rpcs[rpc]})
    else:
        missing.append(rpc)

print("=" * 60)
print("CROSS-CHECK: Flutter RPCs vs Supabase")
print("=" * 60)
print("\nEXISTING RPCs (%d):" % len(exists))
for e in exists:
    print("  OK  %-55s args: %s" % (e["name"], e["args"][:80]))

print("\nMISSING RPCs (%d):" % len(missing))
for m_name in missing:
    print("  MISS  %s" % m_name)

# Save
out = Path(__file__).parent / "logs" / "audit_phase2_rpcs_cross.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"existing": exists, "missing": missing, "total_flutter": len(flutter_rpcs), "total_supabase_matched": len(exists)}, f, ensure_ascii=False, indent=2)
print("\nSaved to %s" % out)
