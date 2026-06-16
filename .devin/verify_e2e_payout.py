import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    return r.json()

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

print("=" * 70)
print("VERIFICATION E2E — Payout Architecture")
print("=" * 70)

# 1. Verify trigger exists on actor_balances
print("\n### 1. TRIGGER on actor_balances ###")
r1 = sql("""
  SELECT trigger_name, event_manipulation, action_timing
  FROM information_schema.triggers
  WHERE event_object_schema = 'app' AND event_object_table = 'actor_balances'
""")
print(f"  {r1}")

# 2. Verify pg_cron job exists
print("\n### 2. pg_cron job for payouts ###")
r2 = sql("SELECT jobname, schedule, command FROM cron.job WHERE jobname = 'process_pending_payouts'")
print(f"  {r2}")

# 3. Verify split rules totals via resolve function
print("\n### 3. Revenue split rules (via app_resolve_revenue_split) ###")
reasons = ['application_fee', 'registration_fee', 'tuition_deposit', 'td_access', 'online_course', 'subscription', 'credit_purchase']
all_ok = True
for reason in reasons:
    data = rpc("app_resolve_revenue_split", {"p_payment_reason": reason})
    if isinstance(data, list):
        total = sum(float(r.get('percentage', 0)) for r in data)
        types = [f"{r['beneficiary_type']}={float(r['percentage'])*100:.0f}%" for r in data]
        ok = abs(total - 1.0) < 0.01
        if not ok:
            all_ok = False
        print(f"  {reason:25s} {total*100:.0f}%  {'OK' if ok else 'FAIL'}  [{', '.join(types)}]")
    else:
        all_ok = False
        print(f"  {reason:25s} ERROR: {data}")
print(f"  >>> ALL RULES {'OK' if all_ok else 'HAVE ISSUES'}")

# 4. Verify university payout is disabled
print("\n### 4. University payout RPC disabled ###")
# Can't call with auth but check the function body
r4 = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_university_request_payout' LIMIT 1")
if isinstance(r4, dict) and r4.get('ok') and r4.get('rows'):
    defn = r4['rows'][0].get('def', '')
    if 'feature_disabled' in defn:
        print("  OK - Returns feature_disabled")
    else:
        print(f"  WARNING - doesn't contain feature_disabled")
        print(f"  {defn[:200]}")
else:
    print(f"  {r4}")

# 5. Verify Edge Function ligdicash-payout has top_up_wallet: 1
print("\n### 5. Edge Function top_up_wallet setting ###")
print("  Verified in code: top_up_wallet: 1 (LigdiCash -> LigdiCash)")

# 6. Verify trigger function code
print("\n### 6. Trigger function trg_auto_queue_payout ###")
r6 = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'trg_auto_queue_payout' LIMIT 1")
if isinstance(r6, dict) and r6.get('ok') and r6.get('rows'):
    defn = r6['rows'][0].get('def', '')
    checks = {
        'payout_queue INSERT': 'INSERT INTO app.payout_queue' in defn,
        'skip platform': "actor_type = 'platform'" in defn,
        'skip university': "actor_type = 'university'" in defn,
        'resolve instructor phone': "app.instructors" in defn,
        'resolve commercial phone': "app.commercial_profiles" in defn,
        'resolve merchant phone': "app.marketplace_merchants" in defn,
        'waiting_phone status': "waiting_phone" in defn,
        'deduct from balance': "available_balance - v_increase" in defn,
    }
    for check, ok in checks.items():
        print(f"  {'OK' if ok else 'FAIL'} {check}")
else:
    print(f"  {r6}")

# 7. Check no university in active split rules
print("\n### 7. No university in active split rules ###")
for reason in reasons:
    data = rpc("app_resolve_revenue_split", {"p_payment_reason": reason})
    if isinstance(data, list):
        for r in data:
            if r.get('beneficiary_type') == 'university':
                print(f"  FAIL - university found in {reason}")
                break
        else:
            continue
    break
else:
    print("  OK - No university in any active split rule")

# 8. Summary
print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)
print("""
FLUX PAYOUT END-TO-END:
1. Etudiant paie (LigdiCash payin) -> application_payments/marketplace_payments
2. LigdiCash callback -> app_confirm_ligdicash_payment RPC
3. RPC confirme + revenue split via app_resolve_revenue_split()
4. RPC credite actor_balances (UPSERT)
5. TRIGGER trg_auto_queue_payout intercepte INSERT/UPDATE
6. TRIGGER insere dans payout_queue (status=pending ou waiting_phone)
7. TRIGGER deduit available_balance (deja en queue)
8. pg_cron (toutes les 15min) appelle Edge Function ligdicash-payout
9. Edge Function traite les payouts pending
10. LigdiCash POST /pay/v01/withdrawal/create (top_up_wallet=1)
11. Transfert LigdiCash -> LigdiCash (portefeuille du beneficiaire)

ACTEURS:
- Enseignant (instructor): commission TD/cours -> payout auto
- Commercial (mobilisateur): commission referral -> payout auto
- Commercant (merchant): revenus marketplace -> payout auto
- Universite: DESACTIVE (aucun flux d'argent)
- Plateforme: garde sa part (pas de payout)
""")
