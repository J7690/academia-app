#!/usr/bin/env python3
"""Inspecter ce qui a change recemment apres un appel au callback LigdiCash."""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json", "Accept": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else {"err": r.status_code, "txt": r.text[:300]}

print("="*70)
print("INSPECTION ACTIVITE PAIEMENTS RECENTE (24h)")
print("="*70)

print("\n[1] PAIEMENTS MODIFIES LES DERNIERES 24H")
r = sql("""SELECT id, status, channel, payment_method, amount_due, payment_reason,
ligdicash_token IS NOT NULL as has_token, ligdicash_transaction_id, created_at, updated_at
FROM app.application_payments
WHERE updated_at > now() - interval '24 hours'
ORDER BY updated_at DESC LIMIT 10""")
print(json.dumps(r, ensure_ascii=False, default=str, indent=2)[:2500])

print("\n[2] PAIEMENTS CONFIRMED AUJOURD'HUI (channel ligdicash)")
r = sql("""SELECT id, status, amount_due, payment_reason, ligdicash_transaction_id, ligdicash_operator, ligdicash_token IS NOT NULL as has_token, updated_at
FROM app.application_payments
WHERE channel='ligdicash' AND status='confirmed' AND updated_at::date = current_date
ORDER BY updated_at DESC LIMIT 10""")
print(json.dumps(r, ensure_ascii=False, default=str, indent=2)[:2000])

print("\n[3] RECUS GENERES AUJOURD'HUI")
r = sql("""SELECT id, payment_id, receipt_number, amount, created_at
FROM app.payment_receipts
WHERE created_at::date = current_date
ORDER BY created_at DESC LIMIT 10""")
print(json.dumps(r, ensure_ascii=False, default=str, indent=2)[:1500])

print("\n[4] ECRITURES LEDGER RECENTES")
r = sql("""SELECT id, payment_id, entry_type, amount, description, created_at
FROM app.platform_ledger
WHERE created_at > now() - interval '24 hours'
ORDER BY created_at DESC LIMIT 10""")
print(json.dumps(r, ensure_ascii=False, default=str, indent=2)[:2000])

print("\n[5] COMPTAGES GLOBAUX")
for t in ["application_payments", "payment_receipts", "platform_ledger", "actor_balances", "subscriptions", "payout_queue"]:
    r = sql(f"SELECT COUNT(*) c FROM app.{t}")
    c = r[0]["c"] if isinstance(r, list) and r else "ERR"
    print(f"  {t}: {c}")

print("\n[6] PAIEMENTS PROCESSING (potentiels callbacks recus mais polling pas fini)")
r = sql("""SELECT id, status, amount_due, payment_reason, ligdicash_token IS NOT NULL as has_token, created_at, updated_at
FROM app.application_payments
WHERE status='processing'
ORDER BY updated_at DESC LIMIT 10""")
print(json.dumps(r, ensure_ascii=False, default=str, indent=2)[:1500])

print("\n" + "="*70)
print("FIN")
print("="*70)
