#!/usr/bin/env python3
"""Phase 4.2 — Audit what data the listing RPCs actually return."""
import json
import requests
from pathlib import Path
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

# 1. Test app_student_list_marketplace_listings with a real call
print("=== 1. app_student_list_marketplace_listings response structure ===")
resp = requests.post(
    f"{m.url}/rest/v1/rpc/app_student_list_marketplace_listings",
    headers=m.headers,
    json={"p_limit": 2, "p_offset": 0, "p_sort": "newest"},
    timeout=30,
)
data = resp.json()
if isinstance(data, dict) and data.get("success"):
    print("  total: %s" % data.get("total"))
    print("  has_more: %s" % data.get("has_more"))
    items = data.get("items", data.get("opportunities", []))
    if items:
        print("  FIRST ITEM KEYS: %s" % sorted(items[0].keys()))
        for k, v in sorted(items[0].items()):
            val_str = str(v)[:80] if v is not None else "NULL"
            print("    %-30s = %s" % (k, val_str))
    else:
        print("  NO ITEMS")
else:
    print("  ERROR: %s" % str(data)[:200])

# 2. Test app_student_get_listing_detail_v2 with real listing
print("\n=== 2. app_student_get_listing_detail_v2 response structure ===")
url2 = f"{m.url}/rest/v1/rpc/admin_execute_sql"
rows = requests.post(url2, headers=m.headers, json={"p_sql": """
    SELECT id FROM app.marketplace_listings
    WHERE is_active = true AND review_status = 'approved'
    LIMIT 1
"""}, timeout=30).json()
listing_rows = rows.get("rows", []) if isinstance(rows, dict) else rows
if listing_rows:
    lid = listing_rows[0]["id"]
    resp2 = requests.post(
        f"{m.url}/rest/v1/rpc/app_student_get_listing_detail_v2",
        headers=m.headers,
        json={"p_listing_id": lid},
        timeout=30,
    )
    d2 = resp2.json()
    if isinstance(d2, dict) and d2.get("success"):
        listing = d2.get("listing", {})
        print("  LISTING KEYS: %s" % sorted(listing.keys()) if listing else "NULL")
        media = d2.get("media", [])
        print("  MEDIA COUNT: %d" % len(media))
        if media:
            print("  FIRST MEDIA KEYS: %s" % sorted(media[0].keys()))
        merchant = d2.get("merchant")
        print("  MERCHANT: %s" % (sorted(merchant.keys()) if merchant else "NULL"))
        reviews = d2.get("reviews", [])
        print("  REVIEWS COUNT: %d" % len(reviews))
        print("  MY_REACTION: %s" % d2.get("my_reaction"))
        print("  IS_BOOKMARKED: %s" % d2.get("is_bookmarked"))
    else:
        print("  ERROR: %s" % str(d2)[:200])

# 3. Check how many listings have media
print("\n=== 3. Listings with media ===")
resp3 = requests.post(url2, headers=m.headers, json={"p_sql": """
    SELECT l.id, l.title, l.cover_url,
           COUNT(m.id) AS media_count
    FROM app.marketplace_listings l
    LEFT JOIN app.marketplace_listing_media m ON m.listing_id = l.id AND m.is_active = true
    WHERE l.is_active = true AND l.review_status = 'approved'
    GROUP BY l.id, l.title, l.cover_url
    ORDER BY l.created_at DESC
"""}, timeout=30).json()
media_rows = resp3.get("rows", []) if isinstance(resp3, dict) else resp3
for r in media_rows:
    title = r.get("title", "")[:35]
    cover = "YES" if r.get("cover_url") else "NO"
    mc = r.get("media_count", 0)
    print("  %-35s cover=%s  media=%d" % (title, cover, mc))

print("\n=== AUDIT COMPLETE ===")
