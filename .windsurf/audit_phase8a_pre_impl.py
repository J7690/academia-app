#!/usr/bin/env python3
"""Audit Phase 8A — Vérification exhaustive avant implémentation split revenus."""

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
                print(f"[ERR] {label}: {err[:200]}")
            return {"error": err}
    except Exception as e:
        if label:
            print(f"[EXC] {label}: {e}")
        return {"error": str(e)}

print("=" * 60)
print("AUDIT PHASE 8A — PRÉ-IMPLÉMENTATION EXHAUSTIF")
print("=" * 60)

# 1. Tables cibles : vérifier qu'elles n'existent PAS encore
print("\n--- 1. Tables cibles (doivent être cnt=0) ---")
for tbl in ['revenue_split_rules', 'actor_balances']:
    results[f"exists_{tbl}"] = sql(f"SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{tbl}'", f"exists {tbl}")

# 2. Colonnes EXACTES de chaque table acteur (pour savoir quoi ajouter)
print("\n--- 2. Colonnes exactes des tables acteurs ---")
for tbl in ['instructors', 'td_teachers', 'marketplace_merchants', 'universities', 'commercial_profiles']:
    results[f"cols_{tbl}"] = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{tbl}' ORDER BY ordinal_position", f"cols {tbl}")

# 3. Vérifier que les colonnes cibles n'existent PAS déjà
print("\n--- 3. Colonnes cibles manquantes ---")
checks = {
    'instructors': ['phone', 'payout_phone', 'payout_operator', 'speciality'],
    'td_teachers': ['phone', 'payout_phone', 'payout_operator'],
    'marketplace_merchants': ['payout_phone', 'payout_operator'],
    'universities': ['payout_phone', 'payout_operator', 'bank_name', 'bank_account'],
}
for tbl, cols in checks.items():
    existing = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{tbl}'")
    existing_names = [c['column_name'] for c in existing] if isinstance(existing, list) else []
    missing = [c for c in cols if c not in existing_names]
    already = [c for c in cols if c in existing_names]
    results[f"missing_{tbl}"] = missing
    results[f"already_{tbl}"] = already
    print(f"  {tbl}: missing={missing}, already={already}")

# 4. RPCs cibles (doivent être cnt=0)
print("\n--- 4. RPCs cibles ---")
target_rpcs = [
    'app_admin_list_revenue_split_rules',
    'app_admin_upsert_revenue_split_rule',
    'app_admin_delete_revenue_split_rule',
    'app_admin_validate_split_totals',
    'app_resolve_revenue_split',
    'app_instructor_get_my_balance',
    'app_instructor_request_payout',
    'app_university_get_balance',
    'app_university_request_payout',
    'app_admin_list_actor_balances',
]
for rpc in target_rpcs:
    r = sql(f"SELECT COUNT(*) as cnt FROM information_schema.routines WHERE routine_name='{rpc}'", f"RPC {rpc}")
    cnt = r[0]['cnt'] if isinstance(r, list) and r else -1
    results[f"rpc_{rpc}"] = cnt

# 5. Vérifier la structure exacte de app_confirm_ligdicash_payment (pour savoir comment la modifier)
print("\n--- 5. app_confirm_ligdicash_payment params ---")
results["confirm_rpc_params"] = sql("""
SELECT p.proname, pg_get_function_arguments(p.oid) as args
FROM pg_proc p WHERE p.proname = 'app_confirm_ligdicash_payment' LIMIT 1
""", "confirm_ligdicash params")

# 6. Vérifier FK et contraintes sur instructors et td_teachers
print("\n--- 6. FK instructors/td_teachers ---")
results["fk_instructors"] = sql("""
SELECT tc.constraint_name, kcu.column_name, ccu.table_name as ref_table, ccu.column_name as ref_col
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'instructors' AND tc.table_schema = 'app'
ORDER BY tc.constraint_type
""", "FK instructors")

results["fk_td_teachers"] = sql("""
SELECT tc.constraint_name, kcu.column_name, ccu.table_name as ref_table, ccu.column_name as ref_col
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'td_teachers' AND tc.table_schema = 'app'
ORDER BY tc.constraint_type
""", "FK td_teachers")

# 7. RLS status sur instructors et td_teachers
print("\n--- 7. RLS ---")
results["rls_actors"] = sql("""
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname='app' AND tablename IN ('instructors', 'td_teachers', 'marketplace_merchants', 'universities')
""", "RLS actors")

# 8. Données existantes
print("\n--- 8. Données ---")
for tbl in ['instructors', 'td_teachers', 'marketplace_merchants', 'universities', 'commercial_profiles']:
    r = sql(f"SELECT COUNT(*) as cnt FROM app.{tbl}", f"count {tbl}")
    results[f"count_{tbl}"] = r

# 9. Schema de marketplace_merchant_balances (pour décider si on la garde ou remplace par actor_balances)
print("\n--- 9. marketplace_merchant_balances ---")
results["mmb_data"] = sql("SELECT COUNT(*) as cnt FROM app.marketplace_merchant_balances", "mmb count")

# 10. Vérifier les payment_reason enum values actuelles
print("\n--- 10. payment_reason enum ---")
results["payment_reason_enum"] = sql("""
SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid=t.oid
WHERE t.typname='payment_reason' ORDER BY e.enumsortorder
""", "payment_reason enum")

output_path = Path(__file__).parent / "logs" / "audit_phase8a_pre_impl.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\n[SAVED] {output_path}")
