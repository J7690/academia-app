#!/usr/bin/env python3
"""Audit Phase 1 pré-implémentation — Vérifier exactement ce qui existe avant de créer."""

import json
from pathlib import Path
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()
results = {}

def sql(query, label=""):
    try:
        resp = manager.execute_sql_auto(query)
        if resp.get("success"):
            data = resp.get("data") or []
            if label:
                print(f"[OK] {label}: {len(data) if isinstance(data, list) else 'ok'}")
            return data
        else:
            err = resp.get("error", "unknown")
            if label:
                print(f"[ERR] {label}: {err[:300]}")
            return {"error": err}
    except Exception as e:
        if label:
            print(f"[EXC] {label}: {e}")
        return {"error": str(e)}

print("=" * 72)
print("AUDIT PHASE 1 — PRÉ-IMPLÉMENTATION")
print("=" * 72)

# 1. Vérifier si les tables cibles existent déjà
print("\n--- 1. Tables cibles existent ? ---")
for tbl in ['subscription_plans', 'subscriptions', 'payout_queue', 'platform_ledger']:
    results[f"exists_{tbl}"] = sql(f"""
    SELECT COUNT(*) as cnt FROM information_schema.tables 
    WHERE table_schema = 'app' AND table_name = '{tbl}'
    """, f"table app.{tbl}")

# 2. Vérifier les valeurs actuelles des enums
print("\n--- 2. Valeurs actuelles enums ---")
for enum_name in ['payment_channel', 'payment_status', 'payment_reason']:
    results[f"enum_{enum_name}"] = sql(f"""
    SELECT e.enumlabel
    FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = '{enum_name}'
    ORDER BY e.enumsortorder
    """, f"enum {enum_name}")

# 3. Vérifier les colonnes existantes sur application_payments
print("\n--- 3. Colonnes application_payments ---")
results["ap_columns"] = sql("""
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'application_payments'
ORDER BY ordinal_position
""", "application_payments columns")

# 4. Vérifier les colonnes existantes sur marketplace_payments
print("\n--- 4. Colonnes marketplace_payments ---")
results["mp_columns"] = sql("""
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'marketplace_payments'
ORDER BY ordinal_position
""", "marketplace_payments columns")

# 5. Vérifier les colonnes existantes sur commercial_profiles
print("\n--- 5. Colonnes commercial_profiles ---")
results["cp_columns"] = sql("""
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'commercial_profiles'
ORDER BY ordinal_position
""", "commercial_profiles columns")

# 6. Vérifier si marketplace_merchant_balances existe et ses colonnes
print("\n--- 6. marketplace_merchant_balances ---")
results["mmb_columns"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'marketplace_merchant_balances'
ORDER BY ordinal_position
""", "marketplace_merchant_balances columns")

# 7. Vérifier que les RPCs cibles n'existent pas déjà
print("\n--- 7. RPCs cibles existent ? ---")
target_rpcs = [
    'app_student_check_subscription',
    'app_admin_list_payout_queue',
    'app_admin_get_treasury_summary',
    'app_admin_list_ledger',
    'app_commercial_request_payout',
    'app_merchant_request_payout',
    'app_admin_manage_subscription_plan',
    'app_admin_list_subscriptions',
    'app_confirm_ligdicash_payment',
]
for rpc in target_rpcs:
    results[f"rpc_exists_{rpc}"] = sql(f"""
    SELECT COUNT(*) as cnt FROM information_schema.routines
    WHERE routine_name = '{rpc}'
    """, f"RPC {rpc}")

# 8. Schéma utilisé par les tables existantes (vérifier que tout est dans 'app')
print("\n--- 8. Schéma des tables financières ---")
results["schemas"] = sql("""
SELECT DISTINCT table_schema, table_name
FROM information_schema.tables
WHERE table_name IN ('application_payments','payment_receipts','payment_proofs',
  'marketplace_payments','marketplace_orders','marketplace_merchant_balances',
  'referral_commissions','commission_rules','commercial_profiles','td_enrollments')
ORDER BY table_schema, table_name
""", "schemas tables financières")

# 9. Vérifier si des RLS existent pour RLS_ENABLED sur les tables financières
print("\n--- 9. RLS enabled ? ---")
results["rls_enabled"] = sql("""
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename IN ('application_payments','payment_receipts','marketplace_payments',
  'marketplace_orders','referral_commissions','commercial_profiles','td_enrollments')
  AND schemaname = 'app'
ORDER BY tablename
""", "RLS enabled status")

# Save
print("\n" + "=" * 72)
output_path = Path(__file__).parent / "logs" / "audit_phase1_pre_impl.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
