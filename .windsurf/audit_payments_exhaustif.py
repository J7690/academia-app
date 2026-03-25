#!/usr/bin/env python3
"""Audit EXHAUSTIF — toutes les tables/RPCs/enums/triggers/RLS liés à l'argent, commissions, paiements, marketplace, abonnements, TD."""

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
                cnt = len(data) if isinstance(data, list) else 'ok'
                print(f"[OK] {label}: {cnt}")
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
print("AUDIT EXHAUSTIF FINANCIER SUPABASE")
print("=" * 72)

# 1. TOUTES les tables contenant des mots liés à l'argent
print("\n--- 1. TOUTES LES TABLES FINANCIÈRES ---")
results["all_financial_tables"] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('app','public')
  AND (table_name ILIKE '%payment%'
    OR table_name ILIKE '%receipt%'
    OR table_name ILIKE '%commission%'
    OR table_name ILIKE '%referral%'
    OR table_name ILIKE '%commercial%'
    OR table_name ILIKE '%milestone%'
    OR table_name ILIKE '%marketplace%'
    OR table_name ILIKE '%order%'
    OR table_name ILIKE '%invoice%'
    OR table_name ILIKE '%billing%'
    OR table_name ILIKE '%subscription%'
    OR table_name ILIKE '%payout%'
    OR table_name ILIKE '%withdrawal%'
    OR table_name ILIKE '%escrow%'
    OR table_name ILIKE '%ledger%'
    OR table_name ILIKE '%transaction%'
    OR table_name ILIKE '%price%'
    OR table_name ILIKE '%fee%'
    OR table_name ILIKE '%revenue%'
    OR table_name ILIKE '%wallet%'
    OR table_name ILIKE '%enroll%'
    OR table_name ILIKE '%access%'
    OR table_name ILIKE '%cart%')
ORDER BY table_schema, table_name
""", "all financial tables")

# 2. TOUS les enums liés aux paiements
print("\n--- 2. TOUS LES ENUMS FINANCIERS ---")
results["all_payment_enums"] = sql("""
SELECT t.typname AS enum_name,
       ARRAY_AGG(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname ILIKE '%payment%'
   OR t.typname ILIKE '%channel%'
   OR t.typname ILIKE '%status%'
   OR t.typname ILIKE '%reason%'
   OR t.typname ILIKE '%order%'
GROUP BY t.typname
ORDER BY t.typname
""", "all payment enums")

# 3. TOUTES les RPCs qui touchent à l'argent
print("\n--- 3. TOUTES LES RPCs FINANCIÈRES ---")
results["all_financial_rpcs"] = sql("""
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_type = 'FUNCTION'
  AND (routine_name ILIKE '%payment%'
    OR routine_name ILIKE '%receipt%'
    OR routine_name ILIKE '%commission%'
    OR routine_name ILIKE '%referral%'
    OR routine_name ILIKE '%commercial%'
    OR routine_name ILIKE '%milestone%'
    OR routine_name ILIKE '%marketplace%'
    OR routine_name ILIKE '%order%'
    OR routine_name ILIKE '%payout%'
    OR routine_name ILIKE '%escrow%'
    OR routine_name ILIKE '%enroll%'
    OR routine_name ILIKE '%subscription%'
    OR routine_name ILIKE '%ledger%'
    OR routine_name ILIKE '%wallet%'
    OR routine_name ILIKE '%withdraw%'
    OR routine_name ILIKE '%invoice%')
ORDER BY routine_name
""", "all financial RPCs")

# 4. TOUS les triggers sur tables financières
print("\n--- 4. TOUS LES TRIGGERS FINANCIERS ---")
results["all_financial_triggers"] = sql("""
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table IN (
  'application_payments', 'payment_receipts', 'payment_proofs',
  'marketplace_payments', 'marketplace_orders', 'marketplace_order_items',
  'referral_commissions', 'commission_rules', 'commercial_profiles',
  'commercial_milestone_claims', 'commercial_milestones',
  'td_enrollments', 'user_referrals'
)
ORDER BY event_object_table, trigger_name
""", "all financial triggers")

# 5. TOUTES les RLS policies sur tables financières
print("\n--- 5. TOUTES LES RLS POLICIES FINANCIÈRES ---")
results["all_financial_rls"] = sql("""
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename IN (
  'application_payments', 'payment_receipts', 'payment_proofs',
  'marketplace_payments', 'marketplace_orders', 'marketplace_order_items',
  'referral_commissions', 'commission_rules', 'commercial_profiles',
  'commercial_milestone_claims', 'commercial_milestones',
  'td_enrollments', 'user_referrals', 'marketplace_listings'
)
ORDER BY tablename, policyname
""", "all financial RLS")

# 6. td_enrollments columns (pour comprendre le flow TD payment)
print("\n--- 6. td_enrollments ---")
results["td_enrollments_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'td_enrollments'
ORDER BY table_schema, ordinal_position
""", "td_enrollments cols")

# 7. Vérifier si des tables ont des colonnes "price", "amount", "fee", "cost"
print("\n--- 7. COLONNES MONTANT DANS TOUTES LES TABLES ---")
results["amount_columns"] = sql("""
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
  AND (column_name ILIKE '%price%'
    OR column_name ILIKE '%amount%'
    OR column_name ILIKE '%fee%'
    OR column_name ILIKE '%cost%'
    OR column_name ILIKE '%commission%'
    OR column_name ILIKE '%revenue%')
ORDER BY table_name, column_name
""", "all amount/price columns in app schema")

# 8. marketplace_listings columns (prix des produits)
print("\n--- 8. marketplace_listings ---")
results["marketplace_listings_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'marketplace_listings'
ORDER BY ordinal_position
""", "marketplace_listings cols")

# 9. Vérifier s'il y a des tables cart
print("\n--- 9. cart tables ---")
results["cart_tables"] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE '%cart%'
  AND table_schema IN ('app','public')
ORDER BY table_name
""", "cart tables")

# 10. cart_items columns si existe
print("\n--- 10. marketplace_cart_items ---")
results["cart_items_cols"] = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'marketplace_cart_items'
ORDER BY table_schema, ordinal_position
""", "marketplace_cart_items cols")

# 11. Vérifier les FK entre marketplace_payments et orders
print("\n--- 11. marketplace FK ---")
results["marketplace_fk"] = sql("""
SELECT tc.constraint_name, tc.table_name, kcu.column_name,
       ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN ('marketplace_payments','marketplace_orders','marketplace_order_items','marketplace_cart_items')
ORDER BY tc.table_name
""", "marketplace FK")

# 12. Données: referral_commissions existantes
print("\n--- 12. referral_commissions data ---")
results["referral_commissions_data"] = sql("""
SELECT status, COUNT(*) as cnt, SUM(commission_amount) as total_amount
FROM app.referral_commissions
GROUP BY status
ORDER BY status
""", "referral commissions data")

# 13. Données: commercial_profiles existants
print("\n--- 13. commercial_profiles data ---")
results["commercial_profiles_data"] = sql("""
SELECT tier, COUNT(*) as cnt, is_active
FROM app.commercial_profiles
GROUP BY tier, is_active
ORDER BY tier
""", "commercial profiles data")

# 14. user_referrals columns
print("\n--- 14. user_referrals ---")
results["user_referrals_cols"] = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'user_referrals'
ORDER BY ordinal_position
""", "user_referrals cols")

# 15. Données: user_referrals count
print("\n--- 15. user_referrals data ---")
results["user_referrals_data"] = sql("""
SELECT COUNT(*) as total FROM app.user_referrals
""", "user_referrals count")

# 16. td_programs price columns
print("\n--- 16. td_programs price ---")
results["td_programs_price"] = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'td_programs'
  AND (column_name ILIKE '%price%' OR column_name ILIKE '%fee%' OR column_name ILIKE '%amount%' OR column_name ILIKE '%cost%')
ORDER BY ordinal_position
""", "td_programs price cols")

# 17. programs (candidatures) price columns
print("\n--- 17. programs fee columns ---")
results["programs_fee"] = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'programs'
  AND (column_name ILIKE '%price%' OR column_name ILIKE '%fee%' OR column_name ILIKE '%amount%' OR column_name ILIKE '%cost%' OR column_name ILIKE '%tuition%')
ORDER BY ordinal_position
""", "programs fee cols")

# 18. fn_resolve_commission_rate source
print("\n--- 18. fn_resolve_commission_rate ---")
results["fn_resolve_commission_rate"] = sql("""
SELECT p.proname, pg_get_functiondef(p.oid) as func_def
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_resolve_commission_rate'
LIMIT 1
""", "fn_resolve_commission_rate")

# 19. fn_check_commission_cap source
print("\n--- 19. fn_check_commission_cap ---")
results["fn_check_commission_cap"] = sql("""
SELECT p.proname, pg_get_functiondef(p.oid) as func_def
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'fn_check_commission_cap'
LIMIT 1
""", "fn_check_commission_cap")

# 20. marketplace_release_escrow source
print("\n--- 20. marketplace_release_escrow ---")
results["marketplace_release_escrow"] = sql("""
SELECT p.proname, pg_get_functiondef(p.oid) as func_def
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_marketplace_release_escrow'
LIMIT 1
""", "marketplace_release_escrow")

# Save
print("\n" + "=" * 72)
output_path = Path(__file__).parent / "logs" / "audit_payments_exhaustif.json"
output_path.parent.mkdir(parents=True, exist_ok=True)
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
print("AUDIT EXHAUSTIF TERMINE")
