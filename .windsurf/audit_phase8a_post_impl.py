#!/usr/bin/env python3
"""Audit Phase 8A post-implémentation."""
import json
from pathlib import Path
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()
results = {}
errors = []

def sql(q, label=""):
    try:
        r = m.execute_sql_auto(q)
        if r.get("success"):
            d = r.get("data") or []
            if label: print(f"[OK] {label}: {len(d) if isinstance(d, list) else 'ok'}")
            return d
        else:
            e = r.get("error","?")
            if label: print(f"[ERR] {label}: {e[:150]}")
            errors.append(f"{label}: {e[:100]}")
            return {"error": e}
    except Exception as e:
        if label: print(f"[EXC] {label}: {e}")
        errors.append(f"{label}: {str(e)[:100]}")
        return {"error": str(e)}

print("VÉRIFICATION POST-IMPLÉMENTATION PHASE 8A")

# 1. Tables
for t in ['revenue_split_rules', 'actor_balances']:
    r = sql(f"SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"table {t}")
    if isinstance(r, list) and r and r[0]['cnt'] == 0: errors.append(f"TABLE MANQUANTE: {t}")

# 2. Seed data
r = sql("SELECT payment_reason, beneficiary_type, percentage FROM app.revenue_split_rules ORDER BY payment_reason, beneficiary_type", "seed rules")
results["seed_rules"] = r
if isinstance(r, list): print(f"  {len(r)} règles de split")

# 3. Colonnes ajoutées
for tbl, cols in [('instructors',['phone','payout_phone','payout_operator','speciality']),
                  ('td_teachers',['phone','payout_phone','payout_operator']),
                  ('marketplace_merchants',['payout_phone','payout_operator']),
                  ('universities',['payout_phone','payout_operator','bank_name','bank_account'])]:
    existing = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{tbl}'")
    names = [c['column_name'] for c in existing] if isinstance(existing, list) else []
    for col in cols:
        if col in names: print(f"  ✓ {tbl}.{col}")
        else: print(f"  ✗ {tbl}.{col} MANQUANT"); errors.append(f"COL MANQUANTE: {tbl}.{col}")

# 4. RPCs
for rpc in ['app_admin_list_revenue_split_rules','app_admin_upsert_revenue_split_rule','app_admin_delete_revenue_split_rule',
            'app_admin_validate_split_totals','app_resolve_revenue_split','app_instructor_get_my_balance',
            'app_instructor_request_payout','app_university_get_balance','app_university_request_payout','app_admin_list_actor_balances']:
    r = sql(f"SELECT COUNT(*) as cnt FROM information_schema.routines WHERE routine_name='{rpc}'")
    cnt = r[0]['cnt'] if isinstance(r, list) and r else 0
    if cnt > 0: print(f"  ✓ {rpc}")
    else: print(f"  ✗ {rpc} MANQUANTE"); errors.append(f"RPC MANQUANTE: {rpc}")

# 5. RLS
r = sql("SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname='app' AND tablename IN ('revenue_split_rules','actor_balances')", "RLS")
if isinstance(r, list):
    for row in r: print(f"  {'✓' if row.get('rowsecurity') else '✗'} RLS {row['tablename']}")

# 6. Validation split totals
r = sql("SELECT payment_reason, ROUND(SUM(percentage),4) as total FROM app.revenue_split_rules WHERE is_active=TRUE GROUP BY payment_reason ORDER BY payment_reason", "split totals")
if isinstance(r, list):
    for row in r:
        ok = abs(float(row['total']) - 1.0) < 0.01
        print(f"  {'✅' if ok else '⚠️'} {row['payment_reason']}: {row['total']}")
        if not ok: errors.append(f"SPLIT TOTAL != 100%: {row['payment_reason']}={row['total']}")

print("\n" + "=" * 40)
if errors: print(f"⚠️ {len(errors)} ERREUR(S)")
else: print("✅ TOUT EST OK")

output_path = Path(__file__).parent / "logs" / "audit_phase8a_post_impl.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump({"errors": errors, "seed_rules": results.get("seed_rules")}, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
