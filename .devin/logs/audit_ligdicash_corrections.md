# AUDIT LIGDICASH — Erreurs identifiées et corrections proposées

> Date : 16 Avril 2026
> Source : Documentation officielle https://developers.ligdicash.com/api1/payin-sans-redirection + réponse support LigdiCash

---

## RÉSUMÉ

La documentation LigdiCash "Payin sans redirection" décrit **DEUX flux différents** :

| Flux | Étape 1 (Envoi OTP) | Étape 2 (Validation) | Débite quoi ? |
|------|---------------------|---------------------|---------------|
| **Portefeuille LigdiCash** | `GET /pay/v02/debitotp/{phone}/{amount}` | `POST /pay/v02/debitwallet/withotp` | Portefeuille LigdiCash du client |
| **Orange Money / Moov Money** | `GET /pay/v02/debitotp/{phone}/{amount}` | `POST /pay/v01/straight/checkout-invoice/create` | Compte mobile money du client |

→ **L'étape 1 est identique** pour les deux flux.
→ **L'étape 2 utilise des endpoints différents** selon l'opérateur.

---

## ERREUR #1 — `ligdicash-confirm` : mauvais endpoint de validation (CRITIQUE)

**Fichier** : `supabase/functions/ligdicash-confirm/index.ts` — **ligne 130**

**Actuel (FAUX)** :
```typescript
const lgResponse = await fetch('https://app.ligdicash.com/pay/v02/debitwallet/withotp', {
```

**Problème** : Cet endpoint est pour le **Portefeuille LigdiCash**, pas pour Orange Money / Moov Money. C'est la cause directe du Code15 : le système essaie de débiter un portefeuille LigdiCash que le client n'a pas (ou qui n'a pas de solde).

**Correction proposée** :
```typescript
const lgResponse = await fetch('https://app.ligdicash.com/pay/v01/straight/checkout-invoice/create', {
```

→ Cet endpoint débite le **compte mobile money** (Orange/Moov) du client.

---

## ERREUR #2 — `ligdicash-confirm` : gestion de la réponse asynchrone

**Fichier** : `supabase/functions/ligdicash-confirm/index.ts` — **lignes 144-180**

**Problème** : Avec `straight/checkout-invoice/create`, la réponse est **asynchrone** :
```json
{
  "response_code": "00",
  "response_text": "La requête est en cours de traitement",
  "token": "eyJ0eXAi..."
}
```
Le paiement n'est PAS immédiatement `completed`. Il faut :
1. Soit attendre le **callback** LigdiCash
2. Soit **polling** du statut avec le token

**Code actuel** (lignes 165-180) : vérifie immédiatement le statut, et si pas `completed`, retourne `{ success: true, status: 'processing' }` — **c'est déjà géré correctement**. La logique existante fonctionne, aucune modification nécessaire ici.

---

## ERREUR #3 — `ligdicash-initiate` : commentaire trompeur (mineur)

**Fichier** : `supabase/functions/ligdicash-initiate/index.ts` — **lignes 5-6**

**Actuel** :
```typescript
// Mode mock : retourne succès sans appeler LigdiCash (LIGDICASH_MODE != 'live')
// Mode live : appelle GET /pay/v02/debitotp/{phone}/{amount}
```

**Correction proposée** : Mettre à jour le commentaire pour refléter que l'OTP est envoyé au mobile money du client (pas au portefeuille LigdiCash).

---

## ERREUR #4 — `ligdicash-confirm` : commentaire trompeur (mineur)

**Fichier** : `supabase/functions/ligdicash-confirm/index.ts` — **lignes 6, 105**

**Actuel** :
```typescript
// Mode live : POST /pay/v02/debitwallet/withotp + verify + RPC
// Step 1: POST /pay/v02/debitwallet/withotp
```

**Correction proposée** : Mettre à jour les commentaires.

---

## NOTE — URL de base test vs live

Le SDK officiel Dart utilise :
- **Test** : `https://test.ligdicash.com/pay/v01/`
- **Live** : `https://app.ligdicash.com/pay/v01/`

Actuellement nos Edge Functions utilisent `app.ligdicash.com` alors que `LIGDICASH_MODE=test`. Le `debitotp` fonctionne malgré tout sur `app.ligdicash.com`. **Pas de changement proposé pour l'instant** — à vérifier si `straight/checkout-invoice/create` fonctionne aussi sur `app.ligdicash.com` en mode test.

---

## RÉSUMÉ DES CORRECTIONS

| # | Fichier | Ligne | Type | Description |
|---|---------|-------|------|-------------|
| **1** | `ligdicash-confirm/index.ts` | 130 | **CRITIQUE** | Changer URL de `/pay/v02/debitwallet/withotp` vers `/pay/v01/straight/checkout-invoice/create` |
| 2 | `ligdicash-confirm/index.ts` | 142 | mineur | Mettre à jour le log `debitwallet response` → `straight response` |
| 3 | `ligdicash-confirm/index.ts` | 6, 105 | mineur | Mettre à jour commentaires |
| 4 | `ligdicash-initiate/index.ts` | 5-6 | mineur | Mettre à jour commentaires |

→ **Seule la correction #1 est bloquante.** Les autres sont cosmétiques.

---

## FLUX CORRIGÉ (après validation)

```
1. App Flutter → Edge Function ligdicash-initiate
   → GET https://app.ligdicash.com/pay/v02/debitotp/{phone}/{amount}
   → LigdiCash envoie OTP par SMS au client (Orange/Moov)
   ✅ FONCTIONNE DÉJÀ

2. Client reçoit OTP → saisit dans l'app

3. App Flutter → Edge Function ligdicash-confirm
   → POST https://app.ligdicash.com/pay/v01/straight/checkout-invoice/create
   → LigdiCash débite le compte Orange Money / Moov Money du client
   ❌ ACTUELLEMENT : /pay/v02/debitwallet/withotp (portefeuille LigdiCash)
   ✅ CORRIGÉ : /pay/v01/straight/checkout-invoice/create (mobile money)

4. Vérification statut avec token → callback → confirmation en DB
   ✅ LOGIQUE EXISTANTE OK
```
