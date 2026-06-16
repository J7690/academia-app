#!/usr/bin/env python3
"""Phase 1 audit — Complete Supabase state for marketplace refonte."""
import json
from pathlib import Path
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def sql(label, query):
    resp = requests.post(url, headers=m.headers, json={"p_sql": query.strip()}, timeout=60)
    data = resp.json()
    rows = data.get("rows", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
    ok = data.get("ok", resp.status_code == 200) if isinstance(data, dict) else True
    err = data.get("error") if isinstance(data, dict) else None
    print(f"  {'OK' if ok else 'ERR'} {label}: {len(rows)} rows" + (f" — {err}" if err else ""))
    return {"ok": ok, "rows": rows, "error": err}

results = {}

# 1. marketplace_listings columns
print("=== MARKETPLACE_LISTINGS ===")
results["ml_cols"] = sql("marketplace_listings cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_listings'
    ORDER BY ordinal_position
""")

# 2. marketplace_merchants columns
print("=== MARKETPLACE_MERCHANTS ===")
results["mm_cols"] = sql("marketplace_merchants cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_merchants'
    ORDER BY ordinal_position
""")

# 3. merchant_profiles columns
print("=== MERCHANT_PROFILES ===")
results["mp_cols"] = sql("merchant_profiles cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='merchant_profiles'
    ORDER BY ordinal_position
""")

# 4. marketplace_listing_media columns
print("=== MARKETPLACE_LISTING_MEDIA ===")
results["mlm_cols"] = sql("marketplace_listing_media cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_listing_media'
    ORDER BY ordinal_position
""")

# 5. marketplace_categories columns
print("=== MARKETPLACE_CATEGORIES ===")
results["mc_cols"] = sql("marketplace_categories cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_categories'
    ORDER BY ordinal_position
""")

# 6. marketplace_carts + cart_items columns
print("=== MARKETPLACE_CARTS ===")
results["cart_cols"] = sql("marketplace_carts cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_carts'
    ORDER BY ordinal_position
""")
results["cart_items_cols"] = sql("marketplace_cart_items cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_cart_items'
    ORDER BY ordinal_position
""")

# 7. marketplace_orders + order_items
print("=== MARKETPLACE_ORDERS ===")
results["orders_cols"] = sql("marketplace_orders cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_orders'
    ORDER BY ordinal_position
""")
results["order_items_cols"] = sql("marketplace_order_items cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_order_items'
    ORDER BY ordinal_position
""")

# 8. marketplace_listing_bookmarks
print("=== MARKETPLACE_LISTING_BOOKMARKS ===")
results["bookmarks_cols"] = sql("marketplace_listing_bookmarks cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_listing_bookmarks'
    ORDER BY ordinal_position
""")

# 9. opportunity_inquiries + messages
print("=== OPPORTUNITY_INQUIRIES ===")
results["inq_cols"] = sql("opportunity_inquiries cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='opportunity_inquiries'
    ORDER BY ordinal_position
""")
results["inq_msg_cols"] = sql("opportunity_inquiry_messages cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='opportunity_inquiry_messages'
    ORDER BY ordinal_position
""")

# 10. opportunity_reactions + comments + bookmarks + views
print("=== OPPORTUNITY SOCIAL TABLES ===")
for t in ['opportunity_reactions', 'opportunity_comments', 'opportunity_bookmarks', 'opportunity_views']:
    results[f"{t}_cols"] = sql(f"{t} cols", f"""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='{t}'
        ORDER BY ordinal_position
    """)

# 11. opportunities table (to deprecate)
print("=== OPPORTUNITIES (to deprecate) ===")
results["opp_cols"] = sql("opportunities cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='opportunities'
    ORDER BY ordinal_position
""")

# 12. FK constraints on all marketplace/opportunity tables
print("=== FOREIGN KEYS ===")
results["fk"] = sql("foreign keys", """
    SELECT
        tc.table_name,
        kcu.column_name,
        ccu.table_schema AS foreign_table_schema,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'app'
        AND (tc.table_name ILIKE '%%marketplace%%'
            OR tc.table_name ILIKE '%%opportunit%%'
            OR tc.table_name ILIKE '%%merchant%%')
    ORDER BY tc.table_name, kcu.column_name
""")

# 13. Data counts
print("=== DATA COUNTS ===")
results["counts"] = sql("data counts", """
    SELECT
        (SELECT COUNT(*) FROM app.marketplace_listings) AS listings,
        (SELECT COUNT(*) FROM app.marketplace_merchants) AS merchants,
        (SELECT COUNT(*) FROM app.merchant_profiles) AS merchant_profiles,
        (SELECT COUNT(*) FROM app.marketplace_categories) AS categories,
        (SELECT COUNT(*) FROM app.marketplace_listing_media) AS listing_media,
        (SELECT COUNT(*) FROM app.marketplace_listing_bookmarks) AS listing_bookmarks,
        (SELECT COUNT(*) FROM app.marketplace_carts) AS carts,
        (SELECT COUNT(*) FROM app.marketplace_cart_items) AS cart_items,
        (SELECT COUNT(*) FROM app.marketplace_orders) AS orders,
        (SELECT COUNT(*) FROM app.marketplace_order_items) AS order_items,
        (SELECT COUNT(*) FROM app.opportunities) AS opportunities,
        (SELECT COUNT(*) FROM app.opportunity_applications) AS opp_applications,
        (SELECT COUNT(*) FROM app.opportunity_types) AS opp_types,
        (SELECT COUNT(*) FROM app.opportunity_inquiries) AS inquiries,
        (SELECT COUNT(*) FROM app.opportunity_reactions) AS reactions,
        (SELECT COUNT(*) FROM app.opportunity_comments) AS comments,
        (SELECT COUNT(*) FROM app.opportunity_bookmarks) AS bookmarks,
        (SELECT COUNT(*) FROM app.opportunity_views) AS views
""")

# 14. Check if marketplace_reviews already exists
print("=== CHECK NEW TABLES ===")
results["check_reviews"] = sql("check marketplace_reviews", """
    SELECT table_name FROM information_schema.tables
    WHERE table_schema='app' AND table_name IN ('marketplace_reviews','marketplace_payments','marketplace_merchant_balances')
""")

# 15. All marketplace/opportunity RPC names
print("=== ALL RPCS ===")
results["rpcs"] = sql("all rpcs", """
    SELECT p.proname AS name,
           pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.proname ILIKE '%%opportunit%%'
        OR p.proname ILIKE '%%marketplace%%'
        OR p.proname ILIKE '%%listing%%'
        OR p.proname ILIKE '%%merchant%%'
        OR p.proname ILIKE '%%inquiry%%'
        OR p.proname ILIKE '%%cart%%'
        OR p.proname ILIKE '%%bookmark%%')
      AND p.proname NOT ILIKE '%%storage%%'
    ORDER BY p.proname
""")

# 16. RLS policies
print("=== RLS POLICIES ===")
results["rls"] = sql("rls policies", """
    SELECT tablename, policyname, roles, cmd
    FROM pg_policies
    WHERE schemaname = 'app'
      AND (tablename ILIKE '%%marketplace%%'
        OR tablename ILIKE '%%opportunit%%'
        OR tablename ILIKE '%%merchant%%')
    ORDER BY tablename, policyname
""")

# 17. Indexes
print("=== INDEXES ===")
results["indexes"] = sql("indexes", """
    SELECT schemaname, tablename, indexname
    FROM pg_indexes
    WHERE schemaname = 'app'
      AND (tablename ILIKE '%%marketplace%%'
        OR tablename ILIKE '%%opportunit%%'
        OR tablename ILIKE '%%merchant%%')
    ORDER BY tablename, indexname
""")

# Save
out = Path(__file__).parent / "logs" / "audit_phase1_marketplace.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print(f"\nSaved to {out}")
