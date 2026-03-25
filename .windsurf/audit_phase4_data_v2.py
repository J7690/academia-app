#!/usr/bin/env python3
"""Phase 4.2 — Audit listing data with full params to disambiguate overloaded RPC."""
import json
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
sql_url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

# 1. Call with ALL params (9-param version) to avoid PGRST203
print("=== 1. app_student_list_marketplace_listings (9 params) ===")
resp = requests.post(
    f"{m.url}/rest/v1/rpc/app_student_list_marketplace_listings",
    headers=m.headers,
    json={
        "p_type": None, "p_search": None, "p_limit": 3, "p_offset": 0,
        "p_sort": "newest", "p_verified_only": False, "p_ready_to_ship_only": False,
        "p_category_id": None, "p_sub_category_id": None,
    },
    timeout=30,
)
data = resp.json()
if isinstance(data, dict) and data.get("success"):
    items = data.get("items", [])
    print("  total: %s, items: %d" % (data.get("total"), len(items)))
    if items:
        print("  KEYS: %s" % sorted(items[0].keys()))
        for k, v in sorted(items[0].items()):
            print("    %-30s = %s" % (k, str(v)[:80] if v is not None else "NULL"))
else:
    print("  Status: %d" % resp.status_code)
    print("  Body: %s" % str(data)[:300])

# 2. detail_v2 with real listing
print("\n=== 2. detail_v2 ===")
rows = requests.post(sql_url, headers=m.headers, json={"p_sql": """
    SELECT id FROM app.marketplace_listings
    WHERE is_active = true AND review_status = 'approved' LIMIT 1
"""}, timeout=30).json()
lr = rows.get("rows", []) if isinstance(rows, dict) else (rows if isinstance(rows, list) else [])
if lr:
    lid = lr[0]["id"]
    resp2 = requests.post(
        f"{m.url}/rest/v1/rpc/app_student_get_listing_detail_v2",
        headers=m.headers, json={"p_listing_id": lid}, timeout=30,
    )
    d2 = resp2.json()
    if isinstance(d2, dict) and d2.get("success"):
        listing = d2.get("listing", {})
        print("  LISTING KEYS: %s" % sorted(listing.keys()) if listing else "NULL")
        for k, v in sorted((listing or {}).items()):
            print("    %-25s = %s" % (k, str(v)[:70] if v is not None else "NULL"))
        media = d2.get("media", [])
        print("  MEDIA: %d items" % len(media))
        for mi in media[:3]:
            print("    type=%s path=%s" % (mi.get("media_type"), str(mi.get("storage_path",""))[:50]))
        merchant = d2.get("merchant")
        if merchant:
            print("  MERCHANT: %s" % {k: str(v)[:40] for k, v in merchant.items()})
        else:
            print("  MERCHANT: NULL")
    else:
        print("  ERROR: %s" % str(d2)[:200])

# 3. Media + cover stats
print("\n=== 3. Listings media stats ===")
r3 = requests.post(sql_url, headers=m.headers, json={"p_sql": """
    SELECT l.id, l.title, l.cover_url, l.rating_avg, l.rating_count,
           l.views_count, l.sales_count, l.reactions_count,
           COUNT(m.id) AS media_count
    FROM app.marketplace_listings l
    LEFT JOIN app.marketplace_listing_media m ON m.listing_id = l.id AND m.is_active = true
    WHERE l.is_active = true AND l.review_status = 'approved'
    GROUP BY l.id ORDER BY l.created_at DESC
"""}, timeout=30).json()
for r in (r3.get("rows", []) if isinstance(r3, dict) else r3):
    t = str(r.get("title",""))[:30]
    c = "YES" if r.get("cover_url") else "NO "
    print("  %-30s cover=%s media=%s rat=%s/%s views=%s sales=%s react=%s" % (
        t, c, r.get("media_count",0), r.get("rating_avg",0), r.get("rating_count",0),
        r.get("views_count",0), r.get("sales_count",0), r.get("reactions_count",0)))
