#!/usr/bin/env python3
"""Audit v2 — marketplace payments, commissions, subscriptions, commercial system, TD payments."""

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

print("=" * 72)
print("AUDIT PAIEMENTS V2 — MARKETPLACE, COMMISSIONS, TD, ABONNEMENTS")
print("=" * 72)

# 1. marketplace_payments columns
print("\n--- 1. marketplace_payments ---")
results["marketplace_payments_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'marketplace_payments'
ORDER BY table_schema, ordinal_position
""", "marketplace_payments cols")

# 2. marketplace_orders columns
print("\n--- 2. marketplace_orders ---")
results["marketplace_orders_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'marketplace_orders'
ORDER BY table_schema, ordinal_position
""", "marketplace_orders cols")

# 3. marketplace_order_items columns
print("\n--- 3. marketplace_order_items ---")
results["marketplace_order_items_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'marketplace_order_items'
ORDER BY table_schema, ordinal_position
""", "marketplace_order_items cols")

# 4. commercial tables
print("\n--- 4. commercial tables ---")
results["commercial_tables"] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE '%commercial%'
   OR table_name ILIKE '%referral%'
   OR table_name ILIKE '%commission%'
   OR table_name ILIKE '%milestone%'
ORDER BY table_schema, table_name
""", "commercial/referral/commission tables")

# 5. referral_commissions columns
print("\n--- 5. referral_commissions ---")
results["referral_commissions_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'referral_commissions'
ORDER BY table_schema, ordinal_position
""", "referral_commissions cols")

# 6. commercial_profiles columns
print("\n--- 6. commercial_profiles ---")
results["commercial_profiles_cols"] = sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'commercial_profiles'
ORDER BY table_schema, ordinal_position
""", "commercial_profiles cols")

# 7. subscription/abonnement tables
print("\n--- 7. subscription tables ---")
results["subscription_tables"] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE '%subscription%'
   OR table_name ILIKE '%abonnement%'
   OR table_name ILIKE '%plan%'
ORDER BY table_schema, table_name
""", "subscription/plan tables")

# 8. TD payment flow
print("\n--- 8. TD enrollment payment ---")
results["td_enrollment_payment_rpc"] = sql("""
SELECT routine_name
FROM information_schema.routines
WHERE routine_name ILIKE '%td%payment%'
   OR routine_name ILIKE '%td%enroll%'
ORDER BY routine_name
""", "TD payment RPCs")

# 9. All marketplace RPCs
print("\n--- 9. marketplace RPCs ---")
results["marketplace_rpcs"] = sql("""
SELECT routine_name
FROM information_schema.routines
WHERE routine_name ILIKE '%marketplace%'
ORDER BY routine_name
""", "marketplace RPCs")

# 10. marketplace_payments data
print("\n--- 10. marketplace_payments data ---")
results["marketplace_payments_data"] = sql("""
SELECT COUNT(*) as total FROM app.marketplace_payments
""", "marketplace payments count")

# 11. marketplace_orders data
print("\n--- 11. marketplace_orders data ---")
results["marketplace_orders_data"] = sql("""
SELECT COUNT(*) as total FROM app.marketplace_orders
""", "marketplace orders count")

# 12. Enum payment_channel values
print("\n--- 12. payment_channel enum ---")
results["payment_channel_enum"] = sql("""
SELECT e.enumlabel
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'payment_channel'
ORDER BY e.enumsortorder
""", "payment_channel enum values")

# 13. Enum payment_status values
print("\n--- 13. payment_status enum ---")
results["payment_status_enum"] = sql("""
SELECT e.enumlabel
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'payment_status'
ORDER BY e.enumsortorder
""", "payment_status enum values")

# 14. Enum payment_reason values
print("\n--- 14. payment_reason enum ---")
results["payment_reason_enum"] = sql("""
SELECT e.enumlabel
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'payment_reason'
ORDER BY e.enumsortorder
""", "payment_reason enum values")

# 15. commission_rules data
print("\n--- 15. commission_rules ---")
results["commission_rules_data"] = sql("""
SELECT id, payment_reason, degree_level, commission_rate, max_amount, currency, is_active, priority
FROM app.commission_rules
ORDER BY priority DESC, payment_reason
""", "commission rules")

# 16. commercial_milestones
print("\n--- 16. commercial_milestones ---")
results["commercial_milestones"] = sql("""
SELECT * FROM app.commercial_milestones ORDER BY threshold
""", "commercial milestones")

# 17. marketplace_process_payment RPC source
print("\n--- 17. marketplace_process_payment source ---")
results["marketplace_process_payment_src"] = sql("""
SELECT p.proname, pg_get_functiondef(p.oid) as func_def
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_marketplace_process_payment'
LIMIT 1
""", "marketplace_process_payment source")

# 18. td enrollment payment RPC source
print("\n--- 18. td_enrollment_payment source ---")
results["td_enrollment_payment_src"] = sql("""
SELECT p.proname, pg_get_functiondef(p.oid) as func_def
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_td_student_create_enrollment_and_payment'
LIMIT 1
""", "td_enrollment_payment source")

# 19. All payout/withdrawal related
print("\n--- 19. payout/withdrawal tables ---")
results["payout_tables"] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE '%payout%'
   OR table_name ILIKE '%withdrawal%'
   OR table_name ILIKE '%disbursement%'
ORDER BY table_schema, table_name
""", "payout/withdrawal tables")

# 20. marketplace_listings columns (for merchant revenue context)
print("\n--- 20. marketplace_listings price cols ---")
results["marketplace_listings_price"] = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'marketplace_listings' AND column_name ILIKE '%price%'
ORDER BY ordinal_position
""", "marketplace_listings price cols")

# Save
print("\n" + "=" * 72)
output_path = Path(__file__).parent / "logs" / "audit_payments_v2.json"
output_path.parent.mkdir(parents=True, exist_ok=True)
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
