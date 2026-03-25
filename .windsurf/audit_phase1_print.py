#!/usr/bin/env python3
"""Print Phase 1 audit results in readable format."""
import json
from pathlib import Path

data = json.loads(Path(__file__).parent.joinpath("logs", "audit_phase1_marketplace.json").read_text(encoding="utf-8"))

print("=== DATA COUNTS ===")
for r in data["counts"]["rows"]:
    for k, v in sorted(r.items()):
        print("  %s: %s" % (k, v))

print("\n=== MARKETPLACE_LISTINGS COLUMNS (31) ===")
for r in data["ml_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    nu = r["is_nullable"]
    print("  %-30s %-30s null=%s" % (cn, dt, nu))

print("\n=== MARKETPLACE_MERCHANTS COLUMNS (17) ===")
for r in data["mm_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    nu = r["is_nullable"]
    print("  %-30s %-30s null=%s" % (cn, dt, nu))

print("\n=== MERCHANT_PROFILES COLUMNS (11) ===")
for r in data["mp_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    nu = r["is_nullable"]
    print("  %-30s %-30s null=%s" % (cn, dt, nu))

print("\n=== FOREIGN KEYS ===")
for r in data["fk"]["rows"]:
    tn = r["table_name"]
    cn = r["column_name"]
    fts = r["foreign_table_schema"]
    ftn = r["foreign_table_name"]
    fcn = r["foreign_column_name"]
    print("  %s.%s -> %s.%s.%s" % (tn, cn, fts, ftn, fcn))

print("\n=== NEW TABLES CHECK ===")
print("  marketplace_reviews/payments/balances exist:", data["check_reviews"]["rows"])

print("\n=== MARKETPLACE_LISTING_MEDIA COLUMNS ===")
for r in data["mlm_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    print("  %-30s %s" % (cn, dt))

print("\n=== CARTS ===")
for r in data["cart_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    print("  %-30s %s" % (cn, dt))
print("--- cart_items ---")
for r in data["cart_items_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    print("  %-30s %s" % (cn, dt))

print("\n=== ORDERS ===")
for r in data["orders_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    print("  %-30s %s" % (cn, dt))
print("--- order_items ---")
for r in data["order_items_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    print("  %-30s %s" % (cn, dt))

print("\n=== INQUIRIES ===")
for r in data["inq_cols"]["rows"]:
    cn = r["column_name"]
    dt = r["data_type"]
    print("  %-30s %s" % (cn, dt))

print("\n=== OPPORTUNITY SOCIAL TABLES ===")
for tbl in ["opportunity_reactions", "opportunity_comments", "opportunity_bookmarks", "opportunity_views"]:
    key = tbl + "_cols"
    print("--- %s ---" % tbl)
    for r in data[key]["rows"]:
        cn = r["column_name"]
        dt = r["data_type"]
        print("  %-30s %s" % (cn, dt))
