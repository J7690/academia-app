#!/usr/bin/env python3
"""Audit Phase 1 post-implémentation — Vérifier que TOUT a été créé correctement."""

import json
from pathlib import Path
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()
results = {}
errors = []

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
            errors.append(f"{label}: {err[:200]}")
            return {"error": err}
    except Exception as e:
        if label:
            print(f"[EXC] {label}: {e}")
        errors.append(f"{label}: {str(e)}")
        return {"error": str(e)}

print("=" * 72)
print("VÉRIFICATION POST-IMPLÉMENTATION PHASE 1")
print("=" * 72)

# 1. Vérifier les 4 nouvelles tables
print("\n--- 1. Nouvelles tables ---")
for tbl in ['subscription_plans', 'subscriptions', 'payout_queue', 'platform_ledger']:
    r = sql(f"SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{tbl}'", f"table app.{tbl}")
    cnt = r[0]['cnt'] if isinstance(r, list) and r else 0
    results[f"table_{tbl}"] = cnt
    if cnt == 0:
        errors.append(f"TABLE MANQUANTE: app.{tbl}")

# 2. Vérifier les nouvelles valeurs enum
print("\n--- 2. Nouvelles valeurs enum ---")
for enum_name, expected_values in [
    ('payment_channel', ['ligdicash']),
    ('payment_status', ['processing']),
    ('payment_reason', ['subscription', 'marketplace_purchase', 'online_course']),
]:
    r = sql(f"SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid=t.oid WHERE t.typname='{enum_name}' ORDER BY e.enumsortorder", f"enum {enum_name}")
    existing = [x['enumlabel'] for x in r] if isinstance(r, list) else []
    for val in expected_values:
        if val in existing:
            print(f"  ✓ {enum_name}.{val}")
        else:
            print(f"  ✗ {enum_name}.{val} MANQUANT")
            errors.append(f"ENUM MANQUANT: {enum_name}.{val}")
    results[f"enum_{enum_name}"] = existing

# 3. Vérifier les nouvelles colonnes
print("\n--- 3. Nouvelles colonnes ---")
checks = [
    ('application_payments', ['ligdicash_token', 'ligdicash_transaction_id', 'ligdicash_operator', 'payment_method', 'phone_number']),
    ('marketplace_payments', ['ligdicash_token', 'ligdicash_transaction_id', 'phone_number']),
    ('commercial_profiles', ['payout_phone']),
]
for table, cols in checks:
    r = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{table}'", f"cols {table}")
    existing = [x['column_name'] for x in r] if isinstance(r, list) else []
    for col in cols:
        if col in existing:
            print(f"  ✓ {table}.{col}")
        else:
            print(f"  ✗ {table}.{col} MANQUANT")
            errors.append(f"COLONNE MANQUANTE: {table}.{col}")

# 4. Vérifier les 9 RPCs
print("\n--- 4. Nouvelles RPCs ---")
rpcs = [
    'app_student_check_subscription', 'app_admin_list_payout_queue',
    'app_admin_get_treasury_summary', 'app_admin_list_ledger',
    'app_commercial_request_payout', 'app_merchant_request_payout',
    'app_admin_manage_subscription_plan', 'app_admin_list_subscriptions',
    'app_confirm_ligdicash_payment',
]
for rpc in rpcs:
    r = sql(f"SELECT COUNT(*) as cnt FROM information_schema.routines WHERE routine_name='{rpc}'", f"RPC {rpc}")
    cnt = r[0]['cnt'] if isinstance(r, list) and r else 0
    if cnt > 0:
        print(f"  ✓ {rpc}")
    else:
        print(f"  ✗ {rpc} MANQUANTE")
        errors.append(f"RPC MANQUANTE: {rpc}")

# 5. Vérifier RLS activé sur nouvelles tables
print("\n--- 5. RLS activé ---")
r = sql("""
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname='app' AND tablename IN ('subscription_plans','subscriptions','payout_queue','platform_ledger')
""", "RLS status")
if isinstance(r, list):
    for row in r:
        status = "✓ RLS ON" if row.get('rowsecurity') else "✗ RLS OFF"
        print(f"  {status} — {row['tablename']}")
results["rls_new_tables"] = r

# 6. Vérifier les RLS policies
print("\n--- 6. RLS policies ---")
r = sql("""
SELECT tablename, policyname, cmd FROM pg_policies
WHERE schemaname='app' AND tablename IN ('subscription_plans','subscriptions','payout_queue','platform_ledger')
ORDER BY tablename, policyname
""", "RLS policies")
if isinstance(r, list):
    for row in r:
        print(f"  ✓ {row['tablename']}.{row['policyname']} ({row['cmd']})")
results["rls_policies"] = r

# 7. Vérifier seed data
print("\n--- 7. Seed data subscription_plans ---")
r = sql("SELECT code, name, price, duration_days FROM app.subscription_plans ORDER BY price", "seed plans")
if isinstance(r, list):
    for row in r:
        print(f"  ✓ {row['code']} — {row['price']} XOF / {row['duration_days']}j")
results["seed_plans"] = r

# 8. Vérifier les index
print("\n--- 8. Nouveaux index ---")
r = sql("""
SELECT indexname, tablename FROM pg_indexes
WHERE schemaname='app' AND indexname LIKE 'idx_%'
  AND tablename IN ('subscriptions','payout_queue','platform_ledger','application_payments')
ORDER BY tablename, indexname
""", "nouveaux index")
if isinstance(r, list):
    for row in r:
        print(f"  ✓ {row['indexname']} on {row['tablename']}")
results["new_indexes"] = r

# RÉSUMÉ
print("\n" + "=" * 72)
if errors:
    print(f"⚠️ {len(errors)} ERREUR(S) DÉTECTÉE(S):")
    for e in errors:
        print(f"  - {e}")
else:
    print("✅ VÉRIFICATION COMPLÈTE — TOUT EST OK")
results["errors"] = errors

output_path = Path(__file__).parent / "logs" / "audit_phase1_post_impl.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
