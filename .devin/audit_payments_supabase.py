#!/usr/bin/env python3
"""Audit complet du module Paiements dans Supabase (tables, colonnes, RPCs, RLS, données)."""

import json
from pathlib import Path
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()
results = {}

def sql(query, label=""):
    """Execute SQL via execute_sql RPC and return result."""
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

print("=" * 72)
print("AUDIT PAIEMENTS SUPABASE")
print("=" * 72)

# 1. Tables liées aux paiements
print("\n--- 1. TABLES PAIEMENT ---")
results["tables"] = sql("""
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name ILIKE '%payment%' 
   OR table_name ILIKE '%receipt%'
   OR table_name ILIKE '%transaction%'
   OR table_name ILIKE '%invoice%'
   OR table_name ILIKE '%billing%'
   OR table_name ILIKE '%paiement%'
ORDER BY table_schema, table_name
""", "Tables paiement")

# 2. Colonnes de application_payments
print("\n--- 2. COLONNES application_payments ---")
results["application_payments_columns"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'application_payments'
ORDER BY ordinal_position
""", "Colonnes application_payments")

# 3. Colonnes de payment_receipts
print("\n--- 3. COLONNES payment_receipts ---")
results["payment_receipts_columns"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'payment_receipts'
ORDER BY ordinal_position
""", "Colonnes payment_receipts")

# 4. Colonnes de payment_proofs (si existe)
print("\n--- 4. COLONNES payment_proofs ---")
results["payment_proofs_columns"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'payment_proofs'
ORDER BY table_schema, ordinal_position
""", "Colonnes payment_proofs")

# 5. RPCs liées aux paiements
print("\n--- 5. RPCs PAIEMENT ---")
results["payment_rpcs"] = sql("""
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_type = 'FUNCTION'
  AND (routine_name ILIKE '%payment%' 
    OR routine_name ILIKE '%receipt%'
    OR routine_name ILIKE '%confirm_payment%'
    OR routine_name ILIKE '%declare_payment%'
    OR routine_name ILIKE '%verify_payment%')
ORDER BY routine_name
""", "RPCs paiement")

# 6. Code source des RPCs clés
print("\n--- 6. CODE SOURCE RPCs CLES ---")
key_rpcs = [
    'app_student_declare_payment',
    'app_create_application_payment',
    'app_student_create_profile_payment',
    'app_admin_verify_payment',
    'app_admin_confirm_payment',
    'app_admin_get_payment_detail',
    'app_admin_list_payments_with_context',
    'app_admin_list_payment_receipts_with_context',
    'app_university_list_payments',
]
results["rpc_sources"] = {}
for rpc_name in key_rpcs:
    src = sql(f"""
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_name = '{rpc_name}'
    LIMIT 1
    """, f"Source {rpc_name}")
    results["rpc_sources"][rpc_name] = src

# 7. RLS policies sur application_payments
print("\n--- 7. RLS POLICIES ---")
results["rls_policies"] = sql("""
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('application_payments', 'payment_receipts', 'payment_proofs')
ORDER BY tablename, policyname
""", "RLS policies paiement")

# 8. Statuts de paiement distincts
print("\n--- 8. STATUTS DISTINCTS ---")
results["distinct_statuses"] = sql("""
SELECT DISTINCT status, COUNT(*) as cnt
FROM app.application_payments
GROUP BY status
ORDER BY cnt DESC
""", "Statuts distincts")

# 9. Payment reasons distincts
print("\n--- 9. PAYMENT REASONS ---")
results["distinct_reasons"] = sql("""
SELECT DISTINCT payment_reason, COUNT(*) as cnt
FROM app.application_payments
GROUP BY payment_reason
ORDER BY cnt DESC
""", "Reasons distincts")

# 10. Channels distincts
print("\n--- 10. CHANNELS ---")
results["distinct_channels"] = sql("""
SELECT DISTINCT channel, COUNT(*) as cnt
FROM app.application_payments
GROUP BY channel
ORDER BY cnt DESC
""", "Channels distincts")

# 11. Nombre total de paiements et recus
print("\n--- 11. COMPTEURS ---")
results["counts"] = sql("""
SELECT 
  (SELECT COUNT(*) FROM app.application_payments) AS total_payments,
  (SELECT COUNT(*) FROM app.payment_receipts) AS total_receipts
""", "Compteurs")

# 12. Contraintes et index
print("\n--- 12. CONTRAINTES ---")
results["constraints"] = sql("""
SELECT tc.constraint_name, tc.constraint_type, tc.table_name, kcu.column_name,
       ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name IN ('application_payments', 'payment_receipts', 'payment_proofs')
ORDER BY tc.table_name, tc.constraint_type
""", "Contraintes")

# 13. Triggers sur les tables paiement
print("\n--- 13. TRIGGERS ---")
results["triggers"] = sql("""
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('application_payments', 'payment_receipts', 'payment_proofs')
ORDER BY event_object_table, trigger_name
""", "Triggers")

# 14. Indexes
print("\n--- 14. INDEX ---")
results["indexes"] = sql("""
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE tablename IN ('application_payments', 'payment_receipts', 'payment_proofs')
ORDER BY tablename, indexname
""", "Indexes")

# 15. Sample data (5 derniers paiements)
print("\n--- 15. SAMPLE DATA (5 derniers) ---")
results["sample_payments"] = sql("""
SELECT id, student_id, application_id, payment_reason, status, amount_due, amount_paid, 
       currency, channel, reference_code, external_reference, created_at, declared_at, 
       verified_at, confirmed_at
FROM app.application_payments
ORDER BY created_at DESC
LIMIT 5
""", "Sample payments")

# 16. Vérifier RPC bodies via pg_proc (plus fiable)
print("\n--- 16. RPC BODIES (pg_proc) ---")
results["rpc_bodies"] = {}
for rpc_name in key_rpcs:
    body = sql(f"""
    SELECT p.proname, pg_get_functiondef(p.oid) as func_def
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = '{rpc_name}'
    LIMIT 1
    """, f"Body {rpc_name}")
    results["rpc_bodies"][rpc_name] = body

# Save results
print("\n" + "=" * 72)
output_path = Path(__file__).parent / "logs" / "audit_payments_supabase.json"
output_path.parent.mkdir(parents=True, exist_ok=True)
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
print("AUDIT TERMINE")
