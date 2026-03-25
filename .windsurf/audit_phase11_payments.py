#!/usr/bin/env python3
"""Phase 11.1 — Audit payment tables and existing RPCs."""
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = m.url + "/rest/v1/rpc/admin_execute_sql"

def sql(label, query):
    resp = requests.post(url, headers=m.headers, json={"p_sql": query.strip()}, timeout=60)
    data = resp.json()
    rows = data.get("rows", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
    err = data.get("error") if isinstance(data, dict) else None
    sys.stdout.write("%s %s: %d rows%s\n" % ("OK" if not err else "ERR", label, len(rows), (" - " + str(err)) if err else ""))
    return rows

# 1. Payment tables exist?
sys.stdout.write("=== 1. Payment tables ===\n")
tables = sql("tables", """
    SELECT table_name FROM information_schema.tables
    WHERE table_schema='app'
      AND table_name IN ('marketplace_payments','marketplace_merchant_balances')
    ORDER BY table_name
""")
for r in tables:
    sys.stdout.write("  %s\n" % r["table_name"])

# 2. marketplace_payments columns
sys.stdout.write("\n=== 2. marketplace_payments columns ===\n")
cols = sql("payments cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_payments'
    ORDER BY ordinal_position
""")
for c in cols:
    sys.stdout.write("  %-25s %-20s null=%s\n" % (c["column_name"], c["data_type"][:20], c["is_nullable"]))

# 3. marketplace_merchant_balances columns
sys.stdout.write("\n=== 3. marketplace_merchant_balances columns ===\n")
cols2 = sql("balances cols", """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='marketplace_merchant_balances'
    ORDER BY ordinal_position
""")
for c in cols2:
    sys.stdout.write("  %-25s %-20s null=%s\n" % (c["column_name"], c["data_type"][:20], c["is_nullable"]))

# 4. Any payment RPCs exist?
sys.stdout.write("\n=== 4. Existing payment/balance RPCs ===\n")
rpcs = sql("payment rpcs", """
    SELECT p.proname AS name
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.proname LIKE '%%payment%%' OR p.proname LIKE '%%balance%%' OR p.proname LIKE '%%escrow%%')
    ORDER BY p.proname
""")
for r in rpcs:
    sys.stdout.write("  %s\n" % r["name"])
if not rpcs:
    sys.stdout.write("  (none)\n")

# 5. commission_rules table exists?
sys.stdout.write("\n=== 5. commission_rules table ===\n")
cr = sql("commission_rules", """
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='commission_rules'
    ORDER BY ordinal_position
""")
for c in cr:
    sys.stdout.write("  %-25s %s\n" % (c["column_name"], c["data_type"]))
if not cr:
    sys.stdout.write("  (table does not exist)\n")

# 6. fn_resolve_commission_rate exists?
sys.stdout.write("\n=== 6. fn_resolve_commission_rate ===\n")
fn = sql("resolve fn", """
    SELECT p.proname AS name, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'app' AND p.proname = 'fn_resolve_commission_rate'
""")
for r in fn:
    sys.stdout.write("  %s(%s)\n" % (r["name"], r["args"]))
if not fn:
    sys.stdout.write("  (does not exist)\n")

# 7. Data counts
sys.stdout.write("\n=== 7. Data ===\n")
cnt = sql("counts", """
    SELECT
        (SELECT COUNT(*) FROM app.marketplace_payments) AS payments,
        (SELECT COUNT(*) FROM app.marketplace_merchant_balances) AS balances
""")
for r in cnt:
    sys.stdout.write("  payments: %s, balances: %s\n" % (r["payments"], r["balances"]))
