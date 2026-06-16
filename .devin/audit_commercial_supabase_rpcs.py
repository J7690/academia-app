#!/usr/bin/env python3
"""AUDIT COMMERCIAL — RPCs complètes + sources + user_invitations structure réelle."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in (rows or [])[:30]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:600]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

# 1. ALL commercial/referral/commission RPCs with FULL arguments
q(m, "1. ALL commercial RPCs (full list with args)", """
SELECT p.proname AS rpc_name, n.nspname AS schema,
       pg_get_function_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS returns
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('public', 'app')
AND (p.proname LIKE '%commercial%' OR p.proname LIKE '%referral%'
     OR p.proname LIKE '%commission%' OR p.proname LIKE '%invitation%'
     OR p.proname LIKE '%prospect%' OR p.proname LIKE '%attach%referral%'
     OR p.proname LIKE '%tier%' OR p.proname LIKE '%milestone%'
     OR p.proname LIKE '%leaderboard%')
ORDER BY p.proname
""")

# 2. user_invitations REAL columns
q(m, "2. user_invitations REAL columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema='app' AND table_name='user_invitations'
ORDER BY ordinal_position
""")

# 3. Source of app_commercial_get_dashboard (FULL)
q(m, "3. FULL source app_commercial_get_dashboard", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_commercial_get_dashboard' AND n.nspname IN ('public', 'app')
""")

# 4. Source of fn_resolve_commission_rate
q(m, "4. Source fn_resolve_commission_rate", """
SELECT LEFT(pg_get_functiondef(p.oid), 1000) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_resolve_commission_rate' AND n.nspname IN ('public', 'app')
""")

# 5. Source of fn_check_commission_cap
q(m, "5. Source fn_check_commission_cap", """
SELECT LEFT(pg_get_functiondef(p.oid), 1000) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_check_commission_cap' AND n.nspname IN ('public', 'app')
""")

# 6. Source of fn_update_commercial_tier
q(m, "6. Source fn_update_commercial_tier", """
SELECT LEFT(pg_get_functiondef(p.oid), 1000) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_update_commercial_tier' AND n.nspname IN ('public', 'app')
""")

# 7. How referral_code is generated / stored
q(m, "7. commercial_profiles sample (referral_code, tier, stats)", """
SELECT user_id, referral_code, tier, is_active,
       total_referrals, confirmed_referrals, created_at
FROM app.commercial_profiles
ORDER BY created_at DESC
""")

# 8. How referral attachment works — search for any function that handles referral codes
q(m, "8. Functions that reference 'referral_code' or 'pending_referral'", """
SELECT p.proname, n.nspname
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE pg_get_functiondef(p.oid) LIKE '%referral_code%'
AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

# 9. Auth users with role=commercial
q(m, "9. Users with role=commercial", """
SELECT id, email, LEFT(raw_user_meta_data::text, 200) AS meta
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'commercial'
ORDER BY created_at DESC LIMIT 10
""")

# 10. How admin creates commercials
q(m, "10. Functions containing 'create' AND 'commercial'", """
SELECT p.proname, n.nspname
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%commercial%' AND p.proname LIKE '%create%'
AND n.nspname IN ('public', 'app')
""")

q(m, "10b. Admin invite/create user functions", """
SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE (p.proname LIKE '%admin%create%' OR p.proname LIKE '%admin%invite%'
       OR p.proname LIKE '%create%user%' OR p.proname LIKE '%invite%user%')
AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

print(f"\n{'='*70}")
print("AUDIT RPCs COMMERCIAL TERMINÉ")
print(f"{'='*70}")
