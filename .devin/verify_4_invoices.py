#!/usr/bin/env python3
"""Appeler verify_token sur les 4 paiements confirmed pour prouver qu'ils existent cote LigdiCash."""
import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SRK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H_SQL = {"apikey": SRK, "Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}
H_FN = {"Authorization": f"Bearer {SRK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H_SQL, json={"sql_query": q}, timeout=20)
    return r.json() if r.status_code == 200 else None

def verify(token):
    r = requests.post(f"{URL}/functions/v1/ligdicash-diag", headers=H_FN,
                      json={"action": "verify_token", "token": token}, timeout=30)
    try: return r.json()
    except: return {"raw": r.text[:300], "status": r.status_code}

rows = sql("""SELECT id, ligdicash_token, amount_due, created_at::date d, phone_number
FROM app.application_payments
WHERE channel='ligdicash' AND status='confirmed' AND ligdicash_token IS NOT NULL
ORDER BY created_at DESC""")

print("=" * 70)
print("VERIFY DIRECT API LIGDICASH POUR 4 PAIEMENTS CONFIRMED (numero 22666660538)")
print("=" * 70)

for row in rows:
    print(f"\n--- Academia id={row['id'][:8]}... date={row['d']} amount={row['amount_due']} phone={row['phone_number']}")
    res = verify(row['ligdicash_token'])
    print(json.dumps(res, indent=2, ensure_ascii=False, default=str))

print("\n" + "=" * 70)
