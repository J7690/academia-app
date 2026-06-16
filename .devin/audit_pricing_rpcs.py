#!/usr/bin/env python3
"""Audit ciblé: RPCs admin existantes pour la tarification, colonnes manquantes."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:200]}

print("=" * 70)
print("AUDIT RPCS PRICING EXISTANTES")
print("=" * 70)

# All admin RPCs that touch pricing-related tables
targets = [
    # Credit packs
    "app_admin_list_credit_packs", "app_admin_update_credit_pack", "app_admin_create_credit_pack",
    "app_admin_delete_credit_pack", "app_admin_upsert_credit_pack",
    # Subscription plans
    "app_admin_list_subscription_plans", "app_admin_update_subscription_plan",
    "app_admin_create_subscription_plan", "app_admin_upsert_subscription_plan",
    # Programs / university fees
    "app_admin_list_programs", "app_admin_update_program", "app_admin_create_program",
    "app_admin_update_program_fees", "app_admin_set_program_fees",
    # TD pricing
    "app_admin_update_td_price", "app_admin_update_td_program", "app_admin_list_td_programs",
    "app_admin_update_td_local_group",
    # Short training pricing
    "app_admin_update_short_training_session", "app_admin_update_short_training_price",
    "app_admin_list_short_training_sessions_with_price",
    # Action prices (credit costs per action)
    "app_admin_list_action_prices", "app_admin_update_action_price", "app_admin_upsert_action_price",
]

print("\n--- Checking specific RPCs ---")
exists = []
missing = []
for rpc in targets:
    r = sql(f"SELECT 1 FROM pg_proc WHERE proname = '{rpc}' LIMIT 1")
    if isinstance(r, list) and len(r) > 0:
        exists.append(rpc)
        print(f"  EXISTS : {rpc}")
    else:
        missing.append(rpc)
        print(f"  MISSING: {rpc}")

# Also scan all admin RPCs that contain 'update' and price/amount keywords
print("\n--- Admin RPCs with update + price/amount in source ---")
r2 = sql("""SELECT proname FROM pg_proc 
    WHERE proname LIKE 'app_admin_%' 
    AND (prosrc LIKE '%price%' OR prosrc LIKE '%amount%' OR prosrc LIKE '%credit_pack%' OR prosrc LIKE '%subscription_plan%')
    AND prosrc LIKE '%UPDATE%'
    ORDER BY proname""")
if isinstance(r2, list):
    for row in r2:
        name = row.get('proname')
        if name not in exists:
            print(f"  FOUND (not in checklist): {name}")
            exists.append(name)

print("\n--- Short training sessions: has price column? ---")
r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='short_training_sessions' ORDER BY ordinal_position")
if isinstance(r3, list):
    cols = [c.get('column_name') for c in r3]
    has_price = 'price' in cols
    print(f"  Columns: {cols}")
    print(f"  Has 'price': {has_price}")

print("\n--- TD programs: existing update RPC? ---")
r4 = sql("SELECT proname FROM pg_proc WHERE proname LIKE 'app_%td%' AND (proname LIKE '%update%' OR proname LIKE '%admin%') ORDER BY proname")
if isinstance(r4, list):
    for row in r4:
        print(f"  {row.get('proname')}")

print("\n--- action_prices table structure ---")
r5 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='action_prices' ORDER BY ordinal_position")
if isinstance(r5, list):
    for c in r5:
        print(f"  {c.get('column_name')} ({c.get('data_type')})")

print("\n--- subscription_plans table structure ---")
r6 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='subscription_plans' ORDER BY ordinal_position")
if isinstance(r6, list):
    for c in r6:
        print(f"  {c.get('column_name')} ({c.get('data_type')})")
    r6b = sql("SELECT * FROM app.subscription_plans ORDER BY price_xof")
    if isinstance(r6b, list):
        print(f"  Data: {r6b}")

print("\n" + "=" * 70)
print("SUMMARY")
print(f"  Existing: {len(exists)}")
print(f"  Missing (to create): {len(missing)}")
print(f"  Missing list: {missing}")
print("=" * 70)
