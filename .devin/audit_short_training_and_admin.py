#!/usr/bin/env python3
"""Audit formations courtes (table paiements) + admin onglets marketplace/formations."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json", "Accept": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:200]}

print("=" * 70)
print("AUDIT FORMATIONS COURTES — Tables + RPCs paiement")
print("=" * 70)

# Colonnes de short_training_registrations
print("\n--- Colonnes short_training_registrations ---")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='short_training_registrations' ORDER BY ordinal_position")
if isinstance(r, list):
    for c in r:
        print(f"  {c['column_name']} ({c['data_type']})")
else:
    print(f"  {r}")

# Y a-t-il un champ payment_id ou payment_status dans registrations ?
print("\n--- Champs liés au paiement dans registrations ---")
r = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='short_training_registrations' AND column_name LIKE '%pay%' OR column_name LIKE '%amount%' OR column_name LIKE '%price%'")
if isinstance(r, list):
    for c in r:
        print(f"  ✅ {c['column_name']}")
    if not r:
        print("  ❌ Aucun champ paiement trouvé")
else:
    print(f"  {r}")

# RPC create_short_training_payment — voir ce qu'elle fait
print("\n--- RPC app_student_create_short_training_payment ---")
r = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_student_create_short_training_payment' LIMIT 1")
if isinstance(r, list) and len(r) > 0:
    src = r[0].get("prosrc", "")
    print(f"  Longueur source: {len(src)} chars")
    # Chercher quelle table elle écrit
    if "application_payments" in src:
        print(f"  → Écrit dans: application_payments ✅")
    elif "short_training_payments" in src:
        print(f"  → Écrit dans: short_training_payments")
    else:
        print(f"  → Table cible inconnue")
    # Chercher le payment_reason
    if "short_training" in src or "formation" in src:
        print(f"  → payment_reason contient 'short_training' ou 'formation'")
    print(f"\n  Source (premiers 500 chars):\n  {src[:500]}")
else:
    print(f"  ❌ RPC non trouvée: {r}")

# RPC confirm
print("\n--- RPC app_confirm_short_training_payment ---")
r = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_confirm_short_training_payment' LIMIT 1")
if isinstance(r, list) and len(r) > 0:
    src = r[0].get("prosrc", "")
    print(f"  Longueur source: {len(src)} chars")
    print(f"  Source (premiers 500 chars):\n  {src[:500]}")
else:
    print(f"  ❌ RPC non trouvée: {r}")

# Sessions existantes
print("\n--- Données short_training_sessions ---")
r = sql("SELECT COUNT(*) as cnt FROM app.short_training_sessions")
cnt = r[0].get("cnt", 0) if isinstance(r, list) and len(r) > 0 else "?"
print(f"  Sessions: {cnt}")

r = sql("SELECT id, title, price, status FROM app.short_training_sessions LIMIT 5")
if isinstance(r, list):
    for s in r:
        print(f"    {s.get('title','')} — {s.get('price',0)} XOF — status={s.get('status','')}")

print("\n" + "=" * 70)
print("AUDIT ADMIN — Onglets marketplace + formations")
print("=" * 70)

# Admin dashboard tabs
print("\n--- Recherche onglets admin liés au marketplace/formations ---")
for name in ["admin_marketplace", "admin_short_training", "admin_formation"]:
    r = sql(f"SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_{name}%' LIMIT 5")
    if isinstance(r, list) and len(r) > 0:
        for rpc in r:
            print(f"  ✅ {rpc.get('routine_name')}")
    else:
        print(f"  ❌ Aucune RPC app_{name}*")

# Marketplace admin RPCs
print("\n--- RPCs Admin Marketplace ---")
for rpc in ["app_admin_list_marketplace_orders", "app_admin_list_marketplace_payments", "app_admin_marketplace_release_payment"]:
    r = sql(f"SELECT 1 FROM pg_proc WHERE proname = '{rpc}' LIMIT 1")
    exists = isinstance(r, list) and len(r) > 0
    print(f"  {'✅' if exists else '❌'} {rpc}")

# Short training admin RPCs
print("\n--- RPCs Admin Formations Courtes ---")
for rpc in ["app_admin_list_short_training_sessions", "app_admin_create_short_training_session", "app_admin_list_short_training_registrations"]:
    r = sql(f"SELECT 1 FROM pg_proc WHERE proname = '{rpc}' LIMIT 1")
    exists = isinstance(r, list) and len(r) > 0
    print(f"  {'✅' if exists else '❌'} {rpc}")

print("\nDone.")
