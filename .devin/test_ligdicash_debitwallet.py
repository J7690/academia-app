#!/usr/bin/env python3
"""Test direct /pay/v02/debitwallet/withotp pour voir la vraie erreur LigdiCash."""

import requests, json

API_KEY = "9PH1085D51ZAFC1UE"
AUTH_TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZF9hcHAiOiIzMTYyMiIsImlkX2Fib25uZSI6MTEzNjc0NCwiZGF0ZWNyZWF0aW9uX2FwcCI6IjIwMjYtMDQtMDcgMDk6NDU6MDgifQ.AxDrB8subflKTCyfvQ8bV6nfDb3rmET2PlBbSCyi5ow"

HEADERS = {
    "Apikey": API_KEY,
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

# Simuler exactement ce que ligdicash-confirm envoie
body = {
    "commande": {
        "invoice": {
            "items": [{"name": "Test 100 XOF", "description": "Test paiement", "quantity": 1, "unit_price": 100, "total_price": 100}],
            "total_amount": 100,
            "devise": "XOF",
            "description": "Test paiement credit_purchase",
            "customer": "22666660538",
            "customer_firstname": "Test",
            "customer_lastname": "Academia",
            "customer_email": "nexiomgroup@gmail.com",
            "external_id": "test-direct-001",
            "otp": "000000",  # Faux OTP pour voir quelle erreur on obtient
        },
        "store": {"name": "Academia", "website_url": "https://nexiomgroup.space"},
        "actions": {
            "cancel_url": "",
            "return_url": "",
            "callback_url": "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-callback",
        },
        "custom_data": {"payment_id": "test-direct-001", "payment_type": "application"},
    }
}

print("=== TEST: POST /pay/v02/debitwallet/withotp ===")
print(f"Phone: 22666660538, Amount: 100 XOF, OTP: 000000 (faux)")
r = requests.post(
    "https://app.ligdicash.com/pay/v02/debitwallet/withotp",
    headers=HEADERS,
    json=body,
    timeout=30,
)
print(f"HTTP Status: {r.status_code}")
try:
    data = r.json()
    print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
    code = data.get("response_code", "??")
    text = data.get("response_text", "??")
    desc = data.get("description", "")
    print(f"\nCode: {code}")
    print(f"Text: {text}")
    print(f"Desc: {desc}")
    if code != "00":
        print(f"\nERREUR LigdiCash: {text} / {desc}")
        print(f"Signification codes:")
        codes = {
            "01": "Echec (solde insuffisant ou transaction refusee)",
            "02": "OTP invalide",
            "03": "Transaction expiree",
            "04": "Wallet introuvable",
            "05": "Numero non enregistre sur le reseau",
            "06": "Compte marchand non approvisionne",
            "07": "Montant inferieur au minimum autorise",
            "08": "Montant superieur au maximum autorise",
        }
        print(f"  Code {code}: {codes.get(code, 'Inconnu')}")
except Exception as e:
    print(f"Erreur parsing: {e}")
    print(f"Raw: {r.text[:500]}")

# Check minimum amount LigdiCash
print("\n=== TEST: Minimum montant ===")
body2 = body.copy()
body2["commande"] = dict(body["commande"])
body2["commande"]["invoice"] = dict(body["commande"]["invoice"])
body2["commande"]["invoice"]["total_amount"] = 1
body2["commande"]["invoice"]["items"] = [{"name": "Test 1 XOF", "description": "Test", "quantity": 1, "unit_price": 1, "total_price": 1}]

r2 = requests.post(
    "https://app.ligdicash.com/pay/v02/debitwallet/withotp",
    headers=HEADERS,
    json=body2,
    timeout=30,
)
print(f"HTTP Status: {r2.status_code}")
try:
    d2 = r2.json()
    print(f"Code: {d2.get('response_code')}, Text: {d2.get('response_text')}")
except Exception:
    print(f"Raw: {r2.text[:200]}")

print("\nDone.")
