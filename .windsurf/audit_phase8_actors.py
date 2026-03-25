#!/usr/bin/env python3
"""Audit Phase 8 — Infos de profil par acteur + colonnes paiement existantes."""

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

print("AUDIT PHASE 8 — PROFILS ACTEURS + INFOS PAIEMENT")
print("=" * 60)

# 1. students columns (phone, email, etc)
print("\n--- 1. students ---")
results["students_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='students' ORDER BY ordinal_position
""", "students cols")

# 2. commercial_profiles columns
print("\n--- 2. commercial_profiles ---")
results["commercial_profiles_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='commercial_profiles' ORDER BY ordinal_position
""", "commercial_profiles cols")

# 3. marketplace_merchants columns
print("\n--- 3. marketplace_merchants ---")
results["marketplace_merchants_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='marketplace_merchants' ORDER BY ordinal_position
""", "marketplace_merchants cols")

# 4. universities columns
print("\n--- 4. universities ---")
results["universities_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='universities' ORDER BY ordinal_position
""", "universities cols")

# 5. instructors / td_teachers columns
print("\n--- 5. instructors ---")
results["instructors_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='instructors' ORDER BY ordinal_position
""", "instructors cols")

print("\n--- 6. td_teachers ---")
results["td_teachers_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='td_teachers' ORDER BY ordinal_position
""", "td_teachers cols")

# 7. commission_rules columns
print("\n--- 7. commission_rules ---")
results["commission_rules_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='commission_rules' ORDER BY ordinal_position
""", "commission_rules cols")

# 8. Existe-t-il une table revenue_split_rules ?
print("\n--- 8. revenue_split_rules existe ? ---")
results["revenue_split_exists"] = sql("""
SELECT COUNT(*) as cnt FROM information_schema.tables
WHERE table_schema='app' AND table_name='revenue_split_rules'
""", "revenue_split_rules")

# 9. marketplace_merchant_balances colonnes
print("\n--- 9. marketplace_merchant_balances ---")
results["merchant_balances_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='marketplace_merchant_balances' ORDER BY ordinal_position
""", "marketplace_merchant_balances cols")

# 10. payout_queue colonnes (vérifier ce qu'on a)
print("\n--- 10. payout_queue ---")
results["payout_queue_cols"] = sql("""
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='app' AND table_name='payout_queue' ORDER BY ordinal_position
""", "payout_queue cols")

# 11. Vérifier auth.users metadata (role, phone, etc)
print("\n--- 11. Sample auth.users metadata ---")
results["auth_users_sample"] = sql("""
SELECT id, email, phone, raw_user_meta_data->>'role' as role,
       raw_user_meta_data->>'full_name' as full_name
FROM auth.users LIMIT 10
""", "auth.users sample")

# 12. marketplace_process_payment source (vérifier le 10% hardcodé)
print("\n--- 12. marketplace commission rate hardcodé ---")
results["marketplace_commission_src"] = sql("""
SELECT pg_get_functiondef(p.oid) as func_def
FROM pg_proc p WHERE p.proname = 'app_marketplace_process_payment' LIMIT 1
""", "marketplace_process_payment source")

output_path = Path(__file__).parent / "logs" / "audit_phase8_actors.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\n[SAVED] {output_path}")
