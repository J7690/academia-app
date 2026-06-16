#!/usr/bin/env python3
"""Extra audit queries for opportunities module."""
import json
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

queries = {
    "CART_CHECKOUT_RPCS": """
        SELECT routine_name FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND (routine_name ILIKE '%%cart%%'
          OR routine_name ILIKE '%%checkout%%'
          OR routine_name = 'app_admin_update_application_status'
          OR routine_name = 'app_admin_set_merchant_verification'
          OR routine_name = 'app_student_get_cart')
        ORDER BY routine_name
    """,
    "MARKETPLACE_LISTINGS_ALL_COLS": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'marketplace_listings'
        ORDER BY ordinal_position
    """,
    "OPPORTUNITY_VIEWS_COLS": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'opportunity_views'
        ORDER BY ordinal_position
    """,
    "MARKETPLACE_MERCHANTS_COLS": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'marketplace_merchants'
        ORDER BY ordinal_position
    """,
    "MERCHANT_PROFILES_COLS": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'merchant_profiles'
        ORDER BY ordinal_position
    """,
    "MARKETPLACE_INQUIRIES_COLS": """
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app'
          AND (table_name ILIKE '%%inquiry%%' OR table_name ILIKE '%%inquiries%%')
        ORDER BY table_name, ordinal_position
    """,
    "LANDING_MEDIA_BUCKET": """
        SELECT id, name, public
        FROM storage.buckets
        WHERE name = 'landing-media'
    """,
    "OPP_DATA_SAMPLE": """
        SELECT id, title, type, status, review_status, merchant_id, is_active,
               price_from, price_to, currency, min_order_qty, is_ready_to_ship
        FROM app.opportunities
        ORDER BY created_at DESC
        LIMIT 5
    """,
    "MARKETPLACE_DATA_SAMPLE": """
        SELECT id, title, type, review_status, merchant_id, is_active,
               price_from, price_to, currency, min_order_qty, is_ready_to_ship
        FROM app.marketplace_listings
        ORDER BY created_at DESC
        LIMIT 5
    """,
    "ADMIN_UPDATE_APPLICATION_STATUS_EXISTS": """
        SELECT routine_name, data_type
        FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name = 'app_admin_update_application_status'
    """,
}

results = {}
for label, sql in queries.items():
    print(f"Running: {label}...")
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    data = resp.json()
    if isinstance(data, dict):
        rows = data.get("rows", [])
        ok = data.get("ok", False)
        err = data.get("error")
    else:
        rows = data if isinstance(data, list) else []
        ok = True
        err = None
    results[label] = {"ok": ok, "rows": rows, "error": err}
    if ok:
        print(f"  OK: {len(rows)} rows")
    else:
        print(f"  ERROR: {err}")

print("\n" + json.dumps(results, indent=2, ensure_ascii=False))
