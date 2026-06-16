#!/usr/bin/env python3
"""Verifier directement l'API LigdiCash pour les paiements deja confirmes en DB.

Objectif : prouver que les invoice_id 78170008 / 77195408 / 77194878 / 77181822
existent bien chez LigdiCash en utilisant la meme cle/token que les Edge Functions.

On passe par ligdicash-diag (deploye sur Supabase) qui a deja les secrets en env.
"""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def diag(action, **kwargs):
    body = {"action": action, **kwargs}
    r = requests.post(
        f"{URL}/functions/v1/ligdicash-diag",
        headers={"Authorization": f"Bearer {SRK}", "Content-Type": "application/json"},
        json=body, timeout=30,
    )
    print(f"\n--- action={action} HTTP {r.status_code}")
    try:
        print(json.dumps(r.json(), indent=2, ensure_ascii=False))
    except Exception:
        print(r.text[:500])

# Recup tokens depuis DB
H = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}
def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else None

print("=" * 70)
print("VERIFICATION API LIGDICASH (compte Academia TEST)")
print("=" * 70)

# 1. Info config
diag("info")

# 2. Solde marchand
diag("check_balance")

# 3. Verify chaque token confirmed via fetch direct LigdiCash
tokens = sql("""SELECT id, ligdicash_token, ligdicash_transaction_id, amount_due, created_at::date d
FROM app.application_payments
WHERE channel='ligdicash' AND status='confirmed' AND ligdicash_token IS NOT NULL
ORDER BY created_at DESC""")

print("\n" + "=" * 70)
print("VERIFY DIRECT DES 4 TOKENS CONFIRMED VIA L'API LIGDICASH")
print("=" * 70)

# On utilise une nouvelle Edge Function inline via diag : creons une action verify
# en attendant, on peut decoder le JWT manuellement et afficher l'id_invoice
import base64
def decode_jwt_payload(token):
    try:
        parts = token.split('.')
        if len(parts) < 2: return None
        payload = parts[1] + '=' * (-len(parts[1]) % 4)
        return json.loads(base64.urlsafe_b64decode(payload))
    except Exception as e:
        return {"error": str(e)}

if isinstance(tokens, list):
    for t in tokens:
        decoded = decode_jwt_payload(t['ligdicash_token'])
        print(f"\n  Academia id={t['id'][:8]}... date={t['d']} amount={t['amount_due']}")
        print(f"    JWT decode -> {decoded}")
        print(f"    => Cherche cette transaction dans LigdiCash dashboard sous id_invoice = {decoded.get('id_invoice') if decoded else 'N/A'}")

print("\n" + "=" * 70)
print("FIN")
print("=" * 70)
