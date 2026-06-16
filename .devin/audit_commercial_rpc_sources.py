#!/usr/bin/env python3
"""Audit RPC sources for the complete referral flow."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def q(label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n=== {label} ===")
    if not ok:
        print(f"ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in rows[:3]:
        src = row.get("src", "")
        print(src[:5000])
        if len(src) > 5000: print("...[TRUNC]")
    if ok and not rows: print("(0 rows)")

# 1. app_register_referral_for_current_user — FULL SOURCE
q("RPC: app_register_referral_for_current_user", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_register_referral_for_current_user' LIMIT 1
""")

# 2. app_admin_confirm_payment — COMMISSION SECTION ONLY (from char 2500)
q("RPC: app_admin_confirm_payment (commission section)", """
SELECT SUBSTRING(pg_get_functiondef(p.oid), 2500, 3000) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_admin_confirm_payment' LIMIT 1
""")

# 3. fn_check_commission_cap — FULL (verify /100 fix)
q("RPC: fn_check_commission_cap", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_check_commission_cap' LIMIT 1
""")

# 4. fn_resolve_commission_rate — FULL
q("RPC: fn_resolve_commission_rate", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_resolve_commission_rate' LIMIT 1
""")

# 5. fn_update_commercial_tier — FULL (verify aligned counter)
q("RPC: fn_update_commercial_tier", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_update_commercial_tier' LIMIT 1
""")

# 6. app_commercial_get_dashboard — VERIFY privacy fixes (amount_range, no channel)
q("RPC: dashboard prospect_payments section", """
SELECT SUBSTRING(pg_get_functiondef(p.oid), 4000, 2000) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_commercial_get_dashboard' LIMIT 1
""")
