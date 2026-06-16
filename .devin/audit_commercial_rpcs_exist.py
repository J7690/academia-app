#!/usr/bin/env python3
"""Verify which commercial RPCs called from Flutter actually exist in Supabase."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok: print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:400]}")
    for row in (rows or [])[:10]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:500]}")
    if ok and not rows: print("  (0 rows) — RPC DOES NOT EXIST")
    return rows

m = SupabaseAutoManager()
print("=" * 70)
print("VERIFICATION — RPCs appelées depuis Flutter vs existence Supabase")
print("=" * 70)

# RPCs called from CommercialDashboardProvider
rpcs_commercial = [
    'app_commercial_get_dashboard',
    'app_commercial_claim_milestone',
]

# RPCs called from AdminUsersOverviewProvider (commercial-related)
rpcs_admin = [
    'app_admin_list_users_overview',
    'app_admin_list_commercials_overview',
    'app_admin_get_commercial_detail',
    'app_admin_update_referral_commission_status',
    'app_admin_list_milestone_claims',
    'app_admin_update_milestone_claim_status',
    'app_admin_update_commercial_cap',
    'app_admin_set_commercial_commission_rate',
    'app_admin_update_user_status',
    'app_admin_delete_user_account',
    'app_admin_list_deleted_users',
    'app_admin_list_user_action_logs',
    'app_admin_create_user_invitation',
    'app_admin_list_commission_rules',
    'app_admin_upsert_commission_rule',
    'app_admin_delete_commission_rule',
]

# Edge Functions called
edge_functions = [
    'admin-hard-delete-user-account',
    'admin-promote-user-role',
]

# Referral attachment
rpcs_referral = [
    'app_attach_referral_code',
    'app_student_attach_referral',
    'app_register_with_referral',
]

print("\n--- COMMERCIAL PROVIDER RPCs ---")
for rpc in rpcs_commercial:
    q(m, rpc, f"""
    SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = '{rpc}' AND n.nspname IN ('public', 'app')
    """)

print("\n--- ADMIN PROVIDER RPCs ---")
for rpc in rpcs_admin:
    q(m, rpc, f"""
    SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = '{rpc}' AND n.nspname IN ('public', 'app')
    """)

print("\n--- REFERRAL ATTACHMENT RPCs ---")
for rpc in rpcs_referral:
    q(m, rpc, f"""
    SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = '{rpc}' AND n.nspname IN ('public', 'app')
    """)

# Check referral attachment in auth_wrapper or similar
print("\n--- REFERRAL FLOW ---")
q(m, "Functions containing 'referral' in name", """
SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%referral%' AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

q(m, "Functions containing 'attach' in name", """
SELECT p.proname, n.nspname
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%attach%' AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

print(f"\n{'='*70}")
print("VERIFICATION TERMINÉE")
print(f"{'='*70}")
