#!/usr/bin/env python3
"""Etat des lieux: tous les montants configurables par domaine."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": q}, timeout=15)
    return r.json() if r.status_code == 200 else {"error": r.status_code, "text": r.text[:200]}

print("=" * 70)
print("ETAT DES LIEUX — MONTANTS CONFIGURABLES PAR DOMAINE")
print("=" * 70)

# 1. PROGRAMMES UNIVERSITE
print("\n1. PROGRAMMES UNIVERSITE (app.programs)")
r = sql("SELECT id, title, degree_level, tuition_fees FROM app.programs WHERE is_active=true ORDER BY title LIMIT 10")
if isinstance(r, list):
    print(f"   Colonnes stockant montants: tuition_fees")
    print(f"   Nb programmes actifs: {len(r)}")
    for p in r[:3]:
        print(f"     - {p.get('title')} ({p.get('degree_level')}): {p.get('tuition_fees')} XOF")
    print(f"   Parametrable depuis admin: NON (pas d'interface)")

# 2. FRAIS CANDIDATURE / INSCRIPTION / SCOLARITE (application_payments)
print("\n2. FRAIS CANDIDATURE UNIVERSITE (app.application_fee_rules ou admin_confirm_payment)")
r2 = sql("""SELECT column_name FROM information_schema.columns 
    WHERE table_schema='app' AND table_name='application_fee_rules' ORDER BY ordinal_position""")
if isinstance(r2, list) and len(r2) > 0:
    cols = [c.get('column_name') for c in r2]
    print(f"   Table app.application_fee_rules existe: OUI")
    print(f"   Colonnes: {cols}")
    r2b = sql("SELECT * FROM app.application_fee_rules LIMIT 5")
    if isinstance(r2b, list):
        for row in r2b:
            print(f"     {row}")
else:
    print(f"   Table application_fee_rules: NON")
    print(f"   Les montants sont fixes par l'admin dans app_admin_confirm_payment (RPC)")
    r2c = sql("SELECT DISTINCT payment_reason, COUNT(*) as nb, AVG(amount_due) as avg_amount FROM app.application_payments GROUP BY payment_reason ORDER BY payment_reason")
    if isinstance(r2c, list):
        for row in r2c:
            print(f"     {row.get('payment_reason')}: {row.get('nb')} paiements, moy={row.get('avg_amount')} XOF")

# 3. CREDITS IA (packs credits)
print("\n3. CREDITS IA — PACKS (app.credit_packs ou similaire)")
r3 = sql("""SELECT table_name FROM information_schema.tables 
    WHERE table_schema='app' AND table_name LIKE '%credit%' ORDER BY table_name""")
if isinstance(r3, list):
    for t in r3:
        tn = t.get('table_name')
        print(f"   Table: app.{tn}")
        r3b = sql(f"SELECT * FROM app.{tn} LIMIT 5")
        if isinstance(r3b, list):
            for row in r3b:
                print(f"     {row}")

# 4. FORMATIONS COURTES
print("\n4. FORMATIONS COURTES (app.short_training_sessions)")
r4 = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='short_training_sessions' ORDER BY ordinal_position")
if isinstance(r4, list):
    cols = [c.get('column_name') for c in r4]
    print(f"   Colonnes: {cols}")
    r4b = sql("SELECT id, title, price, status FROM app.short_training_sessions LIMIT 5")
    if isinstance(r4b, list):
        for row in r4b:
            print(f"     {row.get('title')}: {row.get('price')} XOF, status={row.get('status')}")
    print(f"   Parametrable depuis admin: PARTIEL (AdminShortTrainingsScreen existe)")

# 5. TD (travaux diriges)
print("\n5. TD — TRAVAUX DIRIGES (app.td_items ou app.td_sessions)")
r5 = sql("""SELECT table_name FROM information_schema.tables 
    WHERE table_schema='app' AND table_name LIKE '%td%' ORDER BY table_name""")
if isinstance(r5, list):
    for t in r5:
        tn = t.get('table_name')
        r5b = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{tn}' AND (column_name LIKE '%price%' OR column_name LIKE '%amount%' OR column_name LIKE '%cost%')")
        if isinstance(r5b, list) and len(r5b) > 0:
            cols = [c.get('column_name') for c in r5b]
            print(f"   app.{tn}: colonnes montant = {cols}")

# 6. MARKETPLACE
print("\n6. MARKETPLACE — PRODUITS (app.marketplace_products)")
r6 = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='marketplace_products' AND (column_name LIKE '%price%' OR column_name LIKE '%amount%')")
if isinstance(r6, list):
    cols = [c.get('column_name') for c in r6]
    print(f"   Colonnes montant: {cols}")
    r6b = sql("SELECT name, unit_price, status FROM app.marketplace_products WHERE status='active' LIMIT 3")
    if isinstance(r6b, list):
        for row in r6b:
            print(f"     {row.get('name')}: {row.get('unit_price')} XOF")
    print(f"   Parametrable depuis admin: PARTIEL (AdminMarketplaceControlTowerScreen)")

# 7. ABONNEMENTS
print("\n7. ABONNEMENTS (app.subscription_plans)")
r7 = sql("SELECT * FROM app.subscription_plans WHERE is_active=true ORDER BY price_xof")
if isinstance(r7, list):
    for row in r7:
        print(f"     {row.get('name')}: {row.get('price_xof')} XOF / {row.get('duration_days')} jours")
    print(f"   Parametrable depuis admin: NON (AdminSubscriptionsScreen ne gere que la liste)")

# 8. CONCOURS / PREP
print("\n8. CONCOURS PREP (app.prep_concours_packs)")
r8 = sql("""SELECT table_name FROM information_schema.tables 
    WHERE table_schema='app' AND (table_name LIKE '%prep%' OR table_name LIKE '%concours%') ORDER BY table_name""")
if isinstance(r8, list):
    for t in r8:
        tn = t.get('table_name')
        r8b = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{tn}' AND (column_name LIKE '%price%' OR column_name LIKE '%amount%')")
        if isinstance(r8b, list) and len(r8b) > 0:
            cols = [c.get('column_name') for c in r8b]
            print(f"   app.{tn}: {cols}")

# 9. COMMISSIONS / SPLIT (deja gere par AdminRevenueSplitScreen)
print("\n9. COMMISSIONS & SPLIT (deja parametrable via AdminRevenueSplitScreen + AdminCommissionRulesScreen)")
r9 = sql("SELECT payment_reason, beneficiary_type, percentage FROM app.revenue_split_rules WHERE is_active=true ORDER BY payment_reason, beneficiary_type")
if isinstance(r9, list):
    for row in r9:
        print(f"     {row.get('payment_reason')} → {row.get('beneficiary_type')}: {float(row.get('percentage',0))*100:.0f}%")

print("\n" + "=" * 70)
print("INTERFACES ADMIN EXISTANTES")
print("=" * 70)
print("""
  - AdminPaymentsScreen         : gere les paiements candidature
  - AdminShortTrainingsScreen   : gere sessions formations courtes
  - AdminMarketplaceControlTower: gere produits marketplace
  - AdminSubscriptionsScreen    : liste abonnements
  - AdminRevenueSplitScreen     : split revenus (%)
  - AdminCommissionRulesScreen  : commissions commerciaux
  
  MANQUANTS:
  - Interface parametrage frais candidature/inscription/scolarite par programme
  - Interface parametrage packs credits IA (prix + nb credits)
  - Interface parametrage prix abonnements
  - Interface parametrage frais TD par session
  - Interface parametrage packs concours/prep
""")
print("Done.")
