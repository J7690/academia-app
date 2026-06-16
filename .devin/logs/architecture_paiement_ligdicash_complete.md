# Architecture Paiement LigdiCash — 100% Numérique, Zéro Cash
## Audit complet + Proposition — 19 Mars 2026

---

# A. CARTOGRAPHIE COMPLÈTE PAR RÔLE

## A1. ÉTUDIANT (11 onglets, index 0-10)

| Index | Onglet | Point de paiement actuel | Point de paiement LigdiCash proposé |
|-------|--------|-------------------------|-------------------------------------|
| 0 | Explorer (Accueil) | Aucun | Banner promo abonnement Premium |
| 1 | Candidatures | Déclaration paiement dans détail candidature | **Bouton "Payer" → LigdiCash OTP** directement dans le détail candidature |
| 2 | Opportunités/Marketplace | Commande marketplace (checkout) | **Checkout LigdiCash OTP** dans le flow d'achat |
| 3 | Communautés | Aucun | - |
| 4 | Universités | Aucun | - |
| 5 | Concours (Prep) | Aucun (gratuit actuellement) | **Paywall Premium** si on veut monétiser |
| 6 | **Paiements** | Écran dédié 1627 lignes (déclaration manuelle) | **TRANSFORMER** : historique + reçus PDF + statuts temps réel. Plus de déclaration manuelle |
| 7 | TD | Inscription TD crée un paiement pending | **Paiement LigdiCash OTP** au moment de l'inscription TD |
| 8 | Challenges | Aucun | - |
| 9 | Cours | Coming soon | Paywall futur si cours payants |
| 10 | Lives | Coming soon | Paywall futur si lives payants |

## A2. ADMIN (24 onglets)

| Index | Onglet | Impact paiement |
|-------|--------|----------------|
| 0 | Candidatures | Voir paiements dans détail candidature |
| 1 | **Paiements** | **Liste tous les paiements + actions confirm/reject** → Devient lecture seule (confirmation automatique LigdiCash) + gestion litiges |
| 2 | **Reçus** | Liste des reçus (inchangé, génération auto) |
| 3 | Programmes | Prix des programmes |
| 4 | **Marketplace** | Contrôle des commandes + paiements marketplace + escrow |
| 5-17 | Autres | Pas d'impact direct paiement |
| 18 | **Commerciaux** | Vue des prospects + commissions + **nouveau : bouton Payout** |
| 19 | **Grille commissions** | Config des % → **ajouter config split université/plateforme** |
| 20 | Comptes utilisateurs | - |
| 21 | **TD** | Prix des sessions TD |
| 22-23 | Communication/Support | - |

### Nouveaux onglets admin proposés :
| Nouvel onglet | Description |
|---------------|-------------|
| **Trésorerie** | Solde LigdiCash, historique entrées/sorties, tableau de bord financier |
| **Payouts** | File d'attente des reversements (commerciaux, universités, marchands) + déclenchement manuel ou auto |
| **Abonnements** | Gestion des plans, prix, promos, liste des abonnés actifs |

## A3. ENSEIGNANT (10 onglets)

| Onglet | Impact paiement |
|--------|----------------|
| Accueil → Sessions | **Aucun paiement direct** — l'enseignant ne perçoit pas via l'app actuellement |
| **Futur** | Si on veut payer les enseignants via LigdiCash Payout → ajouter onglet "Mes revenus" avec historique des payouts |

## A4. COMMERCIAL (3 onglets)

| Onglet | Impact paiement actuel | Avec LigdiCash |
|--------|----------------------|----------------|
| Accueil | KPIs, tier, ref_link | Inchangé + **solde commissions disponible** |
| Prospects | Liste des filleuls | Inchangé |
| **Finances** | Commissions (status pending/approved/paid), milestones | **Ajouter : bouton "Demander le versement" → Payout LigdiCash sur son mobile money** |

## A5. MARCHAND MARKETPLACE (console)

| Écran | Impact paiement actuel | Avec LigdiCash |
|-------|----------------------|----------------|
| Commandes | Liste commandes reçues | **Voir statut paiement temps réel** (payé/escrow/libéré) |
| **Nouveau : Mes revenus** | N'existe pas | **Historique des versements reçus + solde disponible + demande de payout** |

## A6. UNIVERSITÉ (3 onglets)

| Onglet | Impact paiement |
|--------|----------------|
| Candidatures | Voir paiements des étudiants |
| **Paiements** | Liste paiements de l'université | → **Devient temps réel** (plus de validation manuelle) |
| Mini-site | - |

---

# B. ARCHITECTURE TECHNIQUE COMPLÈTE

## B1. Principes fondamentaux

1. **ZÉRO cash** — Tout passe par LigdiCash OTP (sans redirection)
2. **ZÉRO validation manuelle admin** — LigdiCash callback = confirmation automatique
3. **Split automatique** — À chaque paiement confirmé, calcul et mise en file des reversements
4. **Escrow marketplace** — Argent bloqué jusqu'à livraison confirmée
5. **Payout automatique** — Cron quotidien reverse aux bénéficiaires via LigdiCash Payout

## B2. Enums — Modifications

### `payment_channel` — ajouter `ligdicash`
```sql
ALTER TYPE payment_channel ADD VALUE 'ligdicash';
```
**Supprimer `cash`** dans le code Flutter (plus de choix espèces). Garder dans l'enum DB pour les données historiques.

### `payment_reason` — ajouter valeurs
```sql
ALTER TYPE payment_reason ADD VALUE 'subscription';
ALTER TYPE payment_reason ADD VALUE 'marketplace_purchase';
```

## B3. Nouvelles tables

### `app.subscription_plans`
```
id UUID PK
code TEXT UNIQUE (premium_monthly, premium_annual, td_pass_monthly)
name TEXT
description TEXT
price NUMERIC
currency TEXT DEFAULT 'XOF'
duration_days INTEGER
features JSONB (["prep_concours","ia_tuteur","jeux_complets"])
is_active BOOLEAN
promo_percent INTEGER DEFAULT 0
promo_expires_at TIMESTAMPTZ
created_at TIMESTAMPTZ
```

### `app.subscriptions`
```
id UUID PK
student_id UUID FK→students
plan_id UUID FK→subscription_plans
status TEXT (active/expired/cancelled/pending_payment)
started_at TIMESTAMPTZ
expires_at TIMESTAMPTZ
payment_id UUID FK→application_payments
auto_renew BOOLEAN
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

### `app.payout_queue`
```
id UUID PK
beneficiary_type TEXT (commercial/university/merchant/instructor)
beneficiary_user_id UUID
beneficiary_phone TEXT (numéro mobile money pour LigdiCash Payout)
amount NUMERIC
currency TEXT DEFAULT 'XOF'
reason TEXT (commission/university_share/merchant_revenue/instructor_pay/milestone_bonus)
source_payment_id UUID FK→application_payments (nullable)
source_marketplace_payment_id UUID FK→marketplace_payments (nullable)
status TEXT (pending/processing/completed/failed)
ligdicash_token TEXT
ligdicash_transaction_id TEXT
processed_at TIMESTAMPTZ
error_message TEXT
retry_count INTEGER DEFAULT 0
created_at TIMESTAMPTZ
```

### `app.platform_ledger` (grand livre de la plateforme)
```
id UUID PK
transaction_type TEXT (payin/payout/commission/escrow_hold/escrow_release)
amount NUMERIC
currency TEXT DEFAULT 'XOF'
direction TEXT (credit/debit)
counterpart_type TEXT (student/commercial/university/merchant/ligdicash)
counterpart_id UUID
reference_id UUID (payment_id ou payout_id)
description TEXT
balance_after NUMERIC
created_at TIMESTAMPTZ
```

## B4. Colonnes à ajouter

### Sur `application_payments`
```sql
ADD COLUMN ligdicash_token TEXT;
ADD COLUMN ligdicash_transaction_id TEXT;
ADD COLUMN ligdicash_operator TEXT;
ADD COLUMN payment_method TEXT DEFAULT 'ligdicash_otp';
ADD COLUMN phone_number TEXT; -- numéro utilisé pour le paiement
```

### Sur `marketplace_payments`
```sql
-- Déjà : payment_method, payment_provider, payment_provider_ref
ADD COLUMN ligdicash_token TEXT;
ADD COLUMN ligdicash_transaction_id TEXT;
ADD COLUMN phone_number TEXT;
```

### Sur `commercial_profiles`
```sql
ADD COLUMN payout_phone TEXT; -- numéro mobile money pour recevoir les commissions
```

## B5. Edge Functions (4)

### 1. `ligdicash-initiate` — Initier un paiement OTP
```
POST Body: { payment_type, payment_id, phone_number }
- payment_type: "application" | "marketplace" | "subscription" | "td"
- Vérifie auth + charge le paiement depuis DB
- Appelle LigdiCash GET /pay/v02/debitotp/{phone}/{amount}
- Stocke le token dans la DB
- Retourne { success, otp_sent, message }
```

### 2. `ligdicash-confirm` — Valider OTP et finaliser
```
POST Body: { payment_type, payment_id, otp_code, phone_number }
- Appelle LigdiCash POST /pay/v02/debitwallet/withotp
- Vérifie status via GET /confirm/?invoiceToken=xxx
- Si completed:
  → Met à jour payment.status = 'confirmed'
  → Génère reçu (payment_receipts)
  → Calcule split: commission commercial + part université + part plateforme
  → INSERT payout_queue pour chaque bénéficiaire
  → INSERT platform_ledger
  → Si subscription → active l'abonnement
  → Si marketplace → met marketplace_payment.status = 'paid'
- Retourne { success, receipt_number, splits }
```

### 3. `ligdicash-callback` — Webhook LigdiCash (backup)
```
POST (no-verify-jwt, public URL)
- Reçoit le callback de LigdiCash (2x POST: form + JSON)
- Vérifie token via /confirm (anti-fraude)
- Idempotent — ne traite pas si déjà confirmé
- Même logique de confirmation que ligdicash-confirm
```

### 4. `ligdicash-payout` — Reverser argent
```
POST Body: { payout_ids: [] } ou { all_pending: true }
- Auth admin required
- Pour chaque payout_queue pending:
  → Appelle LigdiCash POST /pay/v01/withdrawal/create
  → customer = beneficiary_phone, amount, callback_url
  → Met à jour payout_queue.status = 'processing'
  → Vérifie via /withdrawal/confirm
  → Si completed → status = 'completed', INSERT platform_ledger (debit)
```

## B6. RPCs à modifier/créer

### Modifier
| RPC | Changement |
|-----|-----------|
| `app_admin_confirm_payment` | **Supprimer** la validation manuelle. Devient un fallback admin pour cas exceptionnels uniquement |
| `app_admin_verify_payment` | **Supprimer** — plus de vérification manuelle |
| `app_student_declare_payment` | **Supprimer** — plus de déclaration manuelle |
| `app_marketplace_process_payment` | Adapter pour accepter `ligdicash` comme provider |

### Créer
| RPC | Description |
|-----|-------------|
| `app_student_check_subscription` | Vérifie si l'étudiant a un abonnement actif pour un feature donné |
| `app_admin_list_payout_queue` | Liste tous les payouts en attente/traités |
| `app_admin_get_treasury_summary` | Solde plateforme, total entrées/sorties, par période |
| `app_admin_list_ledger` | Grand livre avec filtres |
| `app_commercial_request_payout` | Le commercial demande le versement de ses commissions |
| `app_merchant_request_payout` | Le marchand demande le versement de ses revenus |
| `app_admin_trigger_payouts` | L'admin déclenche les payouts en attente |
| `app_admin_manage_subscription_plans` | CRUD des plans d'abonnement |

## B7. Modifications Flutter

### Fichiers à SUPPRIMER ou VIDER
| Fichier | Raison |
|---------|--------|
| Formulaires de déclaration manuelle dans `student_payments_screen.dart` | Plus de "J'ai déjà payé" |
| DropdownMenuItem `cash` partout | Plus d'espèces |
| `_openDeclareExistingPaymentFlow` | Supprimé |
| `_openCreateApplicationPaymentFlow` | Remplacé par LigdiCash OTP |
| `_openCreateProfilePaymentFlow` | Remplacé par LigdiCash OTP |

### Nouveaux fichiers Flutter
| Fichier | Description |
|---------|-------------|
| `lib/widgets/ligdicash_payment_sheet.dart` | Bottom sheet réutilisable : choix opérateur, numéro, OTP, confirmation |
| `lib/widgets/paywall_overlay.dart` | Overlay "Abonnement requis" pour onglets premium |
| `lib/widgets/subscription_plans_sheet.dart` | Bottom sheet choix plan (mensuel/annuel) |
| `lib/providers/ligdicash_provider.dart` | Provider: initiate, confirmOtp, checkStatus |
| `lib/providers/subscription_provider.dart` | Provider: loadActiveSub, hasFeatureAccess, subscribe |
| `lib/providers/payout_provider.dart` | Provider admin: listPayouts, triggerPayouts |
| `lib/providers/treasury_provider.dart` | Provider admin: getSummary, listLedger |
| `lib/features/admin/admin_treasury_screen.dart` | Onglet trésorerie admin |
| `lib/features/admin/admin_payouts_screen.dart` | Onglet payouts admin |
| `lib/features/admin/admin_subscriptions_screen.dart` | Onglet abonnements admin |
| `lib/features/commercial/commercial_payout_screen.dart` | Écran demande de versement commercial |
| `lib/features/merchant/merchant_revenue_screen.dart` | Écran revenus marchand |

### Fichiers à modifier
| Fichier | Modification |
|---------|-------------|
| `student_payments_screen.dart` | Refonte complète → historique lecture seule + reçus PDF + statuts temps réel |
| `student_application_detail_screen.dart` | Bouton "Payer" → ouvre `LigdiCashPaymentSheet` |
| `student_td_root_screen.dart` | Inscription TD → `LigdiCashPaymentSheet` |
| `student_marketplace_cart_screen_v1.dart` | Checkout → `LigdiCashPaymentSheet` |
| `admin_dashboard_screen.dart` | Ajouter 3 onglets (Trésorerie, Payouts, Abonnements) |
| `admin_payments_screen.dart` | Simplifier — lecture seule + filtres + bouton admin "forcer confirmation" (cas exceptionnel) |
| `commercial_dashboard_screen.dart` | Onglet Finances → ajouter bouton "Demander versement" |
| `merchant_marketplace_console_screen_v2.dart` | Ajouter section "Mes revenus" + "Demander versement" |
| `university_payments_screen.dart` | Lecture seule — paiements confirmés automatiquement |

---

# C. FLOW COMPLET — CHAQUE CAS D'USAGE

## C1. Étudiant paie frais candidature
```
1. Détail candidature → Bouton "Payer 25 000 XOF"
2. LigdiCashPaymentSheet s'ouvre
3. Saisie numéro mobile money → "Envoyer OTP"
4. Edge Function ligdicash-initiate → LigdiCash envoie SMS OTP
5. Étudiant saisit code OTP → "Confirmer"
6. Edge Function ligdicash-confirm → LigdiCash débite
7. DB: payment.status = confirmed, reçu généré
8. Split auto: 12% → payout_queue(commercial), 70% → payout_queue(université), 18% → plateforme
9. Écran: "✅ Paiement confirmé" + reçu téléchargeable
```

## C2. Étudiant achète sur Marketplace
```
1. Panier → Checkout → "Payer X XOF"
2. LigdiCashPaymentSheet
3. OTP → Confirm
4. DB: marketplace_payment.status = 'paid' (escrow)
5. Marchand livre → Admin/auto release escrow
6. Split: 10% commission plateforme → platform_ledger, 90% → payout_queue(merchant)
7. Payout cron → LigdiCash envoie 90% au marchand
```

## C3. Étudiant s'abonne Premium
```
1. Tap sur onglet verrouillé → PaywallOverlay
2. Choix plan (mensuel 5000 / annuel 45000)
3. LigdiCashPaymentSheet
4. OTP → Confirm
5. DB: subscription créée (active, expires_at = now + duration_days)
6. Onglets premium déverrouillés immédiatement
```

## C4. Payout commercial
```
1. Dashboard commercial → Finances → "Demander versement"
2. Saisit son numéro mobile money
3. RPC app_commercial_request_payout → INSERT payout_queue
4. Admin valide ou cron auto
5. Edge Function ligdicash-payout → LigdiCash envoie l'argent
6. Commercial reçoit sur Orange/Moov/Telecel
```

## C5. Payout marchand
```
1. Console marchand → "Mes revenus" → "Retirer X XOF"
2. Même flow que commercial
3. Argent envoyé après release escrow
```

---

# D. RÉSUMÉ DES ACTIONS

## Phase 1 — Fondations (faisable MAINTENANT)
1. Créer tables: subscription_plans, subscriptions, payout_queue, platform_ledger
2. Ajouter colonnes LigdiCash sur application_payments + marketplace_payments + commercial_profiles
3. Ajouter valeurs enum (ligdicash, subscription, marketplace_purchase)
4. Créer RPCs: check_subscription, list_payout_queue, treasury_summary, etc.
5. Créer widget LigdiCashPaymentSheet (mode mock sans credentials)
6. Créer PaywallOverlay + SubscriptionProvider
7. Créer squelettes Edge Functions (ligdicash-initiate, confirm, callback, payout)
8. Refondre student_payments_screen → historique lecture seule
9. Ajouter onglets admin (Trésorerie, Payouts, Abonnements)
10. Ajouter "Mes revenus" marchand + "Demander versement" commercial
11. Seed data subscription_plans

## Phase 2 — Branchement LigdiCash (AVEC credentials)
1. Configurer secrets LIGDICASH_API_KEY + LIGDICASH_BEARER_TOKEN
2. Déployer les 4 Edge Functions
3. Tester paiement OTP réel (petit montant)
4. Tester callback webhook
5. Tester payout vers mobile money
6. Supprimer totalement les formulaires de déclaration manuelle
7. Supprimer le canal "cash" de l'UI

## Phase 3 — Optimisation
1. Cron pg_cron pour payouts automatiques quotidiens
2. Dashboard trésorerie temps réel
3. Notifications push à chaque paiement/payout
4. Renouvellement auto abonnements
5. Gestion des échecs/retry LigdiCash
