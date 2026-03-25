# Audit Complet Module Paiements — 19 Mars 2026

## 1. ARCHITECTURE SUPABASE

### 1.1 Tables (4 tables, schema `app`)

| Table | Colonnes | Description |
|-------|----------|-------------|
| `application_payments` | 21 cols | Table principale des paiements |
| `payment_receipts` | 6 cols | Reçus générés après confirmation |
| `payment_proofs` | 7 cols | Justificatifs uploadés |
| `marketplace_payments` | ? | Paiements marketplace (séparé) |

### 1.2 Colonnes `application_payments` (21)

| Colonne | Type | Nullable | Default |
|---------|------|----------|---------|
| `id` | uuid | NO | gen_random_uuid() |
| `application_id` | uuid | YES | NULL |
| `student_id` | uuid | NO | - |
| `university_id` | uuid | YES | NULL |
| `amount_due` | numeric | NO | - |
| `amount_paid` | numeric | YES | NULL |
| `currency` | text | NO | 'XOF' |
| `payment_reason` | USER-DEFINED (enum) | NO | - |
| `channel` | USER-DEFINED (enum) | YES | NULL |
| `status` | USER-DEFINED (enum) | NO | 'pending' |
| `reference_code` | text | NO | - |
| `external_reference` | text | YES | NULL |
| `student_note` | text | YES | NULL |
| `created_by` | uuid | YES | NULL |
| `verified_by` | uuid | YES | NULL |
| `confirmed_by` | uuid | YES | NULL |
| `created_at` | timestamptz | NO | now() |
| `updated_at` | timestamptz | NO | now() |
| `verified_at` | timestamptz | YES | NULL |
| `confirmed_at` | timestamptz | YES | NULL |
| `declared_at` | timestamptz | YES | NULL |

### 1.3 Colonnes `payment_receipts` (6)

| Colonne | Type |
|---------|------|
| `id` | uuid (PK) |
| `payment_id` | uuid (FK → application_payments) |
| `receipt_number` | text (UNIQUE) |
| `issued_by` | uuid |
| `issued_at` | timestamptz |
| `snapshot` | jsonb |

### 1.4 Colonnes `payment_proofs` (7)

| Colonne | Type |
|---------|------|
| `id` | uuid (PK) |
| `payment_id` | uuid (FK → application_payments) |
| `proof_type` | text |
| `file_path` | text |
| `uploaded_by` | uuid |
| `uploaded_at` | timestamptz |
| `note` | text (nullable) |

### 1.5 Enums utilisés

- **`payment_status`** : pending, declared_by_student, under_verification, confirmed, rejected, cancelled
- **`payment_reason`** : application_fee, registration_fee, tuition_deposit, td_access, other
- **`payment_channel`** : orange_money, moov_money, telecel_money, cash

### 1.6 Contraintes & FK

- `application_payments.application_id` → `applications.id`
- `application_payments.student_id` → `students.id`
- `application_payments.university_id` → `universities.id`
- `payment_proofs.payment_id` → `application_payments.id`
- `payment_receipts.payment_id` → `application_payments.id`
- UNIQUE: `reference_code`, `external_reference` (WHERE NOT NULL), `receipt_number`

### 1.7 Index (12)

- PK: application_payments_pkey, payment_proofs_pkey, payment_receipts_pkey
- UNIQUE: reference_code, external_reference (partial), receipt_number
- BTREE: application_id, student_id, university_id, status, payment_proofs.payment_id, payment_receipts.payment_id

---

## 2. RPCs (20 fonctions)

### 2.1 RPCs Étudiant (3)

| RPC | Params | Description |
|-----|--------|-------------|
| `app_student_declare_payment` | p_payment_id, p_channel, p_amount_paid, p_external_reference, p_student_note | Déclare un paiement existant (status → declared_by_student) |
| `app_create_application_payment` | p_application_id, p_payment_reason, p_amount_due | Crée un paiement lié à une candidature (ref AP-*) |
| `app_student_create_profile_payment` | p_payment_reason, p_amount_due | Crée un paiement lié au profil (ref PR-*) |

### 2.2 RPCs Admin (5)

| RPC | Description |
|-----|-------------|
| `app_admin_verify_payment` | Vérifie (valid → under_verification, invalid → rejected) |
| `app_admin_confirm_payment` | Confirme + génère reçu + auto-commission commerciale |
| `app_admin_get_payment_detail` | Détail complet (payment + receipts + proofs + context) |
| `app_admin_list_payments_with_context` | Liste tous les paiements avec programme/université |
| `app_admin_list_payment_receipts_with_context` | Liste tous les reçus avec contexte |

### 2.3 RPCs Université (1)

| RPC | Description |
|-----|-------------|
| `app_university_list_payments` | Liste paiements de l'université (filtre university_id) |

### 2.4 RPCs Notification (5 triggers functions)

| RPC | Trigger |
|-----|---------|
| `app_notify_admin_payment_declared` | INSERT/UPDATE sur application_payments |
| `app_notify_student_payment_status` | UPDATE sur application_payments |
| `app_notify_university_payment` | INSERT/UPDATE sur application_payments |
| `app_notify_commercial_payment_confirmed` | UPDATE sur application_payments |
| `app_notify_commercial_prospect_payment` | INSERT/UPDATE sur application_payments |

### 2.5 RPCs Commission (2)

| RPC | Description |
|-----|-------------|
| `app_generate_referral_commission_for_payment` | Génère commission (appelé inline dans confirm) |
| `app_on_payment_confirmed_generate_referral_commission` | Trigger function (DÉSACTIVÉ) |

### 2.6 RPCs Marketplace & TD (2)

| RPC | Description |
|-----|-------------|
| `app_marketplace_process_payment` | Paiement marketplace |
| `app_td_student_create_enrollment_and_payment` | Inscription TD + paiement |

### 2.7 Autres (1)

| RPC | Description |
|-----|-------------|
| `payment_receipts_block_changes` (schema app) | Empêche UPDATE/DELETE sur reçus |

---

## 3. RLS Policies (5)

| Table | Policy | Cmd | Rule |
|-------|--------|-----|------|
| application_payments | `admin_select_all_payments` | SELECT | role = 'admin' |
| application_payments | `student_select_own_payments` | SELECT | student_id = auth.uid() |
| application_payments | `university_select_own_payments` | SELECT | university_id match |
| payment_proofs | `student_select_own_payment_proofs` | SELECT | via payment owner |
| payment_receipts | `authenticated_select_payment_receipts` | SELECT | true (any auth) |

**Note:** Pas de policy INSERT/UPDATE/DELETE pour application_payments côté étudiant → tout passe par les RPCs SECURITY DEFINER.

---

## 4. Triggers (11)

| Trigger | Event | Table | Action |
|---------|-------|-------|--------|
| trg_admin_payment_declared_notify | INSERT, UPDATE | application_payments | Notif admin |
| trg_student_payment_status_notify | UPDATE | application_payments | Notif étudiant |
| trg_uni_payment_notify | INSERT, UPDATE | application_payments | Notif université |
| trg_commercial_payment_confirmed_notify | UPDATE | application_payments | Notif commercial |
| trg_commercial_prospect_payment_notify | INSERT, UPDATE | application_payments | Notif commercial prospect |
| trg_app_application_payments_referral_commission | UPDATE | application_payments | Commission (DÉSACTIVÉ) |
| payment_receipts_no_delete | DELETE | payment_receipts | BLOCK |
| payment_receipts_no_update | UPDATE | payment_receipts | BLOCK |

---

## 5. Données existantes

- **6 paiements** total (5 confirmed, 1 declared_by_student)
- **5 reçus** générés
- **Reasons** : application_fee (3), registration_fee (1), tuition_deposit (1), td_access (1)
- **Channels** : cash (3), orange_money (2), telecel_money (1)
- **1 seul étudiant** (6745c7ad-...) a des paiements

---

## 6. ARCHITECTURE FLUTTER

### 6.1 Écrans (7 fichiers)

| Fichier | Rôle | Lignes |
|---------|------|--------|
| `features/student/student_payments_screen.dart` | Écran principal étudiant "Mes paiements" | 1627 |
| `features/student/student_application_detail_screen.dart` | Déclarer paiement depuis détail candidature | 1086 |
| `features/admin/admin_payments_screen.dart` | Liste admin de tous les paiements | 562 |
| `features/admin/admin_payment_detail_screen.dart` | Détail admin d'un paiement (timeline + reçus + proofs) | 458 |
| `features/admin/admin_payment_receipts_screen.dart` | Liste admin des reçus | 277 |
| `features/admin/admin_application_detail_screen.dart` | Section paiement dans détail candidature admin | 713 |
| `features/university/university_payments_screen.dart` | Vue université des paiements | 427 |

### 6.2 Providers (6 fichiers)

| Provider | RPCs utilisées |
|----------|----------------|
| `StudentApplicationPaymentsProvider` | loadMyPayments (SELECT direct), loadPayments, declareExistingPayment (app_student_declare_payment), createAndDeclarePayment (app_create_application_payment + declare), createAndDeclareProfilePayment (app_student_create_profile_payment + declare), getReceiptsForPayment (SELECT direct) |
| `AdminPaymentsProvider` | loadAllPayments (app_admin_list_payments_with_context), verifyPayment (app_admin_verify_payment), confirmPayment (app_admin_confirm_payment) |
| `AdminPaymentDetailProvider` | loadDetail (app_admin_get_payment_detail) |
| `AdminPaymentReceiptsProvider` | loadAllReceipts (app_admin_list_payment_receipts_with_context) |
| `AdminApplicationPaymentsProvider` | loadPaymentsForApplication (SELECT direct), verifyPayment, confirmPayment |
| `UniversityPaymentsProvider` | loadPayments (app_university_list_payments) |
| `UniversityApplicationPaymentsProvider` | loadPaymentsForApplication (SELECT direct) |

### 6.3 Utilitaires (1 fichier)

| Fichier | Description |
|---------|-------------|
| `utils/payment_receipt_pdf.dart` | Génère PDF reçu via `pdf` + `printing` packages |

### 6.4 Navigation

- **Étudiant** : Tab index 6 dans `student_dashboard_screen.dart` → `StudentPaymentsScreen`
- **Admin** : Tab "Paiements" + Tab "Reçus" dans `admin_dashboard_screen.dart` → `AdminPaymentsScreen` + `AdminPaymentReceiptsScreen`
- **Admin detail** : Tap sur un paiement → `AdminPaymentDetailScreen`
- **Université** : `UniversityPaymentsScreen`

### 6.5 Canaux de paiement (Flutter)

Canaux hardcodés dans les DropdownMenuItems :
- `orange_money` → Orange Money
- `moov_money` → Moov Money
- `telecel_money` → Telecel Money
- `cash` → Espèces / guichet

### 6.6 Statuts de paiement (Flutter)

Statuts affichés via _statusChip() :
- `pending` → En attente (orange)
- `declared_by_student` → Déclaré (blueGrey)
- `under_verification` → En vérification (blue)
- `confirmed` → Confirmé (green)
- `rejected` → Rejeté (red)
- `cancelled` → Annulé (grey)

---

## 7. FLOW DE PAIEMENT ACTUEL

```
1. ÉTUDIANT crée un paiement
   → app_create_application_payment (lié à candidature)
   → app_student_create_profile_payment (lié au profil)
   → status = 'pending'

2. ÉTUDIANT déclare le paiement (canal, montant, référence)
   → app_student_declare_payment
   → status = 'declared_by_student'

3. ADMIN vérifie le paiement
   → app_admin_verify_payment (valid → under_verification, invalid → rejected)

4. ADMIN confirme le paiement
   → app_admin_confirm_payment
   → status = 'confirmed'
   → Génère reçu (payment_receipts)
   → Auto-calcul commission commerciale (si applicable)

5. Notifications à chaque étape via triggers
```

---

## 8. CE QUI MANQUE POUR LIGDICASH

Le système actuel est **100% manuel** : l'étudiant paie en dehors de la plateforme puis déclare son paiement. Avec LigdiCash, il faudra :

1. **Paiement in-app** : l'étudiant initie le paiement depuis l'app → LigdiCash API → confirmation automatique
2. **Webhook callback** : LigdiCash notifie le serveur quand le paiement est réussi → auto-confirm
3. **Nouveau canal** : `ligdicash` à ajouter à l'enum `payment_channel`
4. **Edge Function** : `ligdicash-payment` pour initier et recevoir les callbacks
5. **Colonne optionnelle** : `ligdicash_transaction_id` pour traçabilité
6. **Écran Flutter** : Redirection vers page de paiement LigdiCash ou widget intégré

Le flow deviendrait :
```
1. Étudiant choisit "Payer via LigdiCash" dans l'app
2. Edge Function crée une invoice LigdiCash → retourne URL de paiement
3. Étudiant complète le paiement (Orange/Moov/Telecel via LigdiCash)
4. LigdiCash envoie webhook → Edge Function → auto-confirm payment + génère reçu
5. L'étudiant voit "Confirmé" instantanément
```
