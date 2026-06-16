# Proposition d'Intégration LigdiCash — Academia
## Recherche + Architecture + UX — 19 Mars 2026

---

# PARTIE 1 : RÉSUMÉ RECHERCHES LIGDICASH

## 1.1 Services LigdiCash disponibles

| Service | Description | Pertinence Academia |
|---------|-------------|---------------------|
| **Payin avec redirection** | L'étudiant est redirigé vers une page LigdiCash pour payer | ⭐⭐⭐ Simple, sécurisé |
| **Payin sans redirection** | Paiement OTP in-app (numéro + code SMS) | ⭐⭐⭐⭐⭐ Meilleure UX mobile |
| **Payout** | Envoyer de l'argent vers mobile money du client | ⭐⭐⭐ Pour payer marchands/commerciaux |
| **Callback** | Webhook POST quand paiement réussi | ⭐⭐⭐⭐⭐ Indispensable |
| **Bulk** | Paiements groupés (salaires, remboursements) | ⭐⭐ Pour payer commissions en masse |
| **Cartes VISA** | Paiements internationaux | ⭐ Futur |
| **SMS** | Envoi SMS clients | ⭐ Backup notifications |

## 1.2 Flow technique LigdiCash

### Payin AVEC redirection (web-view)
```
1. Backend crée invoice → POST /pay/v01/redirect/checkout-invoice/create
   - Headers: Apikey + Authorization Bearer
   - Body: items[], total_amount, devise(XOF), customer info, callback_url, return_url, cancel_url, custom_data
2. LigdiCash retourne response_code "00" + response_text = URL de paiement
3. App ouvre URL dans WebView/navigateur
4. Client paie via Orange/Moov/Telecel/Wallet
5. LigdiCash envoie 2x POST callback (form-urlencoded + JSON) avec token, status, amount, operator
6. Backend vérifie: GET /confirm/?invoiceToken=xxx → response_code=="00" && status=="completed"
```

### Payin SANS redirection (OTP in-app) — RECOMMANDÉ POUR ACADEMIA
```
1. Collecter numéro téléphone + montant
2. GET /pay/v02/debitotp/{phone_number}/{amount} → envoie OTP par SMS au client
3. Client reçoit SMS avec code OTP
4. Client saisit OTP dans l'app
5. POST /pay/v02/debitwallet/withotp avec OTP + invoice data → débite le compte
6. Vérifier status: GET /confirm/?invoiceToken=xxx → response_code=="00" && status=="completed"
7. Callback POST sur callback_url (même format que redirection)
```

### Payout (reverser argent vers mobile money)
```
1. POST /pay/v01/withdrawal/create
   - Body: amount, description, customer(226XXXXXXXX), callback_url, top_up_wallet(0=mobile money, 1=wallet)
2. LigdiCash retourne token
3. Vérifier: GET /withdrawal/confirm/?withdrawalToken=xxx
4. Réponse: response_code=="00" && status=="completed"
```

## 1.3 SDK Dart/Flutter
- Package: `ligdicash: ^1.0.2` sur pub.dev
- Publié il y a 20 mois — wrappeur HTTP basique autour de l'API REST
- **Recommandation** : NE PAS utiliser le SDK Dart directement dans l'app Flutter
  - Les clés API (Apikey + Bearer token) ne doivent JAMAIS être côté client
  - → Utiliser une **Edge Function Supabase** comme proxy sécurisé

## 1.4 Infos clés
- **Devise** : XOF uniquement (parfait pour BF)
- **Opérateurs supportés** : Orange Money BF, Moov Money BF, Telecel Money BF, Wallet LigdiCash, Cartes VISA
- **Callback** : 2 requêtes POST (form-urlencoded + JSON) — attention au doublon
- **Vérification obligatoire** : Toujours vérifier response_code=="00" + status=="completed" via le token
- **Commissions** : Négociées dans le contrat (% par transaction), prélevées par LigdiCash sur chaque paiement

---

# PARTIE 2 : ANALYSE DES BESOINS ACADEMIA

## 2.1 Types de paiements dans Academia

| Catégorie | Qui paie | À qui | Montant | Fréquence |
|-----------|----------|-------|---------|-----------|
| **Frais de dossier** | Étudiant | Plateforme (admin) | Fixe (ex: 2000 XOF) | Unique |
| **Frais d'inscription** | Étudiant | Plateforme → Université | Variable | Unique |
| **Scolarité** | Étudiant | Plateforme → Université | Variable (tranches) | Récurrent |
| **Accès TD** | Étudiant | Plateforme | Fixe | Unique/Abonnement |
| **Abonnement Premium** | Étudiant | Plateforme | Mensuel/Annuel | Récurrent |
| **Achat Marketplace** | Étudiant/User | Plateforme → Marchand | Variable | Unique |
| **Commission Commercial** | Plateforme | Commercial | % du paiement | Automatique |
| **Reversement Université** | Plateforme | Université | % du paiement | Périodique |
| **Reversement Marchand** | Plateforme | Marchand Marketplace | Montant - commission | Après livraison |

## 2.2 Split Payment (répartition automatique)

Quand un étudiant paie, l'argent entre dans le **compte marchand LigdiCash d'Academia** puis est réparti :

```
Exemple : Étudiant paie 100 000 XOF de frais d'inscription

  100 000 XOF
      ↓
  [LigdiCash prélève sa commission : ex 2%] → 2 000 XOF pour LigdiCash
      ↓
  98 000 XOF arrive dans le wallet Academia
      ↓
  Split automatique (rules dans commission_rules) :
  ├── Commission commercial (si parrainage) : 12% × 98 000 = 11 760 XOF → file payout
  ├── Part université : 70% × 98 000 = 68 600 XOF → file payout
  └── Part plateforme : 18% × 98 000 = 17 640 XOF → reste dans wallet
```

## 2.3 Abonnements et accès conditionnel

| Niveau | Accès | Prix indicatif |
|--------|-------|----------------|
| **Free** | Feed challenges, communautés, profil | 0 XOF |
| **Étudiant Basic** | + Candidatures, TD basique | Frais de dossier unique |
| **Premium** | + Prep Concours, IA Tuteur illimité, Jeux complets, Lives | X XOF/mois |
| **TD Pass** | Accès aux sessions TD d'appui | Y XOF/session ou Z XOF/mois |

---

# PARTIE 3 : PROPOSITION UX — PAS D'ONGLET DÉDIÉ

## 3.1 Philosophie UX (inspirée Coursera/Netflix/Spotify)

**PAS d'onglet "Paiements"** visible en permanence dans la nav principale.

Les meilleures plateformes (Coursera, Netflix, Spotify, Duolingo) ne montrent JAMAIS un onglet "Paiements" dans le menu principal. Le paiement est **contextuel** — il apparaît au moment où l'utilisateur en a besoin :

- **Coursera** : Tu cliques "S'inscrire" sur un cours → écran de paiement inline → tu paies → accès immédiat
- **Netflix** : Tu choisis ton forfait → écran de paiement → retour dashboard
- **Duolingo** : Tu cliques "Super Duolingo" → bottom sheet avec prix → paiement → accès débloqué
- **Spotify** : Banner "Passer Premium" → page prix → paiement → features débloquées

### Pour Academia, le paiement doit être **invisible sauf quand nécessaire** :

```
FLOW A : L'étudiant veut accéder au Prep Concours (premium)
  → Tape sur "Prep Concours"
  → Si pas abonné → Bottom Sheet "Abonnement requis" avec prix + bouton "Payer maintenant"
  → Tape "Payer maintenant"
  → Écran de paiement LigdiCash (in-app, OTP)
  → Paiement réussi → accès immédiat → redirection vers Prep Concours

FLOW B : L'étudiant déclare un paiement de frais d'inscription
  → Depuis le détail de sa candidature → bouton "Payer les frais"
  → Bottom Sheet de paiement (montant pré-rempli)
  → Paye via LigdiCash → confirmation auto

FLOW C : Achat Marketplace
  → Panier → Checkout → Paiement LigdiCash → Confirmation commande
```

## 3.2 Où placer les paiements dans l'UI ?

| Endroit | Ce qu'on affiche | Trigger |
|---------|-----------------|---------|
| **Détail candidature** | Bouton "Payer les frais" (montant affiché) | Candidature créée |
| **Onglet bloqué** (Prep Concours, etc.) | Paywall overlay "Abonnement Premium" | Tap sur onglet verrouillé |
| **Profil/Paramètres** | Section "Mes paiements" (historique, reçus) | Navigation manuelle |
| **Marketplace checkout** | Flow de paiement standard | Panier validé |
| **TD inscription** | Bottom sheet paiement | Inscription à une session TD |
| **Banner promo** | "Offre -30% cette semaine" → paiement | Homepage |

## 3.3 Écran de paiement unifié (widget réutilisable)

Un seul **composant Flutter** `PaymentBottomSheet` utilisable partout :

```
┌─────────────────────────────────────┐
│       💳 Paiement                   │
│                                     │
│  Frais d'inscription                │
│  Programme : Licence Économie       │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Montant : 25 000 XOF      │    │
│  └─────────────────────────────┘    │
│                                     │
│  Payer avec :                       │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │  🟠  │ │  🔵  │ │  🟢  │       │
│  │Orange│ │ Moov │ │Telecel│       │
│  │Money │ │Money │ │Money │        │
│  └──────┘ └──────┘ └──────┘       │
│                                     │
│  Numéro mobile money :              │
│  ┌─────────────────────────────┐    │
│  │ +226 7X XX XX XX            │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │     Envoyer le code OTP     │    │
│  └─────────────────────────────┘    │
│                                     │
│  Code OTP reçu par SMS :           │
│  ┌─────────────────────────────┐    │
│  │   [ _ ][ _ ][ _ ][ _ ][ _ ]│    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    ✅ CONFIRMER LE PAIEMENT │    │
│  └─────────────────────────────┘    │
│                                     │
│  🔒 Paiement sécurisé par LigdiCash│
│                                     │
│  Ou déclarer un paiement manuel     │
│  (effectué en dehors de l'app)      │
└─────────────────────────────────────┘
```

## 3.4 Paywall pour contenus premium

```
┌─────────────────────────────────────┐
│                                     │
│        🔒 Contenu Premium           │
│                                     │
│   Prep Concours / IA Tuteur /       │
│   Jeux complets                     │
│                                     │
│   Débloque tout avec l'abonnement   │
│   Academia Premium                  │
│                                     │
│   ✅ Prep Concours illimité         │
│   ✅ IA Tuteur sans limite          │
│   ✅ Jeux éducatifs complets        │
│   ✅ Sessions Lives prioritaires    │
│                                     │
│   ┌─────────────┐ ┌─────────────┐   │
│   │  Mensuel    │ │  Annuel     │   │
│   │  5 000 XOF  │ │ 45 000 XOF │   │
│   │  /mois      │ │ /an (-25%) │   │
│   └─────────────┘ └─────────────┘   │
│                                     │
│   ┌─────────────────────────────┐   │
│   │   S'ABONNER MAINTENANT      │   │
│   └─────────────────────────────┘   │
│                                     │
│   Satisfait ou remboursé 7 jours    │
│                                     │
└─────────────────────────────────────┘
```

---

# PARTIE 4 : ARCHITECTURE TECHNIQUE

## 4.1 Vue d'ensemble

```
┌──────────────┐     ┌───────────────────┐     ┌──────────────┐
│  Flutter App  │────▶│  Supabase Edge     │────▶│  LigdiCash   │
│  (Étudiant)   │     │  Functions          │     │  API          │
│               │◀────│                     │◀────│              │
└──────────────┘     │  ligdicash-pay      │     └──────────────┘
                      │  ligdicash-callback │
                      │  ligdicash-payout   │
                      └─────────┬───────────┘
                                │
                      ┌─────────▼───────────┐
                      │  Supabase DB         │
                      │  (tables paiement)   │
                      │  + triggers          │
                      │  + commission_rules  │
                      │  + subscriptions     │
                      └──────────────────────┘
```

## 4.2 Nouvelles Edge Functions

### Edge Function 1 : `ligdicash-pay` (initier un paiement)
```
POST /functions/v1/ligdicash-pay
Body: {
  payment_id: "uuid",           // ID du paiement dans application_payments
  phone_number: "22670123456",  // Numéro mobile money
  method: "otp" | "redirect"    // OTP recommandé
}

→ Charge le paiement depuis DB
→ Appelle LigdiCash API (debitotp ou redirect)
→ Stocke le token LigdiCash dans la DB
→ Retourne { success, otp_sent } ou { success, redirect_url }
```

### Edge Function 2 : `ligdicash-validate` (valider OTP)
```
POST /functions/v1/ligdicash-validate
Body: {
  payment_id: "uuid",
  otp_code: "123456",
  phone_number: "22670123456"
}

→ Appelle LigdiCash API (debitwallet/withotp)
→ Vérifie status via /confirm
→ Si completed → met à jour application_payments.status = 'confirmed'
→ Génère reçu + commission auto (via RPC existante app_admin_confirm_payment adaptée)
→ Retourne { success, receipt_number }
```

### Edge Function 3 : `ligdicash-callback` (webhook LigdiCash)
```
POST /functions/v1/ligdicash-callback (URL publique, no-verify-jwt)

→ Reçoit le POST de LigdiCash (2x : form + JSON)
→ Vérifie le token via /confirm pour anti-fraude
→ Si status=="completed" → met à jour paiement + reçu + commission
→ Idempotent (ne traite pas 2 fois le même token)
→ Retourne 200 OK
```

### Edge Function 4 : `ligdicash-payout` (reverser argent)
```
POST /functions/v1/ligdicash-payout (appelé par cron ou admin)
Body: {
  payout_batch_id: "uuid"  // ou individuel
}

→ Charge les reversements en attente (commissions commerciales, parts universités, marchands)
→ Appelle LigdiCash Payout API pour chacun
→ Met à jour le statut de chaque reversement
```

## 4.3 Nouvelles tables Supabase

### Table `app.subscriptions`
```sql
CREATE TABLE app.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES app.students(id),
  plan_code TEXT NOT NULL,              -- 'free', 'premium_monthly', 'premium_annual', 'td_pass'
  status TEXT NOT NULL DEFAULT 'active', -- 'active', 'expired', 'cancelled', 'pending'
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  payment_id UUID REFERENCES app.application_payments(id),
  auto_renew BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Table `app.subscription_plans`
```sql
CREATE TABLE app.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,            -- 'premium_monthly', 'premium_annual', 'td_pass_monthly'
  name TEXT NOT NULL,                   -- 'Premium Mensuel'
  description TEXT,
  price NUMERIC NOT NULL,               -- 5000
  currency TEXT NOT NULL DEFAULT 'XOF',
  duration_days INTEGER NOT NULL,       -- 30, 365
  features JSONB,                       -- ["prep_concours", "ia_tuteur", "jeux_complets"]
  is_active BOOLEAN DEFAULT TRUE,
  promo_percent INTEGER DEFAULT 0,      -- 25 = 25% de réduction
  promo_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Table `app.payout_queue`
```sql
CREATE TABLE app.payout_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_type TEXT NOT NULL,       -- 'commercial', 'university', 'merchant'
  beneficiary_user_id UUID,
  beneficiary_phone TEXT,               -- numéro mobile money pour le payout
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  reason TEXT,                          -- 'commission', 'university_share', 'merchant_revenue'
  source_payment_id UUID REFERENCES app.application_payments(id),
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
  ligdicash_token TEXT,
  ligdicash_transaction_id TEXT,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Colonnes à ajouter sur `application_payments`
```sql
ALTER TABLE app.application_payments
  ADD COLUMN ligdicash_token TEXT,
  ADD COLUMN ligdicash_transaction_id TEXT,
  ADD COLUMN ligdicash_operator TEXT,
  ADD COLUMN payment_method TEXT DEFAULT 'manual';  -- 'manual', 'ligdicash_otp', 'ligdicash_redirect'
```

## 4.4 Modifications Flutter

### Nouveaux fichiers
| Fichier | Description |
|---------|-------------|
| `lib/widgets/payment_bottom_sheet.dart` | Widget réutilisable de paiement LigdiCash (OTP flow) |
| `lib/widgets/paywall_screen.dart` | Écran paywall pour contenus premium |
| `lib/widgets/subscription_card.dart` | Carte d'abonnement (mensuel/annuel) |
| `lib/providers/payment_gateway_provider.dart` | Provider pour LigdiCash (initier, valider OTP, vérifier) |
| `lib/providers/subscription_provider.dart` | Provider pour abonnements (charger plan actif, vérifier accès) |
| `lib/services/ligdicash_service.dart` | Service appelant les Edge Functions |

### Fichiers modifiés
| Fichier | Modification |
|---------|-------------|
| `student_payments_screen.dart` | Ajouter bouton "Payer via LigdiCash" en plus de la déclaration manuelle |
| `student_application_detail_screen.dart` | Bouton "Payer maintenant" → ouvre PaymentBottomSheet |
| `student_td_root_screen.dart` | Vérifier abonnement avant accès TD |
| `student_prep_concours_screen.dart` | Paywall si pas premium |
| `student_dashboard_screen.dart` | Badge "Premium" si abonné |
| Chaque onglet premium | Guard `SubscriptionProvider.hasAccess('feature')` |

## 4.5 Flow complet Paiement In-App (OTP)

```
1. [Flutter] Utilisateur tape "Payer 25 000 XOF"
2. [Flutter] Ouvre PaymentBottomSheet → saisit numéro mobile money
3. [Flutter] Appelle Edge Function ligdicash-pay(payment_id, phone, method='otp')
4. [Edge Function] Crée/vérifie le paiement dans DB → appelle LigdiCash GET /debitotp/{phone}/{amount}
5. [LigdiCash] Envoie OTP par SMS au numéro
6. [Edge Function] Retourne {success: true, otp_sent: true}
7. [Flutter] Affiche champ OTP → utilisateur saisit le code reçu par SMS
8. [Flutter] Appelle Edge Function ligdicash-validate(payment_id, otp, phone)
9. [Edge Function] Appelle LigdiCash POST /debitwallet/withotp avec l'OTP
10. [LigdiCash] Débite le compte → retourne token
11. [Edge Function] Vérifie status via /confirm → response_code=="00" && status=="completed"
12. [Edge Function] Met à jour DB: status='confirmed', confirmed_at=NOW()
13. [Edge Function] Génère reçu (payment_receipts)
14. [Edge Function] Calcule commission commercial (si applicable) → INSERT payout_queue
15. [Edge Function] Calcule part université (si applicable) → INSERT payout_queue
16. [Edge Function] Active l'abonnement (si applicable) → INSERT subscriptions
17. [Edge Function] Retourne {success: true, receipt_number: "REC-..."}
18. [Flutter] Affiche "✅ Paiement confirmé !" + confettis
19. [Flutter] Redirige vers le contenu débloqué

EN PARALLÈLE :
20. [LigdiCash] Envoie callback POST à ligdicash-callback (backup)
21. [Edge Function callback] Vérifie idempotence → paiement déjà traité → ignore
```

## 4.6 Promotions automatiques

```sql
-- Exemple : Promo -30% sur Premium Annuel pendant les inscriptions
UPDATE app.subscription_plans
SET promo_percent = 30,
    promo_expires_at = '2026-10-01'::TIMESTAMPTZ
WHERE code = 'premium_annual';
```

Le prix affiché dans l'app est calculé dynamiquement :
```dart
final effectivePrice = plan.price * (1 - plan.promoPercent / 100);
```

## 4.7 Payout automatique (reverser aux bénéficiaires)

Un **cron Supabase** (pg_cron) exécute quotidiennement :
```
1. Charger tous les payout_queue WHERE status='pending'
2. Pour chaque entrée → appeler Edge Function ligdicash-payout
3. LigdiCash Payout API → envoie l'argent sur le mobile money du bénéficiaire
4. Mettre à jour payout_queue.status = 'completed'
```

Ou l'admin peut déclencher manuellement depuis le dashboard.

---

# PARTIE 5 : RÉSUMÉ DÉCISIONNEL

## Ce qu'on peut faire MAINTENANT (sans credentials)

| Action | Détail |
|--------|--------|
| ✅ Créer les tables `subscriptions`, `subscription_plans`, `payout_queue` | SQL prêt |
| ✅ Ajouter colonnes LigdiCash sur `application_payments` | SQL prêt |
| ✅ Créer le widget `PaymentBottomSheet` Flutter | UI complète |
| ✅ Créer le widget `PaywallScreen` Flutter | UI complète |
| ✅ Créer le `SubscriptionProvider` + guards d'accès | Logique complète |
| ✅ Créer les Edge Functions (squelette, mock mode) | Prêtes à brancher |
| ✅ Créer les RPCs split payment + payout_queue | SQL complet |
| ✅ Seed data subscription_plans | Données initiales |

## Ce qu'on fera AVEC les credentials

| Action | Détail |
|--------|--------|
| 🔑 Configurer secrets `LIGDICASH_API_KEY` + `LIGDICASH_BEARER_TOKEN` | Edge Functions |
| 🔑 Déployer Edge Functions en production | supabase functions deploy |
| 🔑 Tester paiement réel OTP (petit montant) | Test end-to-end |
| 🔑 Configurer callback_url publique | URL Supabase Edge Function |
| 🔑 Tester payout vers mobile money | Reversement commercial/université |

## Recommandation finale

**Approche hybride** : Garder le système de déclaration manuelle actuel (cash, sans smartphone) ET ajouter le paiement LigdiCash automatique comme option principale. L'étudiant choisit :
- **"Payer maintenant"** → LigdiCash OTP (instantané, automatique)
- **"J'ai déjà payé"** → Déclaration manuelle (ancien système, validation admin)

Cela couvre 100% des étudiants, y compris ceux qui paient en espèces au guichet.
