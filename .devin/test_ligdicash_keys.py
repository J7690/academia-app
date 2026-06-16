#!/usr/bin/env python3
"""Test direct des clés API LigdiCash — vérifie si le projet est activé et fonctionnel."""

import requests
import json

API_KEY = "9PH1085D51ZAFC1UE"
AUTH_TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZF9hcHAiOiIzMTYyMiIsImlkX2Fib25uZSI6MTEzNjc0NCwiZGF0ZWNyZWF0aW9uX2FwcCI6IjIwMjYtMDQtMDcgMDk6NDU6MDgifQ.AxDrB8subflKTCyfvQ8bV6nfDb3rmET2PlBbSCyi5ow"

HEADERS = {
    "Apikey": API_KEY,
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

print("=" * 60)
print("TEST DIRECT API LIGDICASH — Clés Test")
print("=" * 60)

# Test 1: Envoyer OTP (Payin sans redirection — étape 1)
# On utilise un faux numéro pour voir la réponse de LigdiCash
# Si le projet n'est pas activé, on aura une erreur spécifique
print("\n--- TEST 1: Payin OTP (GET /pay/v02/debitotp/{phone}/{amount}) ---")
test_phone = "22670000000"  # Faux numéro test
test_amount = 100

url = f"https://app.ligdicash.com/pay/v02/debitotp/{test_phone}/{test_amount}"
print(f"  URL: {url}")

try:
    r = requests.get(url, headers=HEADERS, timeout=15)
    print(f"  HTTP Status: {r.status_code}")
    print(f"  Response: {r.text[:500]}")
    
    try:
        data = r.json()
        if data.get("error") == False:
            print(f"\n  ✅ API FONCTIONNE ! OTP envoyé (ou simulé)")
        elif "not activated" in str(data).lower() or "not active" in str(data).lower() or "inactive" in str(data).lower():
            print(f"\n  ❌ PROJET NON ACTIVÉ — Contactez LigdiCash pour activation")
        elif "unauthorized" in str(data).lower() or "invalid" in str(data).lower():
            print(f"\n  ❌ CLÉS INVALIDES — Vérifiez API Key et Auth Token")
        else:
            print(f"\n  ⚠️ Réponse inattendue — voir détails ci-dessus")
    except:
        print(f"\n  ⚠️ Réponse non-JSON")
except Exception as e:
    print(f"  ❌ ERREUR CONNEXION: {e}")

# Test 2: Créer une facture (Payin avec redirection)
# Ceci teste aussi l'auth mais avec un endpoint différent
print("\n--- TEST 2: Payin Redirection (POST /pay/v01/redirect/checkout-invoice/create) ---")
invoice_body = {
    "commande": {
        "invoice": {
            "items": [{"name": "Test Academia", "description": "Test de connectivité", "quantity": 1, "unit_price": 100, "total_price": 100}],
            "total_amount": 100,
            "devise": "XOF",
            "description": "Test de connectivité API LigdiCash",
            "customer": "",
            "customer_firstname": "Test",
            "customer_lastname": "Academia",
            "customer_email": "test@academia.com",
            "external_id": "TEST-001",
            "otp": ""
        },
        "store": {
            "name": "Academia",
            "website_url": "https://nexiomgroup.space"
        },
        "actions": {
            "cancel_url": "https://nexiomgroup.space/cancel",
            "return_url": "https://nexiomgroup.space/success",
            "callback_url": "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-callback"
        },
        "custom_data": {
            "test": "true",
            "source": "academia_key_test"
        }
    }
}

try:
    r2 = requests.post(
        "https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/create",
        headers=HEADERS,
        json=invoice_body,
        timeout=15,
    )
    print(f"  HTTP Status: {r2.status_code}")
    print(f"  Response: {r2.text[:500]}")
    
    try:
        data2 = r2.json()
        if data2.get("response_code") == "00":
            print(f"\n  ✅ FACTURE CRÉÉE ! Token: {data2.get('token','')[:50]}...")
            print(f"  Lien paiement: {data2.get('response_text','')[:100]}...")
            print(f"\n  → Les clés sont VALIDES et le projet est ACTIVÉ !")
        elif "response_code" in data2:
            print(f"\n  ⚠️ Code réponse: {data2.get('response_code')} — {data2.get('response_text','')}")
        else:
            print(f"\n  ⚠️ Réponse inattendue")
    except:
        print(f"\n  ⚠️ Réponse non-JSON")
except Exception as e:
    print(f"  ❌ ERREUR CONNEXION: {e}")

# Test 3: Vérifier le solde marchand (optionnel)
print("\n--- TEST 3: Payout (POST /pay/v01/withdrawal/create) — test avec petit montant ---")
payout_body = {
    "commande": {
        "amount": 1,
        "description": "Test payout Academia",
        "customer": test_phone,
        "custom_data": {"test": "true"},
        "callback_url": "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-callback",
        "top_up_wallet": 0
    }
}

try:
    r3 = requests.post(
        "https://app.ligdicash.com/pay/v01/withdrawal/create",
        headers=HEADERS,
        json=payout_body,
        timeout=15,
    )
    print(f"  HTTP Status: {r3.status_code}")
    print(f"  Response: {r3.text[:500]}")
    
    try:
        data3 = r3.json()
        if data3.get("response_code") == "00":
            print(f"\n  ✅ PAYOUT OK — Le compte marchand a un solde")
        elif "insufficient" in str(data3).lower() or "solde" in str(data3).lower() or "balance" in str(data3).lower():
            print(f"\n  ⚠️ SOLDE INSUFFISANT — Normal en mode test, le payin doit d'abord fonctionner")
        else:
            print(f"\n  ⚠️ Réponse: voir ci-dessus")
    except:
        pass
except Exception as e:
    print(f"  ❌ ERREUR: {e}")

print("\n" + "=" * 60)
print("FIN DES TESTS")
print("=" * 60)
