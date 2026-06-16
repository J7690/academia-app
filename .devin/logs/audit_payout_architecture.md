# AUDIT PAYOUT — Architecture complète Academia
## Date: 17 Avril 2026

---

# 1. ÉTAT DES LIEUX — CE QUI EXISTE DÉJÀ

## 1.1 Flux Payin (entrée d'argent) — OPÉRATIONNEL
```
Étudiant/Client
    │ (Mobile Money: Orange/Moov/Telecel)
    ▼
[LigdiCash API - Payin sans redirection]
    │ USSD → OTP → straight/checkout-invoice/create → polling confirm
    ▼
[Compte Marchand LigdiCash Academia]
    │ L'argent arrive en "Liquidités Cash"
    ▼
[Supabase: application_payments / marketplace_payments confirmés]
```

**Edge Functions déployées:**
- `ligdicash-initiate` — retourne code USSD, pas d'appel API
- `ligdicash-confirm` — POST straight/checkout-invoice/create + polling
- `ligdicash-callback` — webhook backup LigdiCash (idempotent)

## 1.2 Flux Payout (sortie d'argent) — INFRASTRUCTURE PRÊTE, PAS ENCORE LIVE

### Edge Function `ligdicash-payout` (10 851 bytes)
- **Endpoint LigdiCash:** `POST /pay/v01/withdrawal/create`
- **Paramètre clé:** `top_up_wallet: 0` → envoie directement sur mobile money du bénéficiaire
- **Mode:** mock (simulé) ou live (réel)
- **Vérification:** `GET /pay/v01/withdrawal/confirm/?withdrawalToken=...`
- **Succès si:** `response_code == "00"` ET `status == "completed"`
- **Auth:** admin ou service_role (cron)
- **Traitement batch:** accepte `payout_ids[]` ou `all_pending: true`

### Tables DB existantes (schema `app`)

#### `app.payout_queue` — File d'attente des versements
| Colonne | Type | Rôle |
|---|---|---|
| id | uuid | PK |
| beneficiary_type | text | instructor / commercial / merchant / university |
| beneficiary_user_id | uuid | FK auth.users |
| beneficiary_phone | text | Numéro mobile money cible |
| amount | numeric | Montant à verser |
| currency | text | XOF |
| reason | text | instructor_revenue / commercial_commission / merchant_revenue |
| source_payment_id | uuid | FK application_payments |
| source_marketplace_payment_id | uuid | FK marketplace_payments |
| status | text | pending → processing → completed / failed |
| ligdicash_token | text | Token retourné par LigdiCash |
| ligdicash_transaction_id | text | ID transaction LigdiCash |
| processed_at | timestamptz | Date de traitement |
| error_message | text | Erreur éventuelle |
| retry_count | integer | Nombre de tentatives |
| created_at | timestamptz | |

#### `app.platform_ledger` — Grand livre plateforme
| Colonne | Type | Rôle |
|---|---|---|
| id | uuid | PK |
| transaction_type | text | payin / payout / commission / split |
| amount | numeric | |
| currency | text | XOF |
| direction | text | credit / debit |
| counterpart_type | text | student / instructor / commercial / merchant |
| counterpart_id | uuid | |
| reference_id | uuid | ID du paiement source |
| description | text | |
| balance_after | numeric | Solde après transaction |
| created_at | timestamptz | |

#### `app.actor_balances` — Soldes par acteur
| Colonne | Type | Rôle |
|---|---|---|
| id | uuid | PK |
| actor_type | text | instructor / commercial / merchant / university |
| actor_id | uuid | |
| available_balance | numeric | Solde retirable |
| pending_balance | numeric | En attente de confirmation |
| total_earned | numeric | Total cumulé |
| total_withdrawn | numeric | Total retiré |
| currency | text | XOF |
| updated_at | timestamptz | |

#### `app.revenue_split_rules` — Règles de répartition
| payment_reason | beneficiary_type | percentage | Description |
|---|---|---|---|
| application_fee | platform | 100% | *À DÉFINIR — courtage = 100% plateforme?* |
| credit_purchase | platform | 100% | |
| online_course | instructor | 60% | Part enseignant cours |
| online_course | commercial | 10% | Commission commercial |
| online_course | platform | 30% | Part plateforme |
| registration_fee | university | 70% | Part université inscription |
| registration_fee | platform | 15% | Part plateforme |
| registration_fee | commercial | 15% | Commission commercial |
| subscription | platform | 100% | Abonnement 100% plateforme |
| td_access | instructor | 55% | Rémunération enseignant TD |
| td_access | commercial | 15% | Commission commercial TD |
| td_access | platform | 30% | Part plateforme TD |
| tuition_deposit | university | 80% | Part université scolarité |
| tuition_deposit | commercial | 10% | Commission commercial |
| tuition_deposit | platform | 10% | Part plateforme |

### RPCs Payout existantes

| RPC | Acteur | Source solde | Mécanisme |
|---|---|---|---|
| `app_instructor_request_payout` | Enseignant | `actor_balances` (instructor) | Déduit balance → insert payout_queue |
| `app_commercial_request_payout` | Commercial | `referral_commissions` (approved) - déjà en queue | Calcule dispo → insert payout_queue |
| `app_merchant_request_payout` | Commerçant | `marketplace_merchant_balances` | Déduit balance → insert payout_queue |
| `app_university_request_payout` | Université | `actor_balances` (university) | Déduit balance → insert payout_queue |
| `app_admin_list_payout_queue` | Admin | — | Liste tous les payouts |
| `app_admin_list_actor_balances` | Admin | — | Liste tous les soldes |

### Flutter — Écrans Payout existants

| Fichier | Acteur | Fonctionnalités |
|---|---|---|
| `instructor_revenue_tab.dart` | Enseignant | Balance card + bouton retrait + config numéro payout |
| `commercial_dashboard_screen.dart` | Commercial | Dashboard commissions + bouton versement |
| `merchant_marketplace_console_screen_v2.dart` | Commerçant | Onglet revenus + bouton retrait |
| `university_revenue_tab.dart` | Université | Balance + bouton versement |

### Données actuelles
- **payout_queue:** 0 enregistrements (aucun payout demandé)
- **platform_ledger:** 0 enregistrements (aucune transaction enregistrée)
- **actor_balances:** Données non accessibles via REST (RLS restrict), mais les RPCs les consultent
- **revenue_split_rules:** 13 règles actives couvrant tous les payment_reasons
- **referral_commissions:** 0 enregistrements

---

# 2. FLUX PAYOUT — COMMENT ÇA FONCTIONNE

```
[Payin confirmé]
    │
    ▼
[RPC app_confirm_ligdicash_payment]
    │ Confirme le paiement
    │ ??? Trigger/RPC pour répartir selon revenue_split_rules ???
    ▼
[actor_balances mis à jour]
    │ Chaque bénéficiaire voit son available_balance augmenter
    ▼
[Acteur clique "Retirer"]  (Flutter UI)
    │ Appel RPC app_xxx_request_payout
    ▼
[payout_queue] status=pending
    │
    ▼
[Admin ou Cron déclenche ligdicash-payout Edge Function]
    │ POST /pay/v01/withdrawal/create (top_up_wallet=0)
    │ → Liquidités Cash Academia → Mobile Money bénéficiaire
    ▼
[LigdiCash confirme] → payout_queue.status=completed
    │ → platform_ledger entry (debit)
```

---

# 3. DÉCOUVERTE CRITIQUE — LE REVENUE SPLIT EST DÉJÀ AUTOMATISÉ

## 3.1 ✅ Revenue Split INTÉGRÉ dans `app_confirm_ligdicash_payment`
**Bonne nouvelle** : la RPC `app_confirm_ligdicash_payment` contient DÉJÀ toute la logique :

1. **Confirmation** : met le paiement à `confirmed`
2. **Reçu** : génère automatiquement un `payment_receipt`
3. **Grand livre** : écrit un `platform_ledger` entry (payin credit)
4. **Commission commerciale** : cherche le `commercial_user_id` via `user_referrals`, résout le taux via `app_resolve_revenue_split`, insère dans `referral_commissions`
5. **Revenue Split** : appelle `app_resolve_revenue_split(payment_reason)` puis boucle sur les règles :
   - Pour chaque bénéficiaire (instructor, commercial, university, merchant) :
   - Calcule `montant * percentage`, respecte min/max
   - Crédite `actor_balances` via UPSERT (available_balance + split_amount)
   - Écrit dans `platform_ledger` (revenue_split debit)
6. **Résolution des acteurs** :
   - `instructor` : cherche `td_enrollments.teacher_id` pour TD
   - `university` : cherche `programs.university_id` via application
   - `commercial` : déjà résolu via `user_referrals`
   - `merchant` : résolu via `marketplace_orders.merchant_id`

### Fonction `app_resolve_revenue_split(p_payment_reason)`
Retourne un JSONB array des règles actives pour un `payment_reason` donné,
triées par priorité, avec percentage/min/max/beneficiary_type.

## 3.2 PROBLÈMES RESTANTS

### 🔴 Université dans le circuit payout
L'université a un `university_revenue_tab.dart` et une RPC `app_university_request_payout`.
Selon votre directive : **les universités ne reçoivent pas de flux d'argent**. Il faut :
- Désactiver les `revenue_split_rules` où `beneficiary_type = 'university'`
- Masquer `university_revenue_tab.dart` (ou afficher un message)
- La RPC `app_university_request_payout` retourne `feature_disabled`

### 🟡 Mode LIGDICASH_MODE = 'mock'
Actuellement en mode simulé. Pour passer en live :
1. `supabase secrets set LIGDICASH_MODE=live`
2. S'assurer que le compte marchand LigdiCash a des liquidités cash suffisantes

### 🟡 Pas de cron pour le payout
Le payout est déclenché manuellement (admin appelle l'Edge Function).
Options :
- pg_cron toutes les heures/jour
- Bouton admin "Traiter tous les payouts"
- Hybride : cron + bouton

### 🟡 Frais de courtage (brokerage_fee)
La règle `application_fee` n'est pas définie dans `revenue_split_rules`.
Le courtage = 100% plateforme. Il faut ajouter cette règle.

### 🟢 Pas de callback spécifique pour les payouts
`ligdicash-callback` gère les payin. Pour les payouts, il faudrait :
- Soit un callback dédié
- Soit un polling périodique des payouts `processing`

---

# 4. ARCHITECTURE PROPOSÉE

## 4.1 Acteurs et flux confirmés

| Acteur | Reçoit de l'argent ? | Source | Via |
|---|---|---|---|
| **Commerçants** (marketplace) | ✅ OUI | Ventes marketplace | Escrow → available_balance → payout |
| **Enseignants** (TD + cours) | ✅ OUI | Part enseignant TD/cours | revenue_split → actor_balances → payout |
| **Commerciaux** (mobilisateurs) | ✅ OUI | Commission sur inscriptions/paiements | referral_commissions → payout |
| **Universités** | ❌ NON | Rien | *À supprimer du circuit* |
| **Plateforme** | ✅ OUI (garde) | Part plateforme de tout | Reste en liquidités cash |

## 4.2 Mécanisme LigdiCash

```
[Liquidités Cash du compte marchand Academia sur LigdiCash]
    │
    │  POST /pay/v01/withdrawal/create
    │  {
    │    "commande": {
    │      "amount": <montant>,
    │      "customer": "226XXXXXXXX",
    │      "description": "Versement Academia - <type> - <ref>",
    │      "top_up_wallet": 0,     ← 0 = mobile money direct
    │      "callback_url": "<supabase>/functions/v1/ligdicash-callback"
    │    }
    │  }
    │
    ▼
[Mobile Money du bénéficiaire]
    - Orange Money
    - Moov Money
    - Telecel Money
```

**Important:** `top_up_wallet: 0` signifie que l'argent est **transféré directement** du compte marchand LigdiCash vers le mobile money du bénéficiaire. Il ne passe PAS par un portefeuille LigdiCash intermédiaire.

## 4.3 Plan d'implémentation proposé

### Phase P1 : Compléter les revenue_split_rules (DB)
- Ajouter la règle `application_fee -> platform 100%` (courtage = 100% plateforme)
- Désactiver les règles `university` (`registration_fee 70%`, `tuition_deposit 80%`)
- Valider via `app_admin_validate_split_totals()` que chaque reason totalise 100%
- **Durée estimée : 30 min**

### Phase P2 : Supprimer l'université du circuit payout
- Désactiver `university_revenue_tab.dart` (message "fonctionnalité non disponible")
- RPC `app_university_request_payout` -> retourner `feature_disabled`
- Redistribuer les pourcentages university vers platform (ou autre acteur)
- **Durée estimée : 1h**

### Phase P3 : Cron automatique payout + callback
- Option A : pg_cron (via pg_net HTTP call) toutes les heures -> Edge Function ligdicash-payout
- Option B : Bouton admin "Traiter les payouts" + pg_cron quotidien backup
- Ajouter polling/callback pour les payouts en `processing`
- **Durée estimée : 2h**

### Phase P4 : Passer en mode LIVE
- `supabase secrets set LIGDICASH_MODE=live`
- Déployer les 4 Edge Functions : `ligdicash-initiate/confirm/callback/payout`
- Tester un micro-payout (100 XOF) vers un numéro de test
- Vérifier le solde liquidités cash du compte marchand Academia
- **Durée estimée : 1h (hors coordination LigdiCash)**

### Phase P5 : Monitoring admin (existant à vérifier)
- L'onglet admin Trésorerie existe déjà (Phase 5 LigdiCash précédente)
- Vérifier qu'il affiche bien : actor_balances, payout_queue, platform_ledger
- Ajouter alerte si solde liquidités cash bas
- **Durée estimée : 1h**

---

# 5. RÉSUMÉ TECHNIQUE

| Composant | Statut | Action requise |
|---|---|---|
| **Edge Function `ligdicash-payout`** | ✅ Prêt (mock) | Passer en live |
| **Table `payout_queue`** | ✅ Existe | OK — aucun payout encore |
| **Table `platform_ledger`** | ✅ Existe | OK — aucune écriture encore |
| **Table `actor_balances`** | ✅ Existe | OK — alimenté auto par confirm RPC |
| **Table `revenue_split_rules`** | ✅ 13 règles | Ajouter `application_fee`, désactiver `university` |
| **Revenue Split auto** | ✅ DANS la RPC `app_confirm_ligdicash_payment` | Fonctionne déjà |
| **`app_resolve_revenue_split()`** | ✅ Existe | Résout les règles par payment_reason |
| **RPCs request_payout** | ✅ 4 acteurs (instructor/commercial/merchant/university) | Désactiver university |
| **Flutter UI payout** | ✅ 4 écrans | Masquer university_revenue_tab |
| **Cron payout** | ❌ MANQUANT | pg_cron ou bouton admin |
| **Callback payout LigdiCash** | ⚠️ Partiel | `ligdicash-payout` vérifie 1x, pas de retry |
| **Mode LIVE** | ❌ Mock | `supabase secrets set LIGDICASH_MODE=live` |

---

# 6. QUESTIONS POUR VALIDATION

1. **Courtage (brokerage_fee) = 100% plateforme ?** Pas de répartition à d'autres acteurs ?
2. **Fréquence payout** : Quotidien automatique ? Hebdomadaire ? Sur demande uniquement ?
3. **Seuil minimum payout** : Faut-il un montant minimum (ex: 500 XOF) pour demander un retrait ?
4. **Validation admin** : Les payouts doivent-ils être approuvés par l'admin avant exécution, ou automatiques ?
5. **Université** : Confirmer que toutes les règles university sont à désactiver (registration_fee 70%, tuition_deposit 80%)
