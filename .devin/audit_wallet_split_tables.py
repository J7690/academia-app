#!/usr/bin/env python3
"""Audit: vérifie l'existence des tables et RPCs wallet/split/abonnements sur Supabase."""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def execute_sql(sql):
    """Execute SQL via execute_sql RPC."""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=15,
    )
    if r.status_code == 200:
        return r.json()
    # Try execute_ddl
    r2 = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": sql},
        timeout=15,
    )
    if r2.status_code == 200:
        return r2.json()
    return {"error": r.status_code, "text": r.text[:300]}

def main():
    print("=" * 70)
    print("AUDIT WALLET / SPLIT / ABONNEMENTS — Supabase")
    print("=" * 70)

    # 1. Vérifier les tables
    tables_to_check = [
        "revenue_split_rules",
        "actor_balances",
        "subscription_plans",
        "subscriptions",
        "payout_queue",
        "platform_ledger",
        "referral_commissions",
        "commission_rules",
        "commercial_profiles",
        "user_referrals",
    ]

    print("\n--- TABLES (schema app) ---")
    result = execute_sql("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'app' 
        AND table_name IN ('revenue_split_rules','actor_balances','subscription_plans',
            'subscriptions','payout_queue','platform_ledger','referral_commissions',
            'commission_rules','commercial_profiles','user_referrals')
        ORDER BY table_name
    """)
    if isinstance(result, list):
        found_tables = [r.get("table_name", r) for r in result]
        for t in tables_to_check:
            status = "✅ EXISTE" if t in found_tables else "❌ MANQUE"
            print(f"  {status} : app.{t}")
    else:
        print(f"  Erreur SQL: {result}")

    # 2. Vérifier les RPCs
    rpcs_to_check = [
        "app_confirm_ligdicash_payment",
        "app_student_check_subscription",
        "app_admin_list_revenue_split_rules",
        "app_admin_upsert_revenue_split_rule",
        "app_admin_delete_revenue_split_rule",
        "app_admin_validate_split_totals",
        "app_resolve_revenue_split",
        "app_instructor_get_my_balance",
        "app_instructor_request_payout",
        "app_university_get_balance",
        "app_university_request_payout",
        "app_admin_list_actor_balances",
        "app_commercial_request_payout",
        "app_merchant_request_payout",
        "app_admin_list_payout_queue",
        "app_admin_get_treasury_summary",
        "app_admin_list_ledger",
        "app_admin_manage_subscription_plan",
        "app_admin_list_subscriptions",
    ]

    print("\n--- RPCs (toutes schemas) ---")
    result = execute_sql("""
        SELECT routine_name 
        FROM information_schema.routines 
        WHERE routine_type = 'FUNCTION'
        AND routine_schema IN ('public', 'app')
        AND routine_name LIKE 'app_%'
        AND routine_name IN (
            'app_confirm_ligdicash_payment',
            'app_student_check_subscription',
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
            'app_commercial_request_payout',
            'app_merchant_request_payout',
            'app_admin_list_payout_queue',
            'app_admin_get_treasury_summary',
            'app_admin_list_ledger',
            'app_admin_manage_subscription_plan',
            'app_admin_list_subscriptions'
        )
        ORDER BY routine_name
    """)
    if isinstance(result, list):
        found_rpcs = [r.get("routine_name", r) for r in result]
        for rpc in rpcs_to_check:
            status = "✅ EXISTE" if rpc in found_rpcs else "❌ MANQUE"
            print(f"  {status} : {rpc}")
    else:
        print(f"  Erreur SQL: {result}")

    # 3. Vérifier les données seed dans subscription_plans
    print("\n--- SEED DATA : subscription_plans ---")
    result = execute_sql("SELECT code, name, price, duration_days, is_active FROM app.subscription_plans ORDER BY price")
    if isinstance(result, list):
        if len(result) == 0:
            print("  ❌ TABLE VIDE — aucun plan d'abonnement")
        for r in result:
            print(f"  {r}")
    else:
        print(f"  {result}")

    # 4. Vérifier les données seed dans revenue_split_rules
    print("\n--- SEED DATA : revenue_split_rules ---")
    result = execute_sql("SELECT payment_reason, beneficiary_type, percentage, is_active FROM app.revenue_split_rules ORDER BY payment_reason, beneficiary_type")
    if isinstance(result, list):
        if len(result) == 0:
            print("  ❌ TABLE VIDE — aucune règle de répartition")
        for r in result:
            print(f"  {r}")
    else:
        print(f"  {result}")

    # 5. Vérifier actor_balances
    print("\n--- DATA : actor_balances ---")
    result = execute_sql("SELECT actor_type, COUNT(*) as cnt, SUM(available_balance) as total_available FROM app.actor_balances GROUP BY actor_type ORDER BY actor_type")
    if isinstance(result, list):
        if len(result) == 0:
            print("  (vide — aucun solde acteur créé)")
        for r in result:
            print(f"  {r}")
    else:
        print(f"  {result}")

    # 6. Vérifier pg_cron jobs
    print("\n--- PG_CRON JOBS ---")
    result = execute_sql("SELECT jobid, schedule, command FROM cron.job ORDER BY jobid")
    if isinstance(result, list):
        for r in result:
            print(f"  Job #{r.get('jobid')}: {r.get('schedule')} → {r.get('command','')[:100]}")
    else:
        print(f"  {result}")

    # 7. Vérifier si app_confirm_ligdicash_payment fait le split
    print("\n--- CONTENU RPC app_confirm_ligdicash_payment (cherche 'actor_balances' ou 'revenue_split') ---")
    result = execute_sql("""
        SELECT prosrc 
        FROM pg_proc 
        WHERE proname = 'app_confirm_ligdicash_payment'
        LIMIT 1
    """)
    if isinstance(result, list) and len(result) > 0:
        src = str(result[0].get("prosrc", ""))
        has_actor = "actor_balances" in src
        has_split = "revenue_split" in src
        print(f"  Contient 'actor_balances': {'✅ OUI' if has_actor else '❌ NON'}")
        print(f"  Contient 'revenue_split': {'✅ OUI' if has_split else '❌ NON'}")
        if not has_actor and not has_split:
            print("  ⚠️ PROBLÈME CRITIQUE: La RPC ne fait PAS le split vers les acteurs!")
    else:
        print(f"  RPC non trouvée ou erreur: {result}")

    print("\n" + "=" * 70)
    print("FIN AUDIT")
    print("=" * 70)


if __name__ == "__main__":
    main()
