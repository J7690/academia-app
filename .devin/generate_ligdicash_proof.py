#!/usr/bin/env python3
"""
Generateur de DOSSIER-PREUVE LigdiCash pour une transaction donnee.

Usage:
    python .windsurf/generate_ligdicash_proof.py <payment_id_academia>

Exemple:
    python .windsurf/generate_ligdicash_proof.py d45fe314-d894-4765-9c4d-981e3175ba98

Le script :
  1. Recupere le paiement en DB (status, token, etc.)
  2. Decode le JWT LigdiCash (id_invoice, dates)
  3. Appelle l'endpoint verify_token de LigdiCash via ligdicash-diag (preuve live)
  4. Recupere le recu lie
  5. Affiche un rapport pret a copier-coller / partager avec LigdiCash
"""
import requests, json, sys, base64
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H_SQL = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}
H_FN  = {"Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H_SQL, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else None

def diag_verify(token):
    r = requests.post(f"{URL}/functions/v1/ligdicash-diag", headers=H_FN,
                      json={"action": "verify_token", "token": token}, timeout=30)
    try: return r.json()
    except: return {"raw": r.text[:500]}

def decode_jwt(token):
    try:
        parts = token.split('.')
        payload = parts[1] + '=' * (-len(parts[1]) % 4)
        return json.loads(base64.urlsafe_b64decode(payload))
    except Exception as e:
        return {"error": str(e)}

# --- Main ---
if len(sys.argv) < 2:
    print("Usage: python generate_ligdicash_proof.py <payment_id>")
    sys.exit(1)

pid = sys.argv[1].strip()
print("=" * 76)
print(f"DOSSIER-PREUVE LIGDICASH — Payment {pid}")
print("=" * 76)

# 1. Paiement Academia
rows = sql(f"""SELECT id, status, channel, payment_method, payment_reason,
amount_due, amount_paid, phone_number, reference_code,
ligdicash_token, ligdicash_transaction_id, ligdicash_operator,
created_at, updated_at, student_id
FROM app.application_payments WHERE id='{pid}'""")
if not rows:
    print(f"\n[ERREUR] Aucun paiement trouve avec id={pid} dans application_payments.")
    sys.exit(1)
ap = rows[0]

# 2. Recu lie
recs = sql(f"""SELECT id, receipt_number, issued_at, snapshot
FROM app.payment_receipts WHERE payment_id='{pid}' ORDER BY issued_at DESC LIMIT 1""")
rec = recs[0] if recs else None

# 3. Decode JWT
jwt_payload = decode_jwt(ap['ligdicash_token']) if ap.get('ligdicash_token') else None

# 4. Appel verify live a LigdiCash
verify = diag_verify(ap['ligdicash_token']) if ap.get('ligdicash_token') else None

# --- Affichage ---
print("\n[BLOC A] IDENTIFIANTS LIGDICASH")
print("-" * 76)
if verify and verify.get('response', {}).get('response_code') == '00':
    resp = verify['response']
    print(f"  request_id     : {resp.get('request_id')}")
    print(f"  id_invoice     : {jwt_payload.get('id_invoice') if jwt_payload else 'N/A'}")
    print(f"  external_id    : {resp.get('external_id')}")
    print(f"  logfile        : {next((c['valueof_customdata'] for c in resp.get('custom_data',[]) if c.get('keyof_customdata')=='logfile'), 'N/A')}")
    print(f"  token (JWT)    : {ap['ligdicash_token'][:80]}...")
    print(f"  status_ligdicash : {resp.get('status')}")
    print(f"  response_code  : {resp.get('response_code')} (00 = succes)")
else:
    print(f"  [WARN] verify a echoue : {verify}")
    print(f"  token          : {ap.get('ligdicash_token')}")
    print(f"  id_invoice JWT : {jwt_payload.get('id_invoice') if jwt_payload else 'N/A'}")

print("\n[BLOC B] DONNEES METIER")
print("-" * 76)
print(f"  Montant        : {ap['amount_due']} XOF")
print(f"  Devise         : XOF")
print(f"  Numero client  : {ap['phone_number']}")
print(f"  Operateur      : {ap['ligdicash_operator']}")
print(f"  Date debit     : {ap['updated_at']}")
print(f"  Date creation  : {ap['created_at']}")

print("\n[BLOC C] DONNEES ACADEMIA (Supabase)")
print("-" * 76)
print(f"  payment_id     : {ap['id']}")
print(f"  status         : {ap['status']}")
print(f"  channel        : {ap['channel']}")
print(f"  payment_method : {ap['payment_method']}")
print(f"  payment_reason : {ap['payment_reason']}")
print(f"  reference_code : {ap['reference_code']}")
if rec:
    print(f"  receipt_number : {rec['receipt_number']}")
    print(f"  receipt_id     : {rec['id']}")
else:
    print(f"  receipt_number : (aucun recu trouve)")

print("\n[BLOC D] LOGS EDGE FUNCTIONS (a verifier sur Supabase Dashboard)")
print("-" * 76)
print(f"  ligdicash-initiate : https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/functions/ligdicash-initiate/logs")
print(f"  ligdicash-confirm  : https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/functions/ligdicash-confirm/logs")
print(f"  ligdicash-callback : https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/functions/ligdicash-callback/logs")
print(f"  Filtre temporel : autour de {ap['updated_at']}")

print("\n[BLOC E] REPONSE BRUTE LIGDICASH (verify_token live)")
print("-" * 76)
if verify:
    print(json.dumps(verify, indent=2, ensure_ascii=False, default=str))
else:
    print("  Pas de token disponible -> impossible de verifier.")

print("\n" + "=" * 76)
print("FIN DU DOSSIER-PREUVE")
print("=" * 76)
