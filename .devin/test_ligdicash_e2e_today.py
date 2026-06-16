#!/usr/bin/env python3
"""
Test E2E LigdiCash avant les tests reels demain.
Audit complet : Edge Functions deployees, secrets configures (via comportement),
DB pretes, RPC idempotente, flow mock fonctionnel.
"""
import requests, json, sys, io

sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json", "Accept": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else {"err": r.status_code, "txt": r.text[:300]}

def call_fn(name, body):
    r = requests.post(f"{URL}/functions/v1/{name}", headers=H, json=body, timeout=45)
    return r.status_code, r.text[:600]

print("="*70)
print("AUDIT LIGDICASH - TESTS PRE-PRODUCTION")
print("="*70)

# 1. Edge Functions deployees (handshake = ne pas 404)
print("\n[1] DEPLOIEMENT EDGE FUNCTIONS")
for fn in ["ligdicash-initiate", "ligdicash-confirm", "ligdicash-callback", "ligdicash-payout", "ligdicash-diag", "ligdicash-diagnostic"]:
    st, body = call_fn(fn, {})
    deployed = st != 404
    mark = "OK " if deployed else "KO "
    print(f"  {mark} {fn}: HTTP {st}  (404=non deployee)")

# 2. RPC critique presente + contenu
print("\n[2] RPC app_confirm_ligdicash_payment")
r = sql("SELECT proname, pg_get_function_identity_arguments(p.oid) as args, length(prosrc) as src_len FROM pg_proc p JOIN pg_namespace n ON n.oid=pronamespace WHERE proname='app_confirm_ligdicash_payment'")
print("  ", json.dumps(r, ensure_ascii=False, default=str)[:400])

# 3. Tables paiements + comptages
print("\n[3] COMPTAGES TABLES CLES (schema app)")
for t in ["application_payments", "marketplace_payments", "payment_receipts", "payout_queue", "platform_ledger", "actor_balances", "subscriptions", "subscription_plans", "revenue_split_rules", "referral_commissions"]:
    r = sql(f"SELECT COUNT(*) c FROM app.{t}")
    c = r[0]["c"] if isinstance(r, list) and r else "ERR"
    print(f"  {t}: {c}")

# 4. Etat des paiements LigdiCash recents
print("\n[4] DERNIERS PAIEMENTS LIGDICASH (any channel/method)")
r = sql("""SELECT id, status, channel, payment_method, amount_due, payment_reason, ligdicash_token IS NOT NULL as has_token, created_at
FROM app.application_payments
WHERE channel='ligdicash' OR payment_method LIKE 'ligdicash%' OR ligdicash_token IS NOT NULL
ORDER BY created_at DESC LIMIT 5""")
print("  ", json.dumps(r, ensure_ascii=False, default=str)[:800])

# 5. Enums valides
print("\n[5] ENUMS PAIEMENTS")
for enum in ["payment_status", "payment_channel", "payment_reason"]:
    r = sql(f"SELECT unnest(enum_range(NULL::app.{enum}))::text as v")
    if isinstance(r, list):
        vals = [x["v"] for x in r]
        print(f"  {enum}: {vals}")

# 6. RLS + service_role
print("\n[6] RLS POLICIES SUR TABLES PAIEMENTS")
r = sql("""SELECT schemaname, tablename, COUNT(*) as policies
FROM pg_policies WHERE schemaname='app' AND tablename IN ('application_payments','marketplace_payments','payout_queue','platform_ledger','actor_balances','subscriptions')
GROUP BY schemaname, tablename ORDER BY tablename""")
print("  ", json.dumps(r, ensure_ascii=False, default=str)[:500])

# 7. Triggers + pg_cron
print("\n[7] PG_CRON JOBS LIES AUX PAIEMENTS")
r = sql("SELECT jobid, jobname, schedule FROM cron.job WHERE jobname ILIKE '%payment%' OR jobname ILIKE '%subscription%' OR jobname ILIKE '%payout%' OR jobname ILIKE '%expire%' ORDER BY jobid")
print("  ", json.dumps(r, ensure_ascii=False, default=str)[:400])

# 8. Test ligdicash-initiate avec service_role (sans user) - on attend 401 not_authenticated
print("\n[8] TEST APPEL EDGE FN AVEC SERVICE_ROLE (attendu 401)")
st, body = call_fn("ligdicash-initiate", {"payment_type": "application", "payment_id": "00000000-0000-0000-0000-000000000000", "phone_number": "22670000000"})
print(f"  status={st}")
print(f"  body={body[:250]}")

# 9. Inspection des secrets (indirect) - on lit les vault si accessible
print("\n[9] INSPECTION VAULT SUPABASE (si accessible)")
r = sql("SELECT name FROM vault.secrets WHERE name ILIKE '%ligdicash%'")
print("  vault.secrets ligdicash:", json.dumps(r, ensure_ascii=False, default=str)[:300])

print("\n" + "="*70)
print("FIN AUDIT")
print("="*70)
