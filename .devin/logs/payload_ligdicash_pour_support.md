# Payloads envoyés à LigdiCash — Pour l'équipe support

> Date : 16 Avril 2026
> Projet API : 31622 (API Key prefix: 9PH1085D...)
> Mode : test

---

## Étape 1 — Envoi OTP (fonctionne ✅)

**Requête :**
```
GET https://app.ligdicash.com/pay/v02/debitotp/22666660538/100
```

**Headers :**
```
Apikey: 9PH1085D51ZAFC1UE
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZF9hcHAiOiIzMTYyMiIsImlkX2Fib25uZSI6MTEzNjc0NCwiZGF0ZWNyZWF0aW9uX2FwcCI6IjIwMjYtMDQtMDcgMDk6NDU6MDgifQ.AxDrB8subflKTCyfvQ8bV6nfDb3rmET2PlBbSCyi5ow
Accept: application/json
Content-Type: application/json
```

**Réponse reçue (succès) :**
```json
{
  "error": false,
  "message": "OTP sent. Please check your phone."
}
```

→ L'OTP est bien reçu par SMS sur le téléphone +226 66 66 05 38.

---

## Étape 2 — Validation OTP (échoue ❌ Code15)

**Requête :**
```
POST https://app.ligdicash.com/pay/v02/debitwallet/withotp
```

**Headers :**
```
Apikey: 9PH1085D51ZAFC1UE
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZF9hcHAiOiIzMTYyMiIsImlkX2Fib25uZSI6MTEzNjc0NCwiZGF0ZWNyZWF0aW9uX2FwcCI6IjIwMjYtMDQtMDcgMDk6NDU6MDgifQ.AxDrB8subflKTCyfvQ8bV6nfDb3rmET2PlBbSCyi5ow
Accept: application/json
Content-Type: application/json
```

**Body envoyé :**
```json
{
  "commande": {
    "invoice": {
      "items": [
        {
          "name": "Achat credits Academia",
          "description": "Achat credits Academia",
          "quantity": 1,
          "unit_price": 100,
          "total_price": 100
        }
      ],
      "total_amount": 100,
      "devise": "XOF",
      "description": "Achat credits Academia",
      "customer": "22666660538",
      "customer_firstname": "Test",
      "customer_lastname": "User",
      "customer_email": "test@test.com",
      "external_id": "ab8dc18d-2367-40a8-a7e3-4fe5a6f38f99",
      "otp": "XXXXXX"
    },
    "store": {
      "name": "Academia",
      "website_url": "https://nexiomgroup.space"
    },
    "actions": {
      "cancel_url": "",
      "return_url": "",
      "callback_url": "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-callback"
    },
    "custom_data": {
      "payment_id": "ab8dc18d-2367-40a8-a7e3-4fe5a6f38f99",
      "payment_type": "credit_purchase"
    }
  }
}
```

**Réponse reçue (échec) :**
```json
{
  "response_code": "01",
  "token": "",
  "response_text": "Echec (Code15)",
  "description": "",
  "custom_data": [],
  "wiki": "https://client.ligdicash.com/wiki/createInvoice"
}
```

---

## Tests effectués

| Test | OTP | Montant | Résultat |
|------|-----|---------|----------|
| OTP bidon | 000000 | 100 XOF | Echec (Code15) |
| OTP bidon | 999999 | 1000 XOF | Echec (Code15) |
| Sans OTP | (vide) | 100 XOF | Echec (Code08) "You must specify password or otp" |
| OTP réel reçu par SMS | XXXXXX | 100 XOF | Echec (Code15) |

→ Le Code15 est systématique quel que soit l'OTP ou le montant.
→ L'étape 1 (debitotp) fonctionne correctement.
→ L'étape 2 (debitwallet/withotp) échoue toujours avec Code15.

**Question pour l'équipe LigdiCash :**
1. Que signifie exactement le Code15 dans ce contexte ?
2. L'endpoint `POST /pay/v02/debitwallet/withotp` est-il activé sur notre projet API (ID 31622) ?
3. Y a-t-il une configuration supplémentaire nécessaire pour utiliser le Payin sans redirection (OTP) en mode test ?
