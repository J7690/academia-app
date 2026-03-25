#!/usr/bin/env python3
"""Verify Phase 1 migration was applied correctly."""
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
    status = "OK" if ok else "ERR"
    print("%s %s: %d rows%s" % (status, label, len(rows), (" - " + str(err)) if err else ""))
    return rows

# 1. Check new columns on marketplace_listings
print("=== 1. marketplace_listings new columns ===")
new_ml_cols = sql("new ml cols", """
    SELECT column_name, data_type, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_listings'
      AND column_name IN ('cover_url','video_url','rating_avg','rating_count',
                          'sales_count','views_count','reactions_count','comments_count',
                          'tags','specifications','variants')
    ORDER BY column_name
""")
for r in new_ml_cols:
    print("  %s: %s (default=%s)" % (r["column_name"], r["data_type"], r.get("column_default")))

# 2. Check new columns on marketplace_merchants
print("\n=== 2. marketplace_merchants new columns ===")
new_mm_cols = sql("new mm cols", """
    SELECT column_name, data_type, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_merchants'
      AND column_name IN ('is_verified','verification_level','bio','display_name',
                          'rating_avg','total_sales','total_products')
    ORDER BY column_name
""")
for r in new_mm_cols:
    print("  %s: %s (default=%s)" % (r["column_name"], r["data_type"], r.get("column_default")))

# 3. Check new tables exist
print("\n=== 3. New tables ===")
new_tables = sql("new tables", """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema='app'
      AND table_name IN ('marketplace_reviews','marketplace_payments','marketplace_merchant_balances')
    ORDER BY table_name
""")
for r in new_tables:
    print("  %s" % r["table_name"])

# 4. Check marketplace_reviews columns
print("\n=== 4. marketplace_reviews columns ===")
rev_cols = sql("reviews cols", """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_reviews'
    ORDER BY ordinal_position
""")
for r in rev_cols:
    print("  %s: %s (null=%s)" % (r["column_name"], r["data_type"], r["is_nullable"]))

# 5. Check marketplace_payments columns
print("\n=== 5. marketplace_payments columns ===")
pay_cols = sql("payments cols", """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_payments'
    ORDER BY ordinal_position
""")
for r in pay_cols:
    print("  %s: %s (null=%s)" % (r["column_name"], r["data_type"], r["is_nullable"]))

# 6. Check marketplace_merchant_balances columns
print("\n=== 6. marketplace_merchant_balances columns ===")
bal_cols = sql("balances cols", """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_merchant_balances'
    ORDER BY ordinal_position
""")
for r in bal_cols:
    print("  %s: %s (null=%s)" % (r["column_name"], r["data_type"], r["is_nullable"]))

# 7. Check listing_id added to social tables
print("\n=== 7. listing_id on social tables ===")
listing_id_cols = sql("listing_id cols", """
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema='app'
      AND column_name = 'listing_id'
      AND table_name IN ('opportunity_reactions','opportunity_comments','opportunity_bookmarks')
    ORDER BY table_name
""")
for r in listing_id_cols:
    print("  %s.%s: %s" % (r["table_name"], r["column_name"], r["data_type"]))

# 8. Check RLS enabled
print("\n=== 8. RLS policies on new tables ===")
rls = sql("rls new tables", """
    SELECT tablename, policyname, cmd
    FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename IN ('marketplace_reviews','marketplace_payments','marketplace_merchant_balances')
    ORDER BY tablename, policyname
""")
for r in rls:
    print("  %s: %s (%s)" % (r["tablename"], r["policyname"], r["cmd"]))

# 9. Check cover_url was populated
print("\n=== 9. cover_url populated ===")
covers = sql("covers", """
    SELECT id, title, cover_url
    FROM app.marketplace_listings
    ORDER BY created_at DESC
    LIMIT 5
""")
for r in covers:
    title = r.get("title", "")[:40]
    cover = r.get("cover_url", "")
    has = "YES" if cover else "NO"
    print("  %s: cover=%s (%s)" % (title, has, (cover or "")[:60]))

# 10. Check new indexes
print("\n=== 10. New indexes ===")
idxs = sql("indexes", """
    SELECT indexname
    FROM pg_indexes
    WHERE schemaname = 'app'
      AND (indexname ILIKE '%%marketplace_reviews%%'
        OR indexname ILIKE '%%marketplace_payments%%'
        OR indexname ILIKE '%%marketplace_merchant_balances%%'
        OR indexname ILIKE '%%reactions_listing%%'
        OR indexname ILIKE '%%comments_listing%%'
        OR indexname ILIKE '%%bookmarks_listing%%'
        OR indexname ILIKE '%%listings_review_status%%'
        OR indexname ILIKE '%%listings_merchant%%'
        OR indexname ILIKE '%%listings_category%%'
        OR indexname ILIKE '%%listings_rating%%'
        OR indexname ILIKE '%%listings_sales%%')
    ORDER BY indexname
""")
for r in idxs:
    print("  %s" % r["indexname"])

print("\n=== VERIFICATION COMPLETE ===")
