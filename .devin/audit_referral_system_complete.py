#!/usr/bin/env python3
"""Audit complet du système referral/commercial - tables + RPC + flux"""
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
    for row in (rows or [])[:10]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:600]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

print("=" * 70)
print("AUDIT COMPLET DU SYSTÈME REFERRAL/COMMERCIAL")
print("=" * 70)

# 1. Tables du système referral
print("\n=== TABLES DU SYSTÈME ===")
tables_to_check = [
    'commercial_profiles',
    'referral_commissions', 
    'user_referrals',
    'user_invitations',
    'commission_rules'
]

for table in tables_to_check:
    q(m, f"Table {table} - colonnes", f"""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='{table}'
    ORDER BY ordinal_position
    """)
    
    q(m, f"Table {table} - sample data", f"""
    SELECT * FROM app.{table} LIMIT 3
    """)

# 2. RPCs de referral
print("\n=== RPCs REFERRAL ===")
q(m, "RPC app_register_referral_for_current_user", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_register_referral_for_current_user' AND n.nspname IN ('public', 'app')
""")

# 3. Vérifier le lien unique commercial
q(m, "commercial_profiles - referral_code generation", """
SELECT user_id, email, 
       COALESCE(referral_code, 'NO_CODE') as referral_code,
       tier, is_active, created_at
FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id
WHERE u.raw_user_meta_data->>'role' = 'commercial'
ORDER BY cp.created_at DESC LIMIT 5
""")

# 4. Vérifier les enregistrements de referral
q(m, "user_referrals - tracking des prospects", """
SELECT * FROM app.user_referrals LIMIT 5
""")

# 5. Vérifier les commissions générées
q(m, "referral_commissions - commissions créées", """
SELECT * FROM app.referral_commissions ORDER BY created_at DESC LIMIT 5
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
