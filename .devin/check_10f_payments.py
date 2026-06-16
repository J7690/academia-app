#!/usr/bin/env python3
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json", "Accept": "application/json"}
def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else {"err": r.status_code, "txt": r.text[:300]}

print("="*70); print("PAIEMENTS 10 XOF / ACTIVITE RECENTE"); print("="*70)

print("\n[1] application_payments AVEC amount_due=10 (tout etat, tout temps)")
print(json.dumps(sql("""SELECT id, status, channel, payment_method, amount_due, amount_paid, payment_reason, ligdicash_token IS NOT NULL has_token, created_at, updated_at FROM app.application_payments WHERE amount_due=10 OR amount_paid=10 ORDER BY COALESCE(updated_at,created_at) DESC LIMIT 20"""), ensure_ascii=False, default=str, indent=2)[:3000])

print("\n[2] application_payments MODIFIES LES 30 DERNIERES MINUTES")
print(json.dumps(sql("""SELECT id, status, channel, amount_due, amount_paid, payment_reason, ligdicash_token IS NOT NULL has_token, created_at, updated_at FROM app.application_payments WHERE updated_at > now() - interval '30 minutes' OR created_at > now() - interval '30 minutes' ORDER BY COALESCE(updated_at,created_at) DESC LIMIT 20"""), ensure_ascii=False, default=str, indent=2)[:3000])

print("\n[3] marketplace_payments AVEC gross_amount=10 ou recents")
print(json.dumps(sql("""SELECT id, status, gross_amount, created_at, updated_at FROM app.marketplace_payments WHERE gross_amount=10 OR updated_at > now() - interval '30 minutes' ORDER BY COALESCE(updated_at,created_at) DESC LIMIT 10"""), ensure_ascii=False, default=str, indent=2)[:1500])

print("\n[4] payment_receipts RECENTS (30min)")
print(json.dumps(sql("""SELECT id, payment_id, receipt_number, created_at FROM app.payment_receipts WHERE created_at > now() - interval '30 minutes' ORDER BY created_at DESC LIMIT 10"""), ensure_ascii=False, default=str, indent=2)[:1500])

print("\n[5] COMPTAGES (delta vs derniere fois : 15/9/4/0/0/0)")
for t in ["application_payments", "payment_receipts", "platform_ledger", "actor_balances", "subscriptions", "payout_queue"]:
    r = sql(f"SELECT COUNT(*) c FROM app.{t}")
    c = r[0]["c"] if isinstance(r, list) and r else "ERR"
    print(f"  {t}: {c}")
print("="*70)
