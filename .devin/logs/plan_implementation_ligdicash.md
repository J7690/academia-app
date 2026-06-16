# Plan d'Implémentation LigdiCash — Phases détaillées
## 100% numérique, zéro cash, OTP sans redirection
## 19 Mars 2026

---

# PHASE 1 — Fondations Supabase (SQL pur)
**Objectif** : Créer toutes les nouvelles tables, colonnes, enums, RPCs, RLS nécessaires au système LigdiCash.
**Prérequis** : Aucun credential LigdiCash nécessaire.

### Étape 1.1 — Audit Supabase (pré-implémentation)
- Vérifier que les enums, tables et colonnes cibles n'existent pas déjà

### Étape 1.2 — Modifier les enums existants
- `payment_channel` : ajouter `ligdicash` (garder `cash` pour historique mais ne plus l'utiliser)
- `payment_reason` : ajouter `subscription`, `marketplace_purchase`, `online_course`
- `payment_status` : ajouter `processing` (pour l'état entre OTP envoyé et confirmation)

### Étape 1.3 — Ajouter colonnes LigdiCash sur tables existantes
- `application_payments` : + `ligdicash_token`, `ligdicash_transaction_id`, `ligdicash_operator`, `payment_method` (DEFAULT 'ligdicash_otp'), `phone_number`
- `marketplace_payments` : + `ligdicash_token`, `ligdicash_transaction_id`, `phone_number`
- `commercial_profiles` : + `payout_phone` (numéro mobile money pour payout)

### Étape 1.4 — Créer table `app.subscription_plans`
- id UUID PK, code TEXT UNIQUE, name, description, price NUMERIC, currency TEXT DEFAULT 'XOF', duration_days INT, features JSONB, is_active BOOL, promo_percent INT DEFAULT 0, promo_expires_at TIMESTAMPTZ, created_at
- Seed data : premium_monthly (5000 XOF, 30j), premium_annual (45000 XOF, 365j), td_pass_monthly

### Étape 1.5 — Créer table `app.subscriptions`
- id UUID PK, student_id FK→students, plan_id FK→subscription_plans, status TEXT (active/expired/cancelled/pending_payment), started_at, expires_at, payment_id FK→application_payments (nullable), auto_renew BOOL, created_at, updated_at
- RLS : student voit les siennes, admin voit toutes

### Étape 1.6 — Créer table `app.payout_queue`
- id UUID PK, beneficiary_type TEXT (commercial/university/merchant/instructor), beneficiary_user_id UUID, beneficiary_phone TEXT, amount NUMERIC, currency TEXT DEFAULT 'XOF', reason TEXT, source_payment_id UUID FK→application_payments (nullable), source_marketplace_payment_id UUID FK→marketplace_payments (nullable), status TEXT (pending/processing/completed/failed), ligdicash_token, ligdicash_transaction_id, processed_at, error_message, retry_count INT DEFAULT 0, created_at
- RLS : admin ALL, commercial voit les siennes, merchant voit les siennes

### Étape 1.7 — Créer table `app.platform_ledger`
- id UUID PK, transaction_type TEXT (payin/payout/commission/escrow_hold/escrow_release/subscription), amount NUMERIC, currency TEXT DEFAULT 'XOF', direction TEXT (credit/debit), counterpart_type TEXT, counterpart_id UUID, reference_id UUID, description TEXT, balance_after NUMERIC, created_at
- RLS : admin SELECT only

### Étape 1.8 — Créer nouvelles RPCs
- `app_student_check_subscription(p_feature TEXT)` → BOOL (vérifie si abonnement actif couvre le feature)
- `app_admin_list_payout_queue(p_status TEXT DEFAULT NULL)` → liste payouts
- `app_admin_get_treasury_summary()` → totaux entrées/sorties/solde
- `app_admin_list_ledger(p_limit INT, p_offset INT)` → grand livre paginé
- `app_commercial_request_payout()` → calcule commissions pending approuvées → INSERT payout_queue
- `app_merchant_request_payout()` → calcule balance dispo → INSERT payout_queue
- `app_admin_manage_subscription_plan(p_action, p_code, p_name, p_price, ...)` → CRUD plans
- `app_admin_list_subscriptions()` → liste abonnés actifs
- `app_confirm_ligdicash_payment(p_payment_id, p_token, p_transaction_id, p_operator)` → confirme paiement + génère reçu + split + payout_queue (appelée par Edge Function)

### Étape 1.9 — Modifier RPCs existantes
- `app_student_declare_payment` → marquer DEPRECATED (garde fonctionnel pour transition mais ne sera plus appelé)
- `app_admin_verify_payment` → marquer DEPRECATED
- `app_admin_confirm_payment` → ajouter colonne `auto_confirmed` dans le retour pour distinguer LigdiCash auto vs admin manuel (fallback)
- `app_marketplace_process_payment` → accepter `ligdicash` comme payment_provider, stocker token
- `app_td_student_create_enrollment_and_payment` → adapter pour accepter `payment_method = 'ligdicash_otp'`

### Étape 1.10 — Index et contraintes
- Index sur payout_queue(status), payout_queue(beneficiary_user_id), subscriptions(student_id, status), platform_ledger(created_at)

**Livrable** : SQL migration `.windsurf/sql_changes/change_20260319_ligdicash_foundations.sql`
**Vérification** : Audit SQL post-implémentation pour confirmer toutes les tables/colonnes/RPCs créées

---

# PHASE 2 — Edge Functions Supabase (backend LigdiCash)
**Objectif** : Créer les 4 Edge Functions qui font l'interface avec l'API LigdiCash.
**Prérequis** : Phase 1 terminée. Credentials LigdiCash PAS encore nécessaires (mode mock).

### Étape 2.1 — Audit Supabase (vérifier Phase 1 OK)

### Étape 2.2 — Edge Function `ligdicash-initiate`
- Reçoit : `{ payment_type, payment_id, phone_number }`
- payment_type : "application" | "marketplace" | "subscription" | "td"
- Vérifie auth Supabase
- Charge le paiement depuis la DB selon payment_type
- Vérifie que le paiement est en status pending/processing
- Stocke phone_number dans la DB
- Mode mock : retourne `{ success: true, otp_sent: true, mock: true }` sans appeler LigdiCash
- Mode réel : GET `https://app.ligdicash.com/pay/v02/debitotp/{phone}/{amount}` avec headers Apikey + Bearer
- Met à jour payment.status = 'processing'
- Retourne `{ success, otp_sent }`
- Secrets requis : `LIGDICASH_API_KEY`, `LIGDICASH_BEARER_TOKEN`, `LIGDICASH_MODE` (mock/live)

### Étape 2.3 — Edge Function `ligdicash-confirm`
- Reçoit : `{ payment_type, payment_id, otp_code, phone_number }`
- Mode mock : simule succès, appelle RPC `app_confirm_ligdicash_payment`
- Mode réel :
  1. POST `https://app.ligdicash.com/pay/v02/debitwallet/withotp` avec invoice + OTP
  2. GET `/confirm/?invoiceToken=xxx` → vérifie response_code=="00" && status=="completed"
  3. Appelle RPC `app_confirm_ligdicash_payment(p_payment_id, p_token, p_transaction_id, p_operator)`
  4. La RPC gère : status=confirmed, reçu, split commission commercial, split université, payout_queue, platform_ledger, activation abonnement si subscription
- Retourne `{ success, receipt_number, transaction_id }`

### Étape 2.4 — Edge Function `ligdicash-callback`
- URL publique (`--no-verify-jwt`)
- Reçoit POST de LigdiCash (2 formats : form-urlencoded + JSON)
- Parse le body, extrait token + status
- Vérifie via GET `/confirm/?invoiceToken=xxx`
- Idempotent : si paiement déjà confirmed → ignore
- Si status=="completed" → appelle même RPC `app_confirm_ligdicash_payment`
- Retourne 200 OK toujours (pour ne pas bloquer LigdiCash)

### Étape 2.5 — Edge Function `ligdicash-payout`
- Auth admin required (ou service_role pour cron)
- Reçoit : `{ payout_ids: [] }` ou `{ all_pending: true }`
- Pour chaque payout_queue pending :
  - Mode mock : simule succès
  - Mode réel : POST `https://app.ligdicash.com/pay/v01/withdrawal/create` avec amount, customer(phone), callback_url
  - Vérifie via GET `/withdrawal/confirm/?withdrawalToken=xxx`
  - Met à jour payout_queue status + platform_ledger (debit)
- Retourne `{ processed, succeeded, failed }`

**Livrable** : 4 fichiers dans `supabase/functions/`
**Vérification** : Test en mode mock via curl ou Flutter

---

# PHASE 3 — Widget Flutter LigdiCash (Étudiant)
**Objectif** : Créer le widget de paiement réutilisable + le brancher sur les points de paiement étudiant.
**Prérequis** : Phase 1 + 2 terminées.

### Étape 3.1 — Audit Flutter (cartographier les points d'appel actuels)

### Étape 3.2 — Créer `lib/services/ligdicash_service.dart`
- `initiatePayment(paymentType, paymentId, phone)` → appelle Edge Function ligdicash-initiate
- `confirmOtp(paymentType, paymentId, otp, phone)` → appelle Edge Function ligdicash-confirm
- `checkPaymentStatus(paymentId)` → charge depuis DB

### Étape 3.3 — Créer `lib/providers/ligdicash_provider.dart`
- States : idle → sending_otp → waiting_otp → confirming → success → error
- Methods : initiate(), confirmOtp(), reset()

### Étape 3.4 — Créer `lib/widgets/ligdicash_payment_sheet.dart`
- Bottom sheet réutilisable
- Params : paymentType, paymentId, amount, description, currency
- UI : 3 boutons opérateurs (Orange/Moov/Telecel), champ numéro téléphone, bouton "Envoyer OTP", champ code OTP (6 digits), bouton "Confirmer le paiement", loading states, messages erreur/succès, "🔒 Sécurisé par LigdiCash"
- Callback onSuccess(receiptNumber)

### Étape 3.5 — Refondre `student_payments_screen.dart`
- Supprimer : tous les formulaires de déclaration manuelle (_openDeclareExistingPaymentFlow, _openCreateApplicationPaymentFlow, _openCreateProfilePaymentFlow)
- Supprimer : _PaymentChannelsSection (plus de choix canal), _CreatePaymentSection
- Garder : _PaymentsHistorySection (historique lecture seule), bouton "Télécharger reçu" PDF
- Ajouter : statuts temps réel, filtre par statut

### Étape 3.6 — Modifier `student_application_detail_screen.dart`
- Remplacer `_showDeclarePaymentSheet` par ouverture de `LigdiCashPaymentSheet`
- Le bouton "Déclarer un paiement" devient "Payer maintenant"

### Étape 3.7 — Modifier `student_td_root_screen.dart`
- L'inscription TD qui appelle `app_td_student_create_enrollment_and_payment` → après création du paiement pending, ouvre `LigdiCashPaymentSheet` pour payer immédiatement

### Étape 3.8 — Modifier `student_marketplace_cart_screen_v1.dart` / checkout
- Après création de la commande/paiement marketplace → ouvre `LigdiCashPaymentSheet`

**Livrable** : Widget complet, providers, service, 4 écrans modifiés
**Vérification** : Build APK debug, test UX en mode mock

---

# PHASE 4 — Abonnements Premium (Paywall)
**Objectif** : Système d'abonnement avec paywall sur les onglets premium.
**Prérequis** : Phase 3 terminée.

### Étape 4.1 — Audit Flutter + Supabase (vérifier tables subscriptions + plans existent)

### Étape 4.2 — Créer `lib/providers/subscription_provider.dart`
- `loadActiveSubscription()` → charge depuis DB
- `hasFeatureAccess(String feature)` → vérifie si plan actif contient le feature
- `subscribe(planCode)` → crée paiement + ouvre LigdiCashPaymentSheet
- Features : "prep_concours", "ia_tuteur_illimite", "jeux_complets", "lives_prioritaires", "td_illimite"

### Étape 4.3 — Créer `lib/widgets/paywall_overlay.dart`
- Overlay qui s'affiche quand l'utilisateur n'a pas accès
- Liste des features du plan, prix (avec promo si applicable), boutons mensuel/annuel
- "S'abonner maintenant" → crée subscription pending + ouvre LigdiCashPaymentSheet

### Étape 4.4 — Ajouter guards d'accès sur les onglets premium
- `StudentPrepConcoursScreen` → vérifier subscription avant chargement (si monétisé)
- Autres onglets futurs (Cours payants, Lives payants)
- Le guard affiche PaywallOverlay si pas d'accès

### Étape 4.5 — Ajouter badge "Premium" dans student dashboard
- Petit badge doré à côté du nom si abonné actif

### Étape 4.6 — Enregistrer SubscriptionProvider dans main.dart

**Livrable** : Paywall fonctionnel, provider, overlay, guards
**Vérification** : Build APK, test paywall en mock

---

# PHASE 5 — Admin Trésorerie + Payouts + Abonnements
**Objectif** : 3 nouveaux onglets admin pour le suivi financier complet.
**Prérequis** : Phase 1 terminée.

### Étape 5.1 — Audit Supabase (vérifier RPCs treasury/payout/subscriptions existent)

### Étape 5.2 — Créer `lib/providers/treasury_provider.dart`
- `loadSummary()` → appelle `app_admin_get_treasury_summary`
- `loadLedger(limit, offset)` → appelle `app_admin_list_ledger`

### Étape 5.3 — Créer `lib/features/admin/admin_treasury_screen.dart`
- KPI cards : solde total, entrées du mois, sorties du mois, commissions totales
- Grand livre avec filtres (type, période, direction)
- Graphique simple entrées/sorties (optionnel)

### Étape 5.4 — Créer `lib/providers/payout_provider.dart`
- `loadPayouts(status)` → appelle `app_admin_list_payout_queue`
- `triggerPayouts(ids)` → appelle Edge Function ligdicash-payout

### Étape 5.5 — Créer `lib/features/admin/admin_payouts_screen.dart`
- Liste des payouts en attente/traités
- Filtres par bénéficiaire type (commercial/university/merchant)
- Bouton "Déclencher les versements en attente"
- Statut temps réel de chaque payout

### Étape 5.6 — Créer `lib/features/admin/admin_subscriptions_screen.dart`
- CRUD des plans (prix, durée, promo)
- Liste des abonnés actifs
- Stats : nombre d'abonnés par plan, revenus récurrents

### Étape 5.7 — Modifier `admin_dashboard_screen.dart`
- Ajouter les 3 nouveaux onglets (Trésorerie, Payouts, Abonnements) → passer de 24 à 27 tabs
- Simplifier `AdminPaymentsScreen` → lecture seule (plus de boutons confirm/reject pour les paiements LigdiCash)

### Étape 5.8 — Modifier `admin_payments_screen.dart`
- Les paiements LigdiCash sont auto-confirmés → afficher un badge "Auto" pour les distinguer
- Garder un bouton "Forcer confirmation" pour les cas exceptionnels (admin override)

**Livrable** : 3 nouveaux onglets admin, providers, écrans
**Vérification** : Build APK, test navigation admin

---

# PHASE 6 — Commercial Payout + Marchand Revenus
**Objectif** : Permettre aux commerciaux et marchands de retirer leurs revenus via LigdiCash Payout.
**Prérequis** : Phase 5 terminée.

### Étape 6.1 — Audit Flutter + Supabase (vérifier RPCs payout commercial/merchant)

### Étape 6.2 — Modifier `commercial_dashboard_screen.dart`
- Onglet "Finances" : ajouter section "Solde disponible" + bouton "Demander un versement"
- Bottom sheet pour saisir/confirmer le numéro mobile money
- Appelle `app_commercial_request_payout` → INSERT payout_queue
- Afficher historique des versements reçus

### Étape 6.3 — Modifier `merchant_marketplace_console_screen_v2.dart`
- Ajouter section/onglet "Mes revenus"
- Afficher : solde disponible (depuis marketplace_merchant_balances), historique des versements
- Bouton "Retirer mes revenus" → `app_merchant_request_payout`

### Étape 6.4 — Modifier `university_payments_screen.dart`
- Paiements désormais confirmés automatiquement → simplifier l'affichage
- Ajouter indicateur "Versement programmé" quand un payout est en queue

**Livrable** : Payout commercial + marchand + vue université simplifiée
**Vérification** : Build APK, test flows

---

# PHASE 7 — Nettoyage + Polish (suppression ancien système)
**Objectif** : Supprimer totalement l'ancien système de paiement manuel.
**Prérequis** : Toutes les phases précédentes terminées + LigdiCash credentials reçus et testés.

### Étape 7.1 — Audit complet Flutter (grep tous les vestiges de l'ancien système)

### Étape 7.2 — Supprimer dans Flutter
- Tous les DropdownMenuItem `cash` dans les écrans de paiement
- `_showDeclarePaymentSheet` dans student_application_detail_screen
- Formulaires de déclaration manuelle dans student_payments_screen
- Boutons "Valider" / "Rejeter" dans admin_payments_screen pour les paiements LigdiCash (garder pour historique)
- Références à "Espèces / guichet" partout

### Étape 7.3 — Marquer RPCs comme deprecated dans Supabase
- `app_student_declare_payment` → ajouter commentaire DEPRECATED, garder fonctionnel pour données historiques
- `app_admin_verify_payment` → idem

### Étape 7.4 — Ajouter pg_cron pour payouts automatiques
- Cron quotidien à 3h du matin : SELECT payout_queue WHERE status='pending' AND created_at < NOW() - INTERVAL '24 hours'
- Appelle Edge Function ligdicash-payout via pg_net

### Étape 7.5 — Ajouter pg_cron pour expiration abonnements
- Cron quotidien : UPDATE subscriptions SET status='expired' WHERE expires_at < NOW() AND status='active'

### Étape 7.6 — Notifications push
- Notification à l'étudiant quand paiement confirmé
- Notification au commercial quand payout envoyé
- Notification au marchand quand escrow libéré
- Notification à l'admin quand paiement LigdiCash reçu

### Étape 7.7 — Build final + test complet
- Build APK debug
- Vérifier tous les flows end-to-end en mode mock

**Livrable** : App nettoyée, crons configurés, notifications
**Vérification** : Build APK final, tests de tous les flows

---

# RÉSUMÉ DES PHASES

| Phase | Contenu | Dépend de | Sans credentials |
|-------|---------|-----------|-----------------|
| **1** | SQL : tables, colonnes, enums, RPCs, RLS | Rien | ✅ OUI |
| **2** | Edge Functions (4) en mode mock | Phase 1 | ✅ OUI |
| **3** | Widget Flutter LigdiCash + refonte écrans étudiant | Phase 1+2 | ✅ OUI |
| **4** | Abonnements Premium + Paywall | Phase 3 | ✅ OUI |
| **5** | Admin Trésorerie + Payouts + Abonnements | Phase 1 | ✅ OUI |
| **6** | Commercial Payout + Marchand Revenus | Phase 5 | ✅ OUI |
| **7** | Nettoyage + Crons + Notifications | Toutes | ⚠️ Credentials pour mode live |

**TOTAL : 7 phases, toutes exécutables sans credentials LigdiCash (mode mock)**
**Quand les credentials arrivent** : Configurer 3 secrets Supabase + passer LIGDICASH_MODE=live → tout fonctionne.
