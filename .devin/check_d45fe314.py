#!/usr/bin/env python3
"""Verifier l'etat final du paiement d45fe314 (10 XOF du 29 mai 16:48) apres callback."""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}
def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else {"err": r.status_code, "txt": r.text[:300]}

print("="*70); print("ETAT FINAL DU PAIEMENT 10 XOF (d45fe314)"); print("="*70)

print("\n[1] application_payments d45fe314")
print(json.dumps(sql("""SELECT id, status, channel, payment_method, amount_due, amount_paid,
phone_number, ligdicash_token IS NOT NULL has_token, ligdicash_transaction_id, ligdicash_operator,
created_at, updated_at FROM app.application_payments WHERE id='d45fe314-d894-4765-9c4d-981e3175ba98'"""),
indent=2, ensure_ascii=False, default=str))

print("\n[2] Recu lie 4fd88df8")
print(json.dumps(sql("""SELECT * FROM app.payment_receipts
WHERE id='4fd88df8-5f83-4bbd-81e6-80f5b539af04' OR payment_id='d45fe314-d894-4765-9c4d-981e3175ba98'"""),
indent=2, ensure_ascii=False, default=str))

print("\n[3] platform_ledger lie")
print(json.dumps(sql("""SELECT * FROM app.platform_ledger
WHERE source_payment_id='d45fe314-d894-4765-9c4d-981e3175ba98'
   OR custom_data::text LIKE '%d45fe314%' LIMIT 5"""),
indent=2, ensure_ascii=False, default=str))

print("\n[4] Compteurs apres ce paiement")
for t in ["application_payments","payment_receipts","platform_ledger","actor_balances"]:
    r = sql(f"SELECT COUNT(*) c FROM app.{t}")
    print(f"  {t}: {r[0]['c'] if isinstance(r,list) and r else r}")
print("="*70)
