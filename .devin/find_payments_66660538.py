#!/usr/bin/env python3
"""Trouver TOUS les paiements lies au numero 66660538 (toute table, tout temps)."""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}
def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else {"err": r.status_code, "txt": r.text[:300]}

print("="*70); print("RECHERCHE EXHAUSTIVE PHONE 66660538"); print("="*70)

print("\n[1] application_payments avec phone contenant 66660538 (TOUT statut, TOUT canal)")
r = sql("""SELECT id, status, channel, payment_method, amount_due, amount_paid,
phone_number, payment_reason,
ligdicash_token IS NOT NULL has_token,
ligdicash_transaction_id, ligdicash_operator,
created_at, updated_at
FROM app.application_payments
WHERE phone_number LIKE '%66660538%'
ORDER BY created_at DESC LIMIT 30""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[2] marketplace_payments avec phone contenant 66660538")
r = sql("""SELECT id, status, gross_amount, phone_number, created_at, updated_at
FROM app.marketplace_payments
WHERE phone_number LIKE '%66660538%'
ORDER BY created_at DESC LIMIT 20""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[3] TOUS les statuts uniques en application_payments (debug)")
r = sql("SELECT DISTINCT status, channel FROM app.application_payments ORDER BY status, channel")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[4] TOUS les paiements ligdicash avec leur phone (TOUT temps, pour faire la liste claire)")
r = sql("""SELECT id, status, amount_due, phone_number, ligdicash_operator,
ligdicash_token IS NOT NULL has_token, ligdicash_transaction_id,
created_at::date as day, updated_at
FROM app.application_payments
WHERE channel='ligdicash' OR payment_method LIKE 'ligdicash%' OR ligdicash_token IS NOT NULL
ORDER BY created_at DESC LIMIT 30""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[5] TOUS les paiements 100 XOF des 5 derniers jours (toute origine)")
r = sql("""SELECT id, status, channel, payment_method, amount_due, phone_number,
ligdicash_token IS NOT NULL has_token, payment_reason,
created_at, updated_at
FROM app.application_payments
WHERE amount_due = 100 AND created_at > now() - interval '5 days'
ORDER BY created_at DESC LIMIT 30""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n" + "="*70)
print("FIN")
print("="*70)
