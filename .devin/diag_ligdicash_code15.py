#!/usr/bin/env python3
"""
Diagnostic Code15 LigdiCash:
- Tester debitotp + debitwallet/withotp avec differents parametres
- Tester redirect (alternative)
- Identifier la cause exacte du Code15
"""

import requests, json, time

API_KEY = "9PH1085D51ZAFC1UE"
AUTH_TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZF9hcHAiOiIzMTYyMiIsImlkX2Fib25uZSI6MTEzNjc0NCwiZGF0ZWNyZWF0aW9uX2FwcCI6IjIwMjYtMDQtMDcgMDk6NDU6MDgifQ.AxDrB8subflKTCyfvQ8bV6nfDb3rmET2PlBbSCyi5ow"

HEADERS = {
    "Apikey": API_KEY,
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

PHONE = "22666660538"

print("=" * 65)
print("  DIAGNOSTIC CODE15 LIGDICASH")
print("=" * 65)

# ============================================================
# Test 1: Envoyer OTP pour 100 FCFA
# ============================================================
print("\n[1] Envoi OTP: GET /pay/v02/debitotp/22666660538/100")
r = requests.get(
    f"https://app.ligdicash.com/pay/v02/debitotp/{PHONE}/100",
    headers=HEADERS, timeout=15,
)
print(f"  Status: {r.status_code}")
print(f"  Response: {r.text[:300]}")
otp_data = r.json() if r.status_code == 200 else {}

# ============================================================
# Test 2: Confirm avec OTP bidon (000000) - pour voir le format d'erreur
# ============================================================
print("\n[2] Confirm avec OTP bidon (000000):")
invoice = {
    "commande": {
        "invoice": {
            "items": [{"name": "Test", "description": "Test", "quantity": 1, "unit_price": 100, "total_price": 100}],
            "total_amount": 100,
            "devise": "XOF",
            "description": "Test paiement",
            "customer": PHONE,
            "customer_firstname": "Test",
            "customer_lastname": "User",
            "customer_email": "test@test.com",
            "external_id": f"diag-{int(time.time())}",
            "otp": "000000",
        },
        "store": {"name": "Academia", "website_url": "https://nexiomgroup.space"},
        "actions": {"cancel_url": "", "return_url": "", "callback_url": ""},
        "custom_data": {"test": "true"},
    }
}
r = requests.post(
    "https://app.ligdicash.com/pay/v02/debitwallet/withotp",
    headers=HEADERS, json=invoice, timeout=15,
)
print(f"  Status: {r.status_code}")
print(f"  Response: {r.text[:400]}")

# ============================================================
# Test 3: Confirm SANS otp (champ vide) - voir si erreur differente
# ============================================================
print("\n[3] Confirm SANS OTP (otp=''):")
invoice2 = json.loads(json.dumps(invoice))
invoice2["commande"]["invoice"]["otp"] = ""
invoice2["commande"]["invoice"]["external_id"] = f"diag-nootp-{int(time.time())}"
r = requests.post(
    "https://app.ligdicash.com/pay/v02/debitwallet/withotp",
    headers=HEADERS, json=invoice2, timeout=15,
)
print(f"  Status: {r.status_code}")
print(f"  Response: {r.text[:400]}")

# ============================================================
# Test 4: Montant plus eleve (1000 FCFA) - minimum ?
# ============================================================
print("\n[4] Test OTP avec 1000 FCFA:")
r = requests.get(
    f"https://app.ligdicash.com/pay/v02/debitotp/{PHONE}/1000",
    headers=HEADERS, timeout=15,
)
print(f"  Status: {r.status_code}")
print(f"  Response: {r.text[:300]}")

# ============================================================
# Test 5: Payin REDIRECT (alternative qui fonctionne ?)
# ============================================================
print("\n[5] Payin REDIRECT (100 FCFA):")
redirect_body = {
    "commande": {
        "invoice": {
            "items": [{"name": "Credits Academia", "description": "Achat credits", "quantity": 1, "unit_price": 100, "total_price": 100}],
            "total_amount": 100,
            "devise": "XOF",
            "description": "Achat credits Academia",
            "customer": "",
            "customer_firstname": "Test",
            "customer_lastname": "User",
            "customer_email": "test@test.com",
            "external_id": f"redirect-test-{int(time.time())}",
            "otp": "",
        },
        "store": {"name": "Academia", "website_url": "https://nexiomgroup.space"},
        "actions": {
            "cancel_url": "https://nexiomgroup.space/cancel",
            "return_url": "https://nexiomgroup.space/success",
            "callback_url": "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-callback",
        },
        "custom_data": {"test": "true"},
    }
}
r = requests.post(
    "https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/create",
    headers=HEADERS, json=redirect_body, timeout=15,
)
print(f"  Status: {r.status_code}")
resp5 = r.json() if r.status_code == 200 else {}
print(f"  Response code: {resp5.get('response_code')}")
print(f"  Response text: {str(resp5.get('response_text',''))[:200]}")
print(f"  Token: {str(resp5.get('token',''))[:50]}")

# ============================================================
# Test 6: Verifier si le montant minimum est un probleme
# ============================================================
print("\n[6] Redirect avec 500 FCFA:")
redirect_body2 = json.loads(json.dumps(redirect_body))
redirect_body2["commande"]["invoice"]["items"][0]["unit_price"] = 500
redirect_body2["commande"]["invoice"]["items"][0]["total_price"] = 500
redirect_body2["commande"]["invoice"]["total_amount"] = 500
redirect_body2["commande"]["invoice"]["external_id"] = f"redir500-{int(time.time())}"
r = requests.post(
    "https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/create",
    headers=HEADERS, json=redirect_body2, timeout=15,
)
resp6 = r.json() if r.status_code == 200 else {}
print(f"  Response code: {resp6.get('response_code')}")
print(f"  Response text: {str(resp6.get('response_text',''))[:200]}")

# ============================================================
# Test 7: debitwallet/withotp avec montant plus eleve (1000)
# ============================================================
print("\n[7] Confirm OTP 1000 FCFA (OTP bidon):")
invoice3 = json.loads(json.dumps(invoice))
invoice3["commande"]["invoice"]["items"][0]["unit_price"] = 1000
invoice3["commande"]["invoice"]["items"][0]["total_price"] = 1000
invoice3["commande"]["invoice"]["total_amount"] = 1000
invoice3["commande"]["invoice"]["external_id"] = f"diag1000-{int(time.time())}"
invoice3["commande"]["invoice"]["otp"] = "999999"
r = requests.post(
    "https://app.ligdicash.com/pay/v02/debitwallet/withotp",
    headers=HEADERS, json=invoice3, timeout=15,
)
print(f"  Status: {r.status_code}")
print(f"  Response: {r.text[:400]}")

print("\n" + "=" * 65)
print("  CONCLUSION")
print("=" * 65)
print("""
Si tous les tests debitwallet/withotp echouent avec Code15,
meme avec un OTP valide, cela signifie probablement:
1. Le projet LigdiCash est en mode TEST et ne supporte pas debitwallet/withotp
2. Ou le montant minimum est > 100 FCFA pour cette methode
3. Ou le compte marchand n'a pas assez de solde de garantie

SOLUTION: Utiliser le Payin REDIRECT (option A) qui fonctionne
en mode test, au lieu du Payin OTP (option B).
""")
