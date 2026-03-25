#!/usr/bin/env python3
"""Audit Phase 4 pré-implémentation — Vérifier tables subscriptions + plans + RPC."""

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

print("AUDIT PHASE 4 — PRÉ-IMPLÉMENTATION")

# 1. subscription_plans data
results["plans"] = sql("SELECT code, name, price, duration_days, features, is_active, promo_percent FROM app.subscription_plans ORDER BY price", "subscription_plans")

# 2. subscriptions table columns
results["sub_cols"] = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='subscriptions' ORDER BY ordinal_position", "subscriptions cols")

# 3. RPC app_student_check_subscription exists
results["rpc_check"] = sql("SELECT COUNT(*) as cnt FROM information_schema.routines WHERE routine_name='app_student_check_subscription'", "RPC check_subscription")

# 4. Any existing subscriptions
results["sub_count"] = sql("SELECT COUNT(*) as cnt FROM app.subscriptions", "subscriptions count")

print("\n" + "=" * 40)
output_path = Path(__file__).parent / "logs" / "audit_phase4_pre_impl.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"[SAVED] {output_path}")
