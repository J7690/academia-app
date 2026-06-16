#!/usr/bin/env python3
"""Phase 5.2 — Audit what fields the listing RPC returns for the grid."""
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

# 1. Check what the listing RPC returns by looking at its source
print("=== 1. RPC source: app_student_list_marketplace_listings (9-param version) ===")
rows = sql("rpc source", """
    SELECT pg_get_functiondef(p.oid) AS def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'app_student_list_marketplace_listings'
    ORDER BY length(pg_get_function_arguments(p.oid)) DESC
    LIMIT 1
""")
if rows:
    defn = rows[0].get("def", "")
    # Print first 2000 chars
    print(defn[:2000])
    if len(defn) > 2000:
        print("... [truncated, total %d chars]" % len(defn))

# 2. Sample data with all fields
print("\n=== 2. Sample listing with all new columns ===")
rows2 = sql("sample", """
    SELECT l.id, l.title, l.cover_url, l.video_url,
           l.rating_avg, l.rating_count, l.sales_count, l.views_count,
           l.reactions_count, l.comments_count,
           l.price_from, l.price_to, l.currency,
           l.min_order_qty, l.lead_time_days, l.is_ready_to_ship,
           l.tags, l.specifications, l.variants,
           l.merchant_id, l.type, l.category,
           mm.name AS merchant_name, mm.is_verified AS merchant_is_verified,
           mm.verification_level AS merchant_verification_level,
           mm.logo_url AS merchant_logo_url
    FROM app.marketplace_listings l
    LEFT JOIN app.marketplace_merchants mm ON mm.id = l.merchant_id
    WHERE l.is_active = true AND l.review_status = 'approved'
    ORDER BY l.created_at DESC
    LIMIT 3
""")
for r in rows2:
    print("\n  --- %s ---" % r.get("title", "?"))
    for k, v in sorted(r.items()):
        print("    %-30s = %s" % (k, str(v)[:60] if v is not None else "NULL"))

# 3. Categories data
print("\n=== 3. Root categories ===")
cats = sql("categories", """
    SELECT id, label, parent_id, sort_order
    FROM app.marketplace_categories
    WHERE parent_id IS NULL
    ORDER BY sort_order, label
""")
for c in cats:
    print("  %s: %s (sort=%s)" % (c.get("id","")[:8], c.get("label"), c.get("sort_order")))

# 4. Count media per listing
print("\n=== 4. Media per listing ===")
media = sql("media counts", """
    SELECT l.id, l.title, COUNT(m.id) AS media_count,
           STRING_AGG(m.media_type, ', ') AS types
    FROM app.marketplace_listings l
    LEFT JOIN app.marketplace_listing_media m ON m.listing_id = l.id AND m.is_active = true
    WHERE l.is_active = true AND l.review_status = 'approved'
    GROUP BY l.id, l.title
    ORDER BY l.title
""")
for r in media:
    print("  %-35s media=%s types=%s" % (
        str(r.get("title",""))[:35], r.get("media_count",0), r.get("types","none")))
