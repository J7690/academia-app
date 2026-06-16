# Rapport Détaillé — Intégration API LigdiCash (Phase Test)

> Date : 7 Avril 2026  
> Source : documentation officielle https://developers.ligdicash.com + SDK GitHub + audit Edge Functions Academia

---

## 1. PRÉSENTATION GÉNÉRALE

**LigdiCash** est un agrégateur de paiement mobile money basé au Burkina Faso, opérant dans 8 pays (BF, Mali, Niger, Togo, Bénin, CI, Sénégal, Guinée).

### Authentification API
Chaque requête nécessite **2 identifiants** dans les headers HTTP :
- **`Apikey`** : clé API du projet (ex: `REV...4I4O`)
- **`Authorization`** : `Bearer {auth_token}` — jeton d'authentification JWT

Ces 2 identifiants sont générés lors de la création d'un **Projet API** sur le dashboard LigdiCash : https://dashboard.ligdicash.com

### Mode Test vs Live
Les SDKs officiels (PHP, JS, Dart) utilisent un paramètre `platform` :
- `platform: "test"` → **Mode test** (sandbox interne LigdiCash)
- `platform: "live"` → **Mode production**

> **IMPORTANT** : La documentation officielle ne mentionne PAS d'URLs différentes pour test/live.
> Les URLs restent les mêmes (`app.ligdicash.com/pay/...`). C'est le **projet API lui-même** qui est configuré en test ou live côté LigdiCash. Un compte test utilise les mêmes endpoints mais les transactions sont simulées côté serveur LigdiCash.

---

## 2. PAYIN — Collecter de l'argent (2 options)

Le **Payin** permet au marchand de recevoir un paiement d'un client.

### Option A : Payin avec redirection
**URL** : `POST https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/create`

**Principe** : Le marchand envoie une facture à LigdiCash. LigdiCash retourne un **lien de paiement** vers lequel on redirige le client. Le client choisit lui-même son opérateur (Orange Money, Moov Money, etc.) sur la page LigdiCash.

**Flow** :
1. `POST /pay/v01/redirect/checkout-invoice/create` → reçoit `response_code: "00"` + `response_text` (URL de paiement) + `token`
2. Rediriger le client vers l'URL de paiement
3. Le client paie sur la page LigdiCash (choix opérateur, saisie OTP)
4. Redirection vers `return_url` (succès) ou `cancel_url` (annulation)
5. Vérifier le statut : `GET /pay/v01/redirect/checkout-invoice/confirm/?invoiceToken={token}`
6. Callback POST envoyé automatiquement par LigdiCash à `callback_url`

**Corps de la requête** :
```json
{
  "commande": {
    "invoice": {
      "items": [
        { "name": "Produit", "description": "...", "quantity": 1, "unit_price": 1000, "total_price": 1000 }
      ],
      "total_amount": 1000,
      "devise": "XOF",
      "description": "Description paiement",
      "customer": "",
      "customer_firstname": "Prénom",
      "customer_lastname": "Nom",
      "customer_email": "email@example.com",
      "external_id": "",
      "otp": ""
    },
    "store": {
      "name": "Academia",
      "website_url": "https://nexiomgroup.space"
    },
    "actions": {
      "cancel_url": "https://...",
      "return_url": "https://...",
      "callback_url": "https://...votre-callback"
    },
    "custom_data": {
      "order_id": "ORD-123",
      "transaction_id": "TXN-123"
    }
  }
}
```

**Avantages** :
- Simple à intégrer (pas de gestion OTP côté marchand)
- LigdiCash gère tout le front de paiement
- Supporte TOUS les opérateurs du contrat sans code supplémentaire

**Inconvénients** :
- L'utilisateur quitte l'app/site → expérience moins fluide sur mobile
- Pas de contrôle sur l'UI de paiement

**Pour Academia** : ⚠️ **Moins adapté pour une app mobile** car nécessite d'ouvrir un navigateur web.

---

### Option B : Payin sans redirection (OTP)
**URLs** :
- Étape 1 : `GET https://app.ligdicash.com/pay/v02/debitotp/{phone_number}/{amount}` → envoie l'OTP au client
- Étape 2 : `POST https://app.ligdicash.com/pay/v02/debitwallet/withotp` → valide le paiement avec l'OTP

**Principe** : Le marchand collecte le numéro de téléphone et le montant, envoie une requête pour générer un OTP. Le client reçoit l'OTP par SMS, le communique au marchand qui le valide.

**Flow** :
1. Recueillir numéro de téléphone du client (préfixé indicatif pays : `226XXXXXXXX`)
2. `GET /pay/v02/debitotp/{phone}/{amount}` → LigdiCash envoie OTP par SMS au client
3. Réponse : `{ "error": false, "message": "OTP sent. Please check your phone." }`
4. Le client saisit l'OTP dans l'app
5. `POST /pay/v02/debitwallet/withotp` avec l'OTP + facture complète
6. Réponse : `{ "response_code": "00", "token": "eyJ..." }`
7. Vérifier le statut : `GET /pay/v01/redirect/checkout-invoice/confirm/?invoiceToken={token}`
8. `response_code == "00"` ET `status == "completed"` → paiement réussi

**Corps de l'étape 2 (validation OTP)** :
```json
{
  "commande": {
    "invoice": {
      "items": [...],
      "total_amount": 16000,
      "devise": "XOF",
      "description": "...",
      "customer": "226XXXXXXXX",
      "customer_firstname": "...",
      "customer_lastname": "...",
      "customer_email": "...",
      "external_id": "",
      "otp": "XXXXXX"
    },
    "store": { "name": "Academia", "website_url": "https://nexiomgroup.space" },
    "actions": {
      "cancel_url": "",
      "return_url": "",
      "callback_url": "https://...votre-callback"
    },
    "custom_data": { "payment_id": "...", "payment_type": "..." }
  }
}
```

**Avantages** :
- Expérience native dans l'app (pas de redirection)
- Contrôle total sur l'UI
- Parfait pour les apps mobiles

**Inconvénients** :
- Plus complexe à implémenter (2 étapes)
- Le marchand doit gérer la logique OTP
- Nécessite de connaître le fonctionnement de chaque opérateur

**Pour Academia** : ✅ **C'est l'option retenue** dans nos Edge Functions actuelles.

---

## 3. PAYOUT — Envoyer de l'argent (2 options via le paramètre `top_up_wallet`)

Le **Payout** permet au marchand d'envoyer de l'argent vers un bénéficiaire.

**URL unique** : `POST https://app.ligdicash.com/pay/v01/withdrawal/create`

Le paramètre clé est **`top_up_wallet`** qui détermine la destination :

### Option A : Payout vers le Wallet LigdiCash (`top_up_wallet: 1`)
L'argent est transféré du compte marchand vers le **portefeuille LigdiCash du client**.
- Le client doit avoir un compte LigdiCash
- L'argent reste dans son wallet LigdiCash
- Le client peut ensuite retirer vers son mobile money depuis l'app LigdiCash

**Avantages** : Instantané, pas de frais opérateur intermédiaire
**Inconvénients** : Le bénéficiaire doit avoir un compte LigdiCash

### Option B : Payout vers Mobile Money (`top_up_wallet: 0`)
L'argent transite par le wallet LigdiCash du client puis est automatiquement envoyé vers son **compte mobile money** (Orange Money, Moov Money, etc.).
- Le numéro de téléphone du client doit être associé à un portefeuille mobile money
- L'opérateur est déterminé automatiquement par le numéro de téléphone

**Avantages** : L'argent arrive directement sur le mobile money du bénéficiaire
**Inconvénients** : Peut avoir un léger délai supplémentaire

### Corps de la requête Payout :
```json
{
  "commande": {
    "amount": 5000,
    "description": "Versement commission enseignant",
    "customer": "226XXXXXXXX",
    "custom_data": {
      "payout_id": "...",
      "beneficiary_type": "instructor"
    },
    "callback_url": "https://...votre-callback-payout",
    "top_up_wallet": 0
  }
}
```

### Vérification du Payout :
```
GET https://app.ligdicash.com/pay/v01/withdrawal/confirm/?withdrawalToken={token}
```
Réponse : `response_code == "00"` ET `status == "completed"` → payout réussi.

**Pour Academia** : ✅ **`top_up_wallet: 0`** est retenu (envoi direct vers mobile money). C'est déjà configuré dans notre Edge Function `ligdicash-payout`.

---

## 4. LE CALLBACK (Webhook)

**Principe** : À chaque transaction réussie, LigdiCash envoie automatiquement un POST à l'URL callback définie.

**IMPORTANT** — LigdiCash envoie **2 requêtes POST** distinctes :
1. `Content-Type: application/x-www-form-urlencoded`
2. `Content-Type: application/json`

Les deux contiennent les mêmes données. **Il faut gérer la déduplication** pour ne pas livrer le service deux fois.

**Données reçues** :
- `token` — le token de la transaction
- `transaction_id` — ID de la transaction LigdiCash
- `status` — statut ("completed", "pending", etc.)
- `amount` / `montant` — montant
- `operator_name` — nom de l'opérateur (ex: "ORANGE BURKINA")
- `custom_data` — données personnalisées (notre payment_id, payment_type)

**Recommandation** : Toujours vérifier le statut via l'API de vérification avant de valider, même après réception du callback (anti-fraude).

---

## 5. PROTOCOLE D'INTÉGRATION (10 étapes)

1. **Contacter le Partner Manager** — BF : sabine.traore@ligdicash.com
2. **Remplir le KYC** (Know Your Customer)
3. **Négocier et signer le contrat** (commissions)
4. **Recevoir une formation** des techniciens LigdiCash
5. **Créer votre projet API** sur https://dashboard.ligdicash.com
6. **Demander l'activation** du projet
7. **Commencer l'intégration** (requêtes HTTP)
8. **Tester** en conditions réelles (compte test)
9. **Mettre en production** (prévenir LigdiCash)
10. **Support** : support@ligdicash.com / +226 61090987 / groupe WhatsApp

---

## 6. IDENTIFIANTS ET HEADERS

### Headers requis pour CHAQUE requête :
```
Apikey: {VOTRE_API_KEY}
Authorization: Bearer {VOTRE_AUTH_TOKEN}
Accept: application/json
Content-Type: application/json
```

### Correspondance avec nos secrets Supabase :
| Secret Supabase          | Rôle                           | Header HTTP        |
|--------------------------|--------------------------------|--------------------|
| `LIGDICASH_API_KEY`      | API Key du projet              | `Apikey`           |
| `LIGDICASH_BEARER_TOKEN` | Auth Token (JWT Bearer)        | `Authorization`    |
| `LIGDICASH_MODE`         | `test` / `live` (notre switch) | N/A (logique code) |

---

## 7. AUDIT — Comparaison Edge Functions vs Documentation Officielle

### ✅ `ligdicash-initiate` (Payin sans redirection — Étape 1)
- **Conforme** : Utilise `GET /pay/v02/debitotp/{phone}/{amount}` ✅
- **Headers** : Apikey + Bearer ✅
- **Mode mock** : OTP simulé "123456" ✅
- **Validation** : Vérifie ownership, status, phone ✅

### ✅ `ligdicash-confirm` (Payin sans redirection — Étape 2)
- **Conforme** : Utilise `POST /pay/v02/debitwallet/withotp` ✅
- **Corps facture** : Structure invoice/items/store/actions/custom_data ✅
- **Vérification** : Appelle `/pay/v01/redirect/checkout-invoice/confirm/` avec le token ✅
- **Champs customer** : Préfixé indicatif pays ✅
- **OTP** : Passé dans le corps de la facture ✅

### ✅ `ligdicash-callback` (Webhook)
- **Conforme** : Gère les 2 Content-Types (JSON + form-urlencoded) ✅
- **Déduplication** : Via RPC idempotente (already_confirmed) ✅
- **Anti-fraude** : Re-vérifie via API en mode live ✅
- **Toujours 200** : Ne bloque pas la retry queue de LigdiCash ✅

### ✅ `ligdicash-payout` (Payout vers mobile money)
- **Conforme** : Utilise `POST /pay/v01/withdrawal/create` ✅
- **`top_up_wallet: 0`** : Envoi direct vers mobile money ✅
- **Vérification** : Appelle `/pay/v01/withdrawal/confirm/` ✅
- **Callback** : Configuré ✅

### Verdict : Les 4 Edge Functions sont **conformes** à la documentation officielle.

---

## 8. MISE EN PLACE DU COMPTE TEST

### Ce que vous avez reçu (ou devez recevoir) de LigdiCash :
1. **API Key** — chaîne de caractères (ex: `81JXXXXX...DH8C`)
2. **Auth Token** — JWT long (ex: `eyJ0eXAiOiJKV1QiLC...`)

### Configuration dans Supabase :
```bash
supabase secrets set LIGDICASH_API_KEY="votre_api_key_test"
supabase secrets set LIGDICASH_BEARER_TOKEN="votre_auth_token_test"
supabase secrets set LIGDICASH_MODE="test"
```

> **Note** : Pour le mode test, mettre `LIGDICASH_MODE=test` au lieu de `mock`. Actuellement nos Edge Functions switchent sur `live` ou autre chose (mock par défaut). Le mode `test` devra utiliser les vrais endpoints LigdiCash mais avec des credentials de test. Il faudra ajuster la condition de `LIGDICASH_MODE === 'live'` à `LIGDICASH_MODE !== 'mock'` pour que le mode `test` appelle aussi les vrais endpoints.

---

## 9. CHANGEMENT NÉCESSAIRE DANS LES EDGE FUNCTIONS

Actuellement, la condition est :
```typescript
if (LIGDICASH_MODE === 'live' && LIGDICASH_API_KEY && LIGDICASH_BEARER_TOKEN)
```

Cela signifie que **seul le mode `live` appelle les vrais endpoints**. En mode `test`, les Edge Functions tomberaient dans le `else` (mock).

**Correction proposée** :
```typescript
if (LIGDICASH_MODE !== 'mock' && LIGDICASH_API_KEY && LIGDICASH_BEARER_TOKEN)
```

Ainsi :
- `LIGDICASH_MODE=mock` → simulation locale (pas d'appel LigdiCash)
- `LIGDICASH_MODE=test` → appelle les vrais endpoints LigdiCash avec credentials test
- `LIGDICASH_MODE=live` → appelle les vrais endpoints LigdiCash avec credentials live

---

## 10. RÉCAPITULATIF DES ENDPOINTS API

| Opération | Méthode | URL |
|-----------|---------|-----|
| **Payin Redirection** — Créer facture | POST | `https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/create` |
| **Payin Sans Redir** — Envoyer OTP | GET | `https://app.ligdicash.com/pay/v02/debitotp/{phone}/{amount}` |
| **Payin Sans Redir** — Valider OTP | POST | `https://app.ligdicash.com/pay/v02/debitwallet/withotp` |
| **Vérifier Payin** | GET | `https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/confirm/?invoiceToken={token}` |
| **Payout** — Créer | POST | `https://app.ligdicash.com/pay/v01/withdrawal/create` |
| **Vérifier Payout** | GET | `https://app.ligdicash.com/pay/v01/withdrawal/confirm/?withdrawalToken={token}` |

---

## 11. LIBRAIRIES OFFICIELLES

| Langage | Package |
|---------|---------|
| **Dart/Flutter** | `ligdicash: ^1.0.2` (pub.dev) |
| **JavaScript/Node** | `npm install ligdicash` |
| **PHP** | `composer require ligdicash/ligdicash` |
| **Python** | `pip install ligdicash` |
| **Java** | ZIP téléchargeable |

---

## 12. PROCHAINES ÉTAPES

1. ⏳ **Fournir les credentials test** (API Key + Auth Token) reçus de LigdiCash
2. 🔧 **Configurer les secrets Supabase** avec ces credentials
3. 🔧 **Modifier les 4 Edge Functions** : `=== 'live'` → `!== 'mock'` pour supporter le mode `test`
4. 🚀 **Déployer les Edge Functions** :
   ```bash
   supabase functions deploy ligdicash-initiate --no-verify-jwt
   supabase functions deploy ligdicash-confirm --no-verify-jwt
   supabase functions deploy ligdicash-callback --no-verify-jwt
   supabase functions deploy ligdicash-payout --no-verify-jwt
   ```
5. 🧪 **Tester un Payin** avec un vrai numéro BF (petit montant)
6. 🧪 **Tester un Payout** (si le solde marchand test le permet)
7. ✅ **Valider avec LigdiCash** avant passage en production
