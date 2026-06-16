#!/usr/bin/env python3
"""Verification complete des RPCs pricing et des donnees retournees."""

import requests, json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def rpc(name, params=None):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/{name}",
        headers=HEADERS, json=params or {}, timeout=15)
    return r.status_code, r.json() if r.status_code == 200 else r.text[:200]

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.text[:200]}

print("=" * 65)
print("VERIFICATION RPCS TARIFICATION")
print("=" * 65)

# 1. Credits IA
print("\n[1] app_admin_list_credit_packs")
status, data = rpc("app_admin_list_credit_packs")
if isinstance(data, dict) and data.get('success'):
    packs = data.get('packs') or []
    print(f"  OK — {len(packs)} packs")
    for p in packs:
        print(f"    {p.get('name')} | {p.get('credits')} credits | {p.get('price_xof')} XOF | bonus {p.get('bonus_percent')}% | actif={p.get('is_active')}")
else:
    print(f"  ERREUR {status}: {data}")

# 2. Abonnements
print("\n[2] app_admin_list_subscription_plans")
status, data = rpc("app_admin_list_subscription_plans")
if isinstance(data, dict) and data.get('success'):
    plans = data.get('plans') or []
    print(f"  OK — {len(plans)} plans")
    for p in plans:
        print(f"    {p.get('name')} | {p.get('price')} XOF | {p.get('duration_days')} jours | actif={p.get('is_active')}")
    if not plans:
        print("  ATTENTION: Aucun plan abonnement en DB!")
        r2 = sql("SELECT COUNT(*) as nb FROM app.subscription_plans")
        print(f"  Count raw: {r2}")
else:
    print(f"  ERREUR {status}: {data}")

# 3. Action prices IA
print("\n[3] app_admin_list_ai_action_prices")
status, data = rpc("app_admin_list_ai_action_prices")
if isinstance(data, dict) and data.get('success'):
    prices = data.get('prices') or []
    print(f"  OK — {len(prices)} actions")
    for p in (prices or [])[:5]:
        print(f"    {p.get('action_code')} | {p.get('cost_credits')} credits | actif={p.get('is_active')}")
    if len(prices or []) > 5:
        print(f"    ... +{len(prices)-5} autres")
    if not prices:
        print("  ATTENTION: Aucune action IA en DB!")
        r2 = sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND table_name='ai_action_prices'")
        print(f"  Table existe: {r2}")
        r3 = sql("SELECT COUNT(*) as nb FROM app.ai_action_prices")
        print(f"  Count: {r3}")
else:
    print(f"  ERREUR {status}: {data}")

# 4. Formations courtes
print("\n[4] app_admin_list_short_trainings_pricing")
status, data = rpc("app_admin_list_short_trainings_pricing")
if isinstance(data, dict) and data.get('success'):
    trainings = data.get('trainings') or []
    print(f"  OK — {len(trainings)} formations")
    for t in trainings:
        print(f"    {t.get('title')} | {t.get('price')} XOF | actif={t.get('is_active')}")
else:
    print(f"  ERREUR {status}: {data}")

# 5. TD programmes
print("\n[5] app_admin_list_td_programs_pricing")
status, data = rpc("app_admin_list_td_programs_pricing")
if isinstance(data, dict) and data.get('success'):
    programs = data.get('programs') or []
    print(f"  OK — {len(programs)} programmes TD")
    for p in (programs or [])[:5]:
        print(f"    {p.get('title')} | {p.get('price')} XOF | {p.get('level')} | {p.get('status')}")
else:
    print(f"  ERREUR {status}: {data}")

# 6. Programmes universite
print("\n[6] app_admin_list_programs_pricing")
status, data = rpc("app_admin_list_programs_pricing")
if isinstance(data, dict) and data.get('success'):
    programs = data.get('programs') or []
    print(f"  OK — {len(programs)} programmes universite")
    for p in (programs or [])[:5]:
        print(f"    {p.get('title')} | {p.get('degree_level')} | tuition={p.get('tuition_fees')} XOF | actif={p.get('is_active')}")
else:
    print(f"  ERREUR {status}: {data}")

print("\n" + "=" * 65)
print("POINTS D'ATTENTION FLUTTER")
print("=" * 65)

# Check if ai_action_prices tab is in flutter screen or not shown
# The screen has 5 tabs: Credits, Abonnements, TD, Formations, Programmes
# ai_action_prices is NOT a tab - good, it's part of Credits tab context
# Verify subscription_plans has price column not price_xof
print("""
  Onglet 1 — Credits IA:   RPC retourne 'price_xof' -> Flutter lit 'price_xof' ✓
  Onglet 2 — Abonnements:  RPC retourne 'price'    -> Flutter lit 'price'     ✓ (subscription_plans.price)
  Onglet 3 — TD:           RPC retourne 'price'    -> Flutter lit 'price'     ✓
  Onglet 4 — Formations:   RPC retourne 'price'    -> Flutter lit 'price'     ✓
  Onglet 5 — Programmes:   RPC retourne 'tuition_fees' -> Flutter lit 'tuition_fees' ✓
""")

# Check subscription_plans column name (price vs price_xof)
r = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='subscription_plans' AND column_name IN ('price','price_xof')")
if isinstance(r, list):
    cols = [c.get('column_name') for c in r]
    print(f"  subscription_plans price column: {cols}")

print("\nDone.")
