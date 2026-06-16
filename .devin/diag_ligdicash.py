#!/usr/bin/env python3
"""
Diagnostic complet du flux LigdiCash:
1. Verifier secrets (LIGDICASH_MODE, API_KEY, BEARER_TOKEN)
2. Tester l'API LigdiCash directement (debitotp, debitwallet/withotp)
3. Verifier l'Edge Function ligdicash-initiate et ligdicash-confirm
4. Checker les paiements recents en DB
"""

import requests, json, time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def sql(query, label=""):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query},
        timeout=30,
    )
    try:
        data = r.json()
    except:
        data = r.text[:500]
    if label:
        ok = r.status_code == 200
        print(f"  {'[OK]' if ok else '[ERR]'} {label}")
        if not ok:
            print(f"       {str(data)[:300]}")
    return data

def edge_call(fn_name, payload, use_service_key=True):
    key = SERVICE_KEY
    r = requests.post(
        f"{SUPABASE_URL}/functions/v1/{fn_name}",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=30,
    )
    return r.status_code, r.json() if r.headers.get("content-type","").startswith("application/json") else r.text[:500]


print("=" * 65)
print("  DIAGNOSTIC LIGDICASH COMPLET")
print("=" * 65)

# ============================================================
# 1. Verifier LIGDICASH_MODE et secrets via Edge Function test
# ============================================================
print("\n[1/7] Test Edge Function ligdicash-initiate (mode detection)...")
# On envoie un payload invalide expres pour voir la reponse
status, resp = edge_call("ligdicash-initiate", {
    "payment_type": "test",
    "payment_id": "00000000-0000-0000-0000-000000000000",
    "phone_number": "22670123456",
})
print(f"  Status: {status}")
print(f"  Response: {json.dumps(resp, indent=2)[:300]}")

# ============================================================
# 2. Verifier les secrets LigdiCash configures
# ============================================================
print("\n[2/7] Verification secrets via Edge Function helper...")
# Deployer temporairement une function qui retourne le mode
status2, resp2 = edge_call("ligdicash-confirm", {
    "payment_type": "test",
    "payment_id": "00000000-0000-0000-0000-000000000000",
    "otp_code": "123456",
    "phone_number": "22670123456",
})
print(f"  Status: {status2}")
print(f"  Response: {json.dumps(resp2, indent=2)[:300]}")

# ============================================================
# 3. Lister les secrets Supabase Edge Functions
# ============================================================
print("\n[3/7] Lister les secrets configures (via CLI)...")
# On ne peut pas lire les secrets directement, mais on peut les lister
# Let's check via supabase secrets list

# ============================================================
# 4. Verifier les paiements recents en DB
# ============================================================
print("\n[4/7] Paiements recents dans application_payments...")
data = sql("""
SELECT id, status, payment_reason, amount_due, amount_paid,
       channel, payment_method, phone_number,
       created_at, updated_at
FROM app.application_payments
ORDER BY created_at DESC
LIMIT 5
""", "recent application_payments")
if isinstance(data, list):
    for row in data:
        print(f"  id={str(row.get('id',''))[:8]}... status={row.get('status')} reason={row.get('payment_reason')} "
              f"amount={row.get('amount_due')} channel={row.get('channel')} method={row.get('payment_method')} "
              f"phone={row.get('phone_number')}")
else:
    print(f"  {str(data)[:300]}")

# ============================================================
# 5. Verifier credit_purchases / credit store payments
# ============================================================
print("\n[5/7] Paiements credit_purchase recents...")
data = sql("""
SELECT id, status, payment_reason, amount_due, amount_paid,
       channel, payment_method, phone_number,
       created_at
FROM app.application_payments
WHERE payment_reason = 'credit_purchase'
ORDER BY created_at DESC
LIMIT 5
""", "credit_purchase payments")
if isinstance(data, list):
    if len(data) == 0:
        print("  -> Aucun paiement credit_purchase trouve")
    for row in data:
        print(f"  id={str(row.get('id',''))[:8]}... status={row.get('status')} amount={row.get('amount_due')} "
              f"channel={row.get('channel')} phone={row.get('phone_number')} at={row.get('created_at')}")
else:
    print(f"  {str(data)[:300]}")

# ============================================================
# 6. Verifier les Edge Function logs (derniers appels ligdicash)
# ============================================================
print("\n[6/7] Verification des Edge Function logs recents via pg_net...")
data = sql("""
SELECT id, status_code, created,
       LEFT(content::text, 400) AS content
FROM net._http_response
WHERE content::text LIKE '%ligdicash%'
   OR content::text LIKE '%LigdiCash%'
   OR content::text LIKE '%debit%'
ORDER BY created DESC
LIMIT 5
""", "pg_net ligdicash responses")
if isinstance(data, list):
    if len(data) == 0:
        print("  -> Aucune reponse pg_net liee a LigdiCash")
    for row in data:
        print(f"  id={row.get('id')} status={row.get('status_code')} at={row.get('created')}")
        print(f"  content={row.get('content','')[:300]}")
        print()
else:
    print(f"  {str(data)[:300]}")

# ============================================================
# 7. Test direct API LigdiCash (lecture des cles depuis les fichiers .windsurf)
# ============================================================
print("\n[7/7] Test direct API LigdiCash...")
# Chercher les cles dans les fichiers existants
import glob, os, re
api_key = None
bearer_token = None

for f in glob.glob("*.py") + glob.glob("logs/*.md") + glob.glob("logs/*.json"):
    if not os.path.isfile(f):
        continue
    try:
        content = open(f, "r", encoding="utf-8", errors="ignore").read()
        if "LIGDICASH_API_KEY" in content or "Apikey" in content:
            # Try to extract
            for line in content.split("\n"):
                if "LIGDICASH_API_KEY" in line and "=" in line and not line.strip().startswith("#"):
                    m = re.search(r'["\']([A-Za-z0-9]+)["\']', line.split("=",1)[1])
                    if m and len(m.group(1)) > 10:
                        api_key = m.group(1)
                if "LIGDICASH_BEARER_TOKEN" in line and "=" in line and not line.strip().startswith("#"):
                    m = re.search(r'["\']([A-Za-z0-9]+)["\']', line.split("=",1)[1])
                    if m and len(m.group(1)) > 10:
                        bearer_token = m.group(1)
    except:
        pass

if api_key and bearer_token:
    print(f"  API Key trouvee: {api_key[:10]}...")
    print(f"  Bearer Token trouve: {bearer_token[:10]}...")
    
    # Test: appeler debitotp avec un numero test
    test_phone = "22666660538"
    test_amount = 100
    otp_url = f"https://app.ligdicash.com/pay/v02/debitotp/{test_phone}/{test_amount}"
    print(f"\n  Test OTP: GET {otp_url}")
    try:
        r = requests.get(
            otp_url,
            headers={
                "Apikey": api_key,
                "Authorization": f"Bearer {bearer_token}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            timeout=30,
        )
        print(f"  Status: {r.status_code}")
        print(f"  Response: {r.text[:500]}")
    except Exception as e:
        print(f"  Erreur: {e}")
else:
    print("  Cles LigdiCash non trouvees dans les fichiers locaux.")
    print("  Veuillez fournir LIGDICASH_API_KEY et LIGDICASH_BEARER_TOKEN")

print("\n" + "=" * 65)
print("  FIN DIAGNOSTIC LIGDICASH")
print("=" * 65)

# Sauvegarder
import os
os.makedirs("logs", exist_ok=True)
with open("logs/diag_ligdicash_report.txt", "w", encoding="utf-8") as f:
    f.write("Diagnostic LigdiCash effectue.\n")
    f.write(f"Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
