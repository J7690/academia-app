#!/usr/bin/env python3
"""Inspecter ce qui se passe vraiment cote DB pour les paiements LigdiCash recents."""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else {"err": r.status_code, "txt": r.text[:300]}

print("="*70)
print("DIAGNOSTIC TRACES PAIEMENTS LIGDICASH (4 dernieres heures)")
print("="*70)

print("\n[1] Tous les paiements ligdicash des 4h - on cherche has_token, transaction_id, operator")
r = sql("""SELECT id, status, amount_due, amount_paid, payment_reason,
ligdicash_token IS NOT NULL has_token,
ligdicash_token,
ligdicash_transaction_id,
ligdicash_operator,
phone_number,
created_at, updated_at
FROM app.application_payments
WHERE channel='ligdicash' AND created_at > now() - interval '4 hours'
ORDER BY created_at DESC LIMIT 20""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[2] Compteurs 4h")
r = sql("""SELECT
  COUNT(*) FILTER (WHERE status='pending') AS pending,
  COUNT(*) FILTER (WHERE status='processing') AS processing,
  COUNT(*) FILTER (WHERE status='confirmed') AS confirmed,
  COUNT(*) FILTER (WHERE status='failed') AS failed,
  COUNT(*) FILTER (WHERE ligdicash_token IS NOT NULL) AS with_token,
  COUNT(*) FILTER (WHERE ligdicash_token IS NULL) AS no_token
FROM app.application_payments
WHERE channel='ligdicash' AND created_at > now() - interval '4 hours'""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[3] Derniers paiements CONFIRMED (tout temps) - format token mock vs live")
r = sql("""SELECT id, status, amount_due, payment_reason, ligdicash_token, ligdicash_transaction_id, ligdicash_operator, updated_at
FROM app.application_payments
WHERE channel='ligdicash' AND status='confirmed'
ORDER BY updated_at DESC LIMIT 5""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n[4] Verifier si current MODE=live appelle vraiment le RPC (regarder mock_token_ vs vrais tokens)")
r = sql("""SELECT
  COUNT(*) FILTER (WHERE ligdicash_token LIKE 'mock_%') AS mock_tokens,
  COUNT(*) FILTER (WHERE ligdicash_token IS NOT NULL AND ligdicash_token NOT LIKE 'mock_%') AS real_tokens,
  COUNT(*) FILTER (WHERE ligdicash_transaction_id LIKE 'MOCK_%') AS mock_txn,
  COUNT(*) FILTER (WHERE ligdicash_transaction_id IS NOT NULL AND ligdicash_transaction_id NOT LIKE 'MOCK_%') AS real_txn
FROM app.application_payments WHERE channel='ligdicash'""")
print(json.dumps(r, indent=2, ensure_ascii=False, default=str))

print("\n" + "="*70)
print("FIN")
print("="*70)
