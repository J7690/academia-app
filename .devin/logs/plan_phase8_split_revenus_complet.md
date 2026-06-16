# Plan Phase 8 — Split Revenus Configurable + Infos Paiement Obligatoires
## Mécanisme robuste de distribution financière pour TOUS les acteurs
## 19 Mars 2026

---

# A. DIAGNOSTIC — CE QUI MANQUE

## A1. Infos paiement manquantes par acteur

| Acteur | Ce qui existe | Ce qui manque (OBLIGATOIRE avant production) |
|--------|--------------|----------------------------------------------|
| **Étudiant** | `students.phone` | Suffisant — il saisit son numéro dans le LigdiCashPaymentSheet |
| **Commercial** | `commercial_profiles.payout_phone` | ✅ OK (ajouté Phase 1) — à rendre OBLIGATOIRE dans l'UI |
| **Marchand** | `marketplace_merchants.contact_phone` | + `payout_phone`, `payout_operator` (orange/moov/telecel) |
| **Université** | `universities.contact_phone` | + `payout_phone`, `payout_operator`, optionnel: `bank_name`, `bank_account`, `bank_iban` |
| **Enseignant (cours)** | `instructors` : RIEN (5 cols) | + `phone`, `payout_phone`, `payout_operator`, `speciality` |
| **Enseignant TD** | `td_teachers` : pas de phone | + `phone`, `payout_phone`, `payout_operator` |

## A2. Split revenus manquant

| Flux | Split actuel | Ce qui manque |
|------|-------------|---------------|
| **Candidature** (application_fee, registration_fee, tuition) | 100% plateforme - commission commercial (si applicable) | % université, % plateforme configurable |
| **TD** (td_access) | 100% plateforme - commission commercial | % enseignant TD, % plateforme configurable |
| **Abonnement** (subscription) | 100% plateforme | Rien à splitter (OK) |
| **Marketplace** | 10% plateforme + 90% marchand (hardcodé) | Rendre le % configurable par admin |
| **Cours en ligne** (online_course) | Pas de paiement implémenté | % enseignant cours, % plateforme |

---

# B. ARCHITECTURE PROPOSÉE

## B1. Nouvelle table `app.revenue_split_rules`

```
id UUID PK
payment_reason TEXT NOT NULL        -- 'application_fee', 'registration_fee', 'tuition_deposit',
                                    -- 'td_access', 'subscription', 'marketplace_purchase', 'online_course', '*'
beneficiary_type TEXT NOT NULL      -- 'platform', 'university', 'instructor', 'commercial', 'merchant'
percentage NUMERIC NOT NULL         -- 0.70 = 70%
max_amount NUMERIC                  -- plafond optionnel par bénéficiaire
min_amount NUMERIC DEFAULT 0       -- minimum (ex: frais fixe 500 XOF)
is_active BOOLEAN DEFAULT TRUE
description TEXT
priority INTEGER DEFAULT 10
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()
UNIQUE(payment_reason, beneficiary_type)
```

**Seed data :**

| payment_reason | beneficiary_type | percentage | description |
|---------------|-----------------|------------|-------------|
| application_fee | platform | 0.85 | Part plateforme frais de dossier |
| application_fee | commercial | 0.15 | Commission commercial frais de dossier |
| registration_fee | platform | 0.15 | Part plateforme frais inscription |
| registration_fee | university | 0.70 | Part université frais inscription |
| registration_fee | commercial | 0.15 | Commission commercial inscription |
| tuition_deposit | platform | 0.10 | Part plateforme scolarité |
| tuition_deposit | university | 0.80 | Part université scolarité |
| tuition_deposit | commercial | 0.10 | Commission commercial scolarité |
| td_access | platform | 0.30 | Part plateforme TD |
| td_access | instructor | 0.55 | Rémunération enseignant TD |
| td_access | commercial | 0.15 | Commission commercial TD |
| marketplace_purchase | platform | 0.10 | Commission plateforme marketplace |
| marketplace_purchase | merchant | 0.90 | Part marchand marketplace |
| online_course | platform | 0.30 | Part plateforme cours en ligne |
| online_course | instructor | 0.60 | Rémunération enseignant cours |
| online_course | commercial | 0.10 | Commission commercial cours |
| subscription | platform | 1.00 | 100% plateforme pour abonnements |
| * | platform | 0.85 | Défaut plateforme |
| * | commercial | 0.15 | Défaut commercial |

**Contrainte** : Pour chaque `payment_reason`, la somme des `percentage` des bénéficiaires actifs doit = 1.00 (100%). L'admin est alerté si ce n'est pas le cas.

## B2. Colonnes à ajouter sur les tables acteurs

### `marketplace_merchants` (+2 colonnes)
```sql
ADD COLUMN payout_phone TEXT;
ADD COLUMN payout_operator TEXT; -- 'orange_money', 'moov_money', 'telecel_money'
```

### `universities` (+4 colonnes)
```sql
ADD COLUMN payout_phone TEXT;
ADD COLUMN payout_operator TEXT;
ADD COLUMN bank_name TEXT;
ADD COLUMN bank_account TEXT;
```

### `instructors` (+4 colonnes)
```sql
ADD COLUMN phone TEXT;
ADD COLUMN payout_phone TEXT;
ADD COLUMN payout_operator TEXT;
ADD COLUMN speciality TEXT;
```

### `td_teachers` (+3 colonnes)
```sql
ADD COLUMN phone TEXT;
ADD COLUMN payout_phone TEXT;
ADD COLUMN payout_operator TEXT;
```

## B3. Table `app.actor_balances` (portefeuille par acteur)

Généralise `marketplace_merchant_balances` pour TOUS les acteurs.

```
id UUID PK
actor_type TEXT NOT NULL            -- 'commercial', 'merchant', 'university', 'instructor'
actor_id UUID NOT NULL              -- user_id ou merchant_id ou university_id
available_balance NUMERIC DEFAULT 0
pending_balance NUMERIC DEFAULT 0
total_earned NUMERIC DEFAULT 0
total_withdrawn NUMERIC DEFAULT 0
currency TEXT DEFAULT 'XOF'
updated_at TIMESTAMPTZ DEFAULT NOW()
UNIQUE(actor_type, actor_id)
```

---

# C. RPCs À CRÉER / MODIFIER

## C1. Nouvelles RPCs

| RPC | Description |
|-----|-------------|
| `app_admin_list_revenue_split_rules` | Liste toutes les règles de split |
| `app_admin_upsert_revenue_split_rule` | Créer/modifier une règle |
| `app_admin_delete_revenue_split_rule` | Supprimer une règle |
| `app_admin_validate_split_totals` | Vérifie que chaque payment_reason totalise 100% |
| `app_resolve_revenue_split(p_payment_reason)` | Retourne les parts de chaque bénéficiaire pour un type de paiement |
| `app_instructor_get_my_balance` | L'enseignant voit son solde |
| `app_instructor_request_payout(p_phone)` | L'enseignant demande un versement |
| `app_university_get_balance` | L'université voit son solde |
| `app_university_request_payout(p_phone)` | L'université demande un versement |
| `app_admin_list_actor_balances` | L'admin voit les soldes de tous les acteurs |

## C2. Modifier `app_confirm_ligdicash_payment`

Actuellement la RPC ne calcule que la commission commerciale. Elle doit être modifiée pour :
1. Appeler `app_resolve_revenue_split(payment_reason)` → obtenir les parts
2. Pour chaque bénéficiaire avec `percentage > 0` :
   - Calculer le montant = `amount_paid × percentage`
   - Si `beneficiary_type = 'commercial'` → utiliser le système existant (fn_resolve_commission_rate + cap dégressif) comme override plus précis
   - Si `beneficiary_type = 'university'` → créditer `actor_balances` + INSERT `payout_queue`
   - Si `beneficiary_type = 'instructor'` → créditer `actor_balances` + INSERT `payout_queue`
   - Si `beneficiary_type = 'platform'` → INSERT `platform_ledger` (credit)
   - Si `beneficiary_type = 'merchant'` → déjà géré par `marketplace_release_escrow`

## C3. Modifier `app_marketplace_process_payment`

Remplacer `v_commission_rate := 0.10` codé en dur par une lecture de `revenue_split_rules WHERE payment_reason = 'marketplace_purchase' AND beneficiary_type = 'platform'`.

---

# D. ÉCRANS FLUTTER

## D1. Admin — Nouvel onglet "Répartition revenus" (ou intégrer dans Grille commissions)

Écran permettant à l'admin de :
- Voir tous les splits par `payment_reason` (tableau visuel)
- Modifier les % pour chaque bénéficiaire
- Vérifier que chaque flux totalise 100% (indicateur vert/rouge)
- Activer/désactiver des règles

**UI : Tableau avec colonnes**
```
Type de paiement | Plateforme | Université | Enseignant | Commercial | Marchand | Total
────────────────────────────────────────────────────────────────────────────────────────
Frais de dossier |    85%     |     0%     |     0%     |    15%     |    —     | 100% ✅
Inscription      |    15%     |    70%     |     0%     |    15%     |    —     | 100% ✅
Scolarité        |    10%     |    80%     |     0%     |    10%     |    —     | 100% ✅
Accès TD         |    30%     |     0%     |    55%     |    15%     |    —     | 100% ✅
Marketplace      |    10%     |     —      |     —      |     —      |   90%   | 100% ✅
Cours en ligne   |    30%     |     0%     |    60%     |    10%     |    —     | 100% ✅
Abonnement       |   100%     |     0%     |     0%     |     0%     |    —     | 100% ✅
```

## D2. Admin — Nouvel onglet "Soldes acteurs"

Liste tous les acteurs avec leur solde, filtrable par type.

## D3. Enseignant — Section "Mes revenus"

Dans le dashboard enseignant (10 tabs), ajouter un 11ème tab "Mes revenus" :
- Solde disponible
- Historique des versements
- Bouton "Retirer mes revenus" → saisie numéro mobile money → payout_queue

## D4. Université — Section "Mes revenus"

Dans le dashboard université, modifier l'onglet "Paiements" ou ajouter :
- Solde disponible (part université des paiements confirmés)
- Bouton "Demander un versement" → saisie numéro

## D5. Chaque acteur — Formulaire infos paiement obligatoires

### Marchand : dans la console marchand
- Champs obligatoires à remplir : `payout_phone`, `payout_operator`
- Alerte si non rempli : "Complétez vos informations de paiement pour recevoir vos revenus"

### Enseignant : dans le dashboard enseignant
- Champs : `phone`, `payout_phone`, `payout_operator`
- Alerte si non rempli

### Université : dans le dashboard université
- Champs : `payout_phone`, `payout_operator`, optionnel `bank_name`, `bank_account`
- Alerte si non rempli

### Commercial : dans le dashboard commercial
- `payout_phone` existe déjà mais doit être obligatoire
- Alerte si non rempli : "Configurez votre numéro mobile money"

---

# E. PLAN D'IMPLÉMENTATION EN 3 SOUS-PHASES

## Phase 8A — Supabase : table revenue_split_rules + colonnes acteurs + RPCs

### Étape 8A.1 — Audit Supabase pré-implémentation
### Étape 8A.2 — Créer `app.revenue_split_rules` + seed data
### Étape 8A.3 — Créer `app.actor_balances`
### Étape 8A.4 — Ajouter colonnes sur `marketplace_merchants`, `universities`, `instructors`, `td_teachers`
### Étape 8A.5 — Créer RPCs : list/upsert/delete split rules, validate totals, resolve split
### Étape 8A.6 — Créer RPCs : instructor_get_balance, instructor_request_payout, university_get_balance, university_request_payout, admin_list_actor_balances
### Étape 8A.7 — Modifier `app_confirm_ligdicash_payment` → utiliser revenue_split_rules pour distribuer automatiquement
### Étape 8A.8 — Modifier `app_marketplace_process_payment` → lire le % depuis revenue_split_rules
### Étape 8A.9 — Vérification post-implémentation

## Phase 8B — Flutter Admin : écran répartition revenus + soldes acteurs

### Étape 8B.1 — Audit Flutter
### Étape 8B.2 — Créer `admin_revenue_split_provider.dart`
### Étape 8B.3 — Créer `admin_revenue_split_screen.dart` (tableau visuel avec % éditables + validation 100%)
### Étape 8B.4 — Créer `admin_actor_balances_provider.dart` + `admin_actor_balances_screen.dart`
### Étape 8B.5 — Ajouter les 2 nouveaux onglets dans admin_dashboard_screen (27→29 tabs)
### Étape 8B.6 — Build APK

## Phase 8C — Flutter Acteurs : revenus + formulaires infos paiement obligatoires

### Étape 8C.1 — Audit Flutter dashboards acteurs
### Étape 8C.2 — Enseignant : onglet "Mes revenus" (11ème tab) + formulaire infos paiement
### Étape 8C.3 — Université : section revenus + formulaire infos paiement
### Étape 8C.4 — Marchand : formulaire infos paiement obligatoires (alerte si non rempli)
### Étape 8C.5 — Commercial : alerte payout_phone obligatoire
### Étape 8C.6 — Build APK final

---

# F. RÉSUMÉ

| Sous-phase | Contenu | Dépendance |
|-----------|---------|------------|
| **8A** | SQL : 2 tables, ~14 colonnes, ~10 RPCs, modifier 2 RPCs existantes, seed 19 règles | Phases 1-7 |
| **8B** | Flutter admin : 2 providers, 2 écrans, 29 tabs | 8A |
| **8C** | Flutter acteurs : 4 dashboards modifiés (enseignant, université, marchand, commercial) | 8A |

**Principe clé : l'admin contrôle TOUT depuis un seul écran.** Chaque % est configurable. Chaque paiement confirmé déclenche automatiquement la distribution vers tous les bénéficiaires. Chaque acteur voit son solde et peut demander un retrait.
