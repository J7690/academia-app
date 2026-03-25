# AUDIT ULTRA-RIGOUREUX — Système Commercial Academia
## 15 Mars 2026

---

## 1. CARTOGRAPHIE SUPABASE

### 1.1 Tables (schema `app`)

| Table | PK | Colonnes clés | Lignes |
|-------|-----|---------------|--------|
| `commercial_profiles` | `user_id` (UUID, FK auth.users) | ref_code, ref_link, commission_rate (NUMERIC, default 5.00), is_active, tier (default 'bronze'), max_commissions_per_prospect (default 3), total_confirmed_payments (default 0), admin_notes, deactivated_at | **7** |
| `user_referrals` | `id` (UUID) | student_id, commercial_user_id, ref_code, source (default 'link'), attributed_at, expires_at, metadata (JSONB) | **1** |
| `referral_commissions` | `id` (UUID) | commercial_user_id, student_id, payment_id, commission_rate, commission_amount, currency (default 'XOF'), status (default 'pending'), approved_at, paid_at, admin_note | **0** |
| `commission_rules` | `id` (UUID) | payment_reason (default '*'), degree_level (default '*'), commission_rate (default 0.10), max_amount (default 0), currency, is_active, description, priority | **13** |
| `commercial_milestones` | `id` (UUID) | threshold, bonus_amount, currency, label, description | **4** (seuils: 5/15/30/50) |
| `commercial_milestone_claims` | `id` (UUID) | commercial_user_id, milestone_id, claimed_at, status (default 'pending'), paid_at | **0** |
| `user_invitations` | `id` (UUID) | token, email, role, university_id, full_name, notes, status (default 'pending'), created_by_admin_id, used_at, expires_at | **0** |

> ⚠️ **Table `commercial_tiers` N'EXISTE PAS** — le tier est un champ TEXT dans `commercial_profiles`, mis à jour par trigger.

### 1.2 RPCs (24 fonctions)

#### Côté Commercial (self-service)
| RPC | Rôle |
|-----|------|
| `app_commercial_get_dashboard` | Dashboard complet (profile, summary, referrals anonymisés, commissions, gamification, leaderboard) |
| `app_commercial_claim_milestone` | Réclamer un bonus de palier |
| `app_register_referral_for_current_user(p_ref_code, p_source, p_metadata)` | Attacher un étudiant à un commercial via code referral |

#### Côté Admin
| RPC | Rôle |
|-----|------|
| `app_admin_list_commercials_overview` | Liste des commerciaux avec stats agrégées |
| `app_admin_get_commercial_detail(p_commercial_user_id)` | Détail d'un commercial (profil, referrals, commissions) |
| `app_admin_set_commercial_commission_rate(p_user_id, p_rate)` | Modifier le taux de commission |
| `app_admin_update_commercial_cap(p_user_id, p_max_cap)` | Modifier le cap de commissions/prospect |
| `app_admin_update_referral_commission_status(p_commission_id, p_new_status, p_admin_note)` | Changer statut commission (pending→approved→paid/rejected) |
| `app_admin_list_milestone_claims(p_status)` | Lister les réclamations de bonus |
| `app_admin_update_milestone_claim_status(p_claim_id, p_new_status)` | Valider/rejeter un bonus |
| `app_admin_list_commission_rules` | CRUD grille de commissions |
| `app_admin_upsert_commission_rule(...)` | Créer/modifier une règle |
| `app_admin_delete_commission_rule(p_rule_id)` | Supprimer une règle |

#### Fonctions internes
| RPC | Rôle |
|-----|------|
| `fn_resolve_commission_rate(p_payment_reason, p_degree_level)` | Résoudre le taux depuis commission_rules (exact → wildcard) |
| `fn_check_commission_cap(p_commercial_user_id, p_student_id)` | Vérifier le cap dégressif par prospect |
| `fn_update_commercial_tier()` | Trigger: recalculer tier + total_confirmed_payments |
| `app_generate_referral_commission_for_payment(p_payment_id)` | Générer commission pour un paiement (chemin trigger) |
| `app_on_payment_confirmed_generate_referral_commission()` | Trigger function sur application_payments UPDATE |

#### Notifications
| RPC | Rôle |
|-----|------|
| `app_notify_commercial_commission` | Trigger INSERT sur referral_commissions |
| `app_notify_commercial_referral` | Trigger INSERT sur user_referrals |
| `app_notify_commercial_payment_confirmed` | Trigger UPDATE sur application_payments |
| `app_notify_commercial_prospect_payment` | Trigger INSERT/UPDATE sur application_payments |

### 1.3 Triggers

| Trigger | Table | Event | Fonction |
|---------|-------|-------|----------|
| `trg_app_application_payments_referral_commission` | application_payments | AFTER UPDATE | `app_on_payment_confirmed_generate_referral_commission` |
| `trg_commercial_commission_notify` | referral_commissions | AFTER INSERT | `app_notify_commercial_commission` |
| `trg_update_commercial_tier` | referral_commissions | AFTER INSERT/UPDATE/DELETE | `fn_update_commercial_tier` |
| `trg_commercial_referral_notify` | user_referrals | AFTER INSERT | `app_notify_commercial_referral` |
| `trg_admin_payment_declared_notify` | application_payments | AFTER INSERT/UPDATE | `app_notify_admin_payment_declared` |
| `trg_commercial_payment_confirmed_notify` | application_payments | AFTER UPDATE | `app_notify_commercial_payment_confirmed` |
| `trg_commercial_prospect_payment_notify` | application_payments | AFTER INSERT/UPDATE | `app_notify_commercial_prospect_payment` |

### 1.4 RLS Policies

| Table | Policy | Cmd | Condition |
|-------|--------|-----|-----------|
| commercial_profiles | admin_select | SELECT | role = 'admin' |
| commercial_profiles | commercial_select_own | SELECT | user_id = auth.uid() |
| referral_commissions | admin_select_all | SELECT | role = 'admin' |
| referral_commissions | commercial_select_own | SELECT | commercial_user_id = auth.uid() |
| user_referrals | admin_select_all | SELECT | role = 'admin' |
| user_referrals | commercial_select_own | SELECT | commercial_user_id = auth.uid() |
| user_referrals | student_select_own | SELECT | student_id = auth.uid() |
| user_invitations | admin_all | ALL | role = 'admin' |

### 1.5 Données réelles

- **7 commerciaux** — TOUS `tier=bronze`, `total_confirmed_payments=0`
- **1 seul referral** (COMM-62acd95a → étudiant 03de29af)
- **0 commissions** générées
- **5 paiements confirmés** — AUCUN n'est lié à un étudiant référé (commercial_id=null)
- **46 étudiants**, **19 candidatures**, **6 paiements** (5 confirmés)
- **2 domaines Netlify** différents dans les ref_links

---

## 2. CARTOGRAPHIE FLUTTER

### 2.1 Fichiers

| Fichier | Rôle | Lignes |
|---------|------|--------|
| `lib/features/commercial/commercial_dashboard_screen.dart` | Dashboard commercial (3 onglets: Accueil, Prospects, Finances) | 1933 |
| `lib/providers/commercial_dashboard_provider.dart` | Provider dashboard commercial | 138 |
| `lib/features/admin/admin_commercials_screen.dart` | Onglet admin gestion commerciaux + milestone claims | 1327 |
| `lib/providers/admin_users_overview_provider.dart` | Provider admin (users, commercials overview, commissions, milestones, caps) | 547 |
| `lib/providers/admin_commission_rules_provider.dart` | Provider admin grille commissions | 105 |
| `lib/features/auth/auth_wrapper.dart` | Attachement referral après login | ~160 (section referral) |
| `lib/features/auth/auth_landing_screen.dart` | Capture du code referral depuis URL | ~30 (section referral) |

### 2.2 Flux Flutter

**Dashboard Commercial** (CommercialDashboardScreen)
- Appelle `app_commercial_get_dashboard` via `CommercialDashboardProvider.loadDashboard()`
- 3 onglets: Accueil (tier, lien, KPIs, leaderboard), Prospects (liste anonymisée), Finances (commissions, paiements, milestones)
- `claimMilestone(id)` → `app_commercial_claim_milestone`

**Admin Commerciaux** (AdminCommercialsScreen)
- Utilise `AdminUsersOverviewProvider`
- Appelle `loadUsers()` → `app_admin_list_users_overview` + `loadCommercialsOverview()` → `app_admin_list_commercials_overview` + `loadMilestoneClaims()`
- Filtre les users par `role == 'commercial'`
- Actions: modifier taux commission, suspendre/réactiver, détail, supprimer, historique, partager lien

---

## 3. BUGS CRITIQUES IDENTIFIÉS

### 🔴 BUG 1 — ref_code et ref_link INVISIBLES dans l'écran admin commerciaux

**Gravité: HAUTE** — L'admin ne voit pas les codes/liens de parrainage des commerciaux.

**Cause racine**: `app_admin_list_users_overview` retourne `{id, email, role, full_name, created_at, last_activity_at, is_online, is_suspended, ...}` mais **PAS** `ref_code` ni `ref_link`.

**Code Flutter** (`admin_commercials_screen.dart` lignes 661-664):
```dart
final refCode = user['ref_code']?.toString() ?? '';
final refLink = user['ref_link']?.toString() ?? '';
```
→ Toujours `''` car ces champs n'existent pas dans le résultat de `loadUsers()`.

**Conséquence**: Les boutons "Copier le lien" et "Partager" sont affichés avec `refLink.isNotEmpty` (lignes 878, 896) mais ne sont jamais visibles car `refLink` est toujours vide.

**Correction**: Fusionner les données de `commercialsOverview` (qui contient `ref_code` et `ref_link`) dans l'affichage, OU enrichir `app_admin_list_users_overview` avec un LEFT JOIN sur `commercial_profiles`.

---

### 🔴 BUG 2 — Incohérence d'UNITÉS entre commission_rules et commercial_profiles

**Gravité: CRITIQUE** — Le mécanisme de cap dégressif est complètement non-fonctionnel.

**Faits**:
- `commission_rules.commission_rate` stocke des **fractions** : `0.12` = 12%, `0.10` = 10%, `0.20` = 20%
- `commercial_profiles.commission_rate` stocke des **pourcentages** : `5.0` = 5%, `2.0` = 2%, `9.0` = 9%
- `fn_resolve_commission_rate` retourne le taux en **fraction** (ex: 0.12)
- `fn_check_commission_cap` retourne le taux en **pourcentage** (ex: 5.0, 4.25, 3.61...)

**Dans `app_admin_confirm_payment`**:
```sql
v_final_rate := LEAST(v_resolved_rate, v_cap_adjusted_rate);
-- LEAST(0.12, 5.0) = 0.12 → le cap n'est JAMAIS appliqué
v_commission_amount := ROUND(v_payment.amount_paid * v_final_rate, 0);
-- 50000 * 0.12 = 6000 (12%) → correct pour rules, mais le cap de 5% est ignoré
```

**Comparaison avec `app_generate_referral_commission_for_payment`** (chemin trigger):
```sql
v_rate := COALESCE(v_profile.commission_rate, 5.00); -- pourcentage
v_amount := ROUND(v_payment.amount_paid * v_rate / 100.0, 2);
-- 50000 * 5.0 / 100 = 2500 (5%) → correct, divise par 100
```

**Conséquence**: Le chemin inline dans `app_admin_confirm_payment` utilise le taux des rules (fraction) sans conversion. Le cap dégressif (qui est en pourcentage) est toujours plus grand numériquement (5.0 > 0.12), donc `LEAST` choisit toujours le taux des rules. **Le mécanisme dégressif est 100% contourné.**

**Correction**: Convertir le cap_adjusted_rate en fraction : `v_cap_adjusted_rate / 100.0` avant le `LEAST`, OU stocker les taux dans la même unité partout.

---

### 🔴 BUG 3 — Double chemin de génération de commission (conflit trigger / inline)

**Gravité: HAUTE** — Deux mécanismes distincts tentent de créer des commissions avec des règles différentes.

| Aspect | Chemin inline (`app_admin_confirm_payment`) | Chemin trigger (`app_generate_referral_commission_for_payment`) |
|--------|---------------------------------------------|----------------------------------------------------------------|
| **Déclenché par** | Code inline dans la fonction | Trigger AFTER UPDATE sur application_payments |
| **Éligibilité payment_reason** | TOUS (via `fn_resolve_commission_rate`) | `registration_fee` et `tuition_deposit` UNIQUEMENT |
| **Taux** | `fn_resolve_commission_rate` (fraction 0.12) | `commercial_profiles.commission_rate` (pourcentage 5.0) / 100 |
| **Calcul montant** | `amount * rate` (pas de /100) | `amount * rate / 100` |
| **Cap dégressif** | `fn_check_commission_cap` (non-fonctionnel, cf BUG 2) | Non implémenté |
| **Doublon check** | Par `payment_id + commercial_user_id` | Par `commercial_user_id + student_id` (max 1 par paire) |
| **Commission multiple/étudiant** | Oui, jusqu'au cap | Non, strict 1 par paire |

**Séquence réelle**:
1. `app_admin_confirm_payment` fait `UPDATE application_payments SET status='confirmed'`
2. Le trigger AFTER UPDATE se déclenche et appelle `app_generate_referral_commission_for_payment`
3. Le trigger crée une commission (si éligible)
4. Le code inline continue et tente aussi de créer une commission
5. Le check inline (`IF NOT EXISTS WHERE payment_id = ...`) trouve la commission du trigger → SKIP

**Conséquence pour le 1er paiement**: Le trigger crée la commission avec le taux du profil (/100 = correct 5%), le code inline est court-circuité. Résultat correct par accident.

**Conséquence pour les paiements suivants**: Le trigger skip (paire déjà traitée), le code inline crée avec le taux des rules (fraction brute = 12%). Résultat potentiellement incorrect si le cap devrait s'appliquer.

**Correction**: Supprimer un des deux chemins. Recommandation: garder le chemin inline (plus riche avec cap + rules) et désactiver le trigger, après avoir corrigé le BUG 2.

---

### 🔴 BUG 4 — Capture de referral INOPÉRANTE sur mobile (Android/iOS)

**Gravité: CRITIQUE** — Le système de parrainage ne fonctionne pas du tout sur l'app mobile native.

**Mécanisme actuel**:
1. `auth_landing_screen.dart` → `_captureReferralFromUrlIfPresent()` utilise `Uri.base` pour extraire `?ref=COMM-xxx`
2. Stocke dans `SharedPreferences('pending_referral_code_v1')`
3. `auth_wrapper.dart` → `_attachReferralIfNeeded()` appelle `app_register_referral_for_current_user` après login

**Problème**: `Uri.base` retourne l'URL du navigateur web uniquement. Sur Android/iOS natif, `Uri.base` retourne `''` ou l'URL du fichier local. **Aucun deep link handler n'est configuré** pour capturer les codes referral depuis des liens ouverts sur mobile.

**Preuve**: Sur 46 étudiants et 7 commerciaux, il n'y a que **1 seul referral** dans la base de données. Le système est essentiellement non-fonctionnel.

**Correction**: Implémenter la capture de referral via:
- Deep links Android (App Links / Intent filters)
- Ou un mécanisme de saisie manuelle du code referral à l'inscription
- Ou un QR code scannable

---

### 🟡 BUG 5 — Compteur `total_confirmed_payments` mal nommé et incohérent avec le tier

**Gravité: MOYENNE**

**Dans `fn_update_commercial_tier`**:
```sql
-- Tier calculé sur COUNT(DISTINCT student_id) avec status IN ('pending','approved','paid')
IF v_count >= 30 THEN v_new_tier := 'diamond';
-- Compteur calculé sur COUNT(*) (pas DISTINCT)
total_confirmed_payments = (SELECT COUNT(*) FROM referral_commissions WHERE ...)
```

- Le **tier** utilise `COUNT(DISTINCT student_id)` → nombre d'étudiants uniques
- Le **compteur** utilise `COUNT(*)` → nombre total de commissions (plusieurs par étudiant possible)
- Le nom `total_confirmed_payments` est trompeur car il inclut aussi les commissions `pending` et `approved`, pas seulement `paid`

---

### 🟡 BUG 6 — Deux domaines Netlify dans les ref_links

**Gravité: MOYENNE**

- 5 profils: `dulcet-snickerdoodle-915a6b.netlify.app`
- 2 profils: `amazing-boba-9a75a7.netlify.app`

Si l'un des déploiements n'est plus actif, les liens de ces commerciaux sont cassés. Les liens devraient utiliser un domaine unique et stable.

---

### 🟡 BUG 7 — `app_generate_referral_commission_for_payment` trop restrictif

**Gravité: MOYENNE**

Ce RPC (chemin trigger) n'accepte que `registration_fee` et `tuition_deposit`:
```sql
IF v_payment.payment_reason NOT IN ('registration_fee', 'tuition_deposit') THEN
    RETURN ...payment_reason_not_eligible
```

Mais la grille `commission_rules` contient des règles pour `application_fee` (rate 0.20, max 5000) et `td_access` (rate 0.15, max 3000). Ces règles ne sont jamais utilisées par le chemin trigger.

---

## 4. DONNÉES ET ÉTAT ACTUEL

### 4.1 Commerciaux (7 profils)

| ref_code | tier | rate | referrals | commissions | domain |
|----------|------|------|-----------|-------------|--------|
| COMM-12826361 | bronze | 2.0% | 0 | 0 | amazing-boba |
| COMM-0ad9ffeb | bronze | 5.0% | 0 | 0 | amazing-boba |
| COMM-62acd95a | bronze | 2.0% | **1** | 0 | dulcet-snickerdoodle |
| COMM-76c552f3 | bronze | 9.0% | 0 | 0 | dulcet-snickerdoodle |
| COMM-44abfda3 | bronze | 2.0% | 0 | 0 | dulcet-snickerdoodle |
| COMM-f1936fc2 | bronze | 5.0% | 0 | 0 | dulcet-snickerdoodle |
| COMM-015b351f | bronze | 5.0% | 0 | 0 | dulcet-snickerdoodle |

### 4.2 Paiements confirmés (5)

Tous pour le même étudiant (6745c7ad), AUCUN n'est référé par un commercial:
- td_access: 2000 XOF
- registration_fee: 3000 XOF
- application_fee: 20 XOF
- tuition_deposit: 250 XOF
- application_fee: 250 XOF

### 4.3 Commission Rules (13 règles)

| payment_reason | degree_level | rate | max_amount |
|----------------|-------------|------|------------|
| application_fee | * | 0.20 (20%) | 5000 XOF |
| registration_fee | BTS | 0.10 (10%) | 15000 XOF |
| registration_fee | Licence | 0.12 (12%) | 25000 XOF |
| registration_fee | LMD | 0.12 (12%) | 25000 XOF |
| registration_fee | licence | 0.12 (12%) | 25000 XOF |
| td_access | * | 0.15 (15%) | 3000 XOF |
| tuition_deposit | * | 0.08 (8%) | 50000 XOF |
| * (wildcard) | * | 0.10 (10%) | 0 XOF |
| _(+ 5 autres variantes de casse/degree)_ | | | |

> Note: doublons Licence/licence dans les rules → la résolution `fn_resolve_commission_rate` retourne le premier match.

### 4.4 Milestones (4)

| Seuil | Bonus | Label |
|-------|-------|-------|
| 5 | 5 000 XOF | Premier palier |
| 15 | 20 000 XOF | Palier Argent |
| 30 | 50 000 XOF | Palier Or |
| 50 | 100 000 XOF | Palier Diamant |

---

## 5. FLUX COMPLET (tel que conçu vs tel que fonctionnel)

### 5.1 Flux d'attribution d'un prospect

```
CONÇU:
  Étudiant visite ref_link (web) → Landing page capture ?ref=COMM-xxx
  → Stocke en SharedPreferences → Login/Signup → auth_wrapper appelle
  → app_register_referral_for_current_user → INSERT user_referrals

RÉALITÉ:
  - ✅ Fonctionne sur Flutter Web uniquement (Uri.base)
  - ❌ Ne fonctionne PAS sur Android/iOS natif (pas de deep link)
  - ❌ 1 seul referral en production sur 46 étudiants → système quasi-inopérant
```

### 5.2 Flux de génération de commission

```
CONÇU (2 chemins en parallèle):

CHEMIN A (trigger):
  Admin confirme paiement → UPDATE application_payments status='confirmed'
  → Trigger AFTER UPDATE → app_on_payment_confirmed_generate_referral_commission
  → app_generate_referral_commission_for_payment
  → Vérifie: paiement confirmed, amount > 0, reason IN (registration_fee, tuition_deposit)
  → Vérifie: student a un referral, commercial actif, fenêtre 12 mois, pas de doublon (par paire)
  → INSERT referral_commissions (taux = commercial_profiles.commission_rate / 100)

CHEMIN B (inline dans app_admin_confirm_payment):
  → Même trigger mais AUSSI code inline dans la fonction
  → Pas de filtre payment_reason
  → Utilise fn_resolve_commission_rate (taux des rules, en fraction)
  → Utilise fn_check_commission_cap (taux du profil, en pourcentage — UNITÉS INCOMPATIBLES)
  → LEAST(fraction, pourcentage) = toujours la fraction → cap ignoré
  → INSERT referral_commissions (taux = fraction brute, pas de /100)

RÉSULTAT:
  - Pour le 1er paiement d'un étudiant référé: chemin A crée la commission, chemin B skip
  - Pour les paiements suivants: chemin A skip (doublon paire), chemin B crée
  - Le cap dégressif ne fonctionne JAMAIS (BUG unités)
  - Le 1er paiement utilise le taux du profil, les suivants le taux des rules → incohérence
```

### 5.3 Flux admin (onglet Commerciaux)

```
CONÇU:
  Admin voit liste des commerciaux avec code, lien, stats
  → Peut modifier taux, cap, suspendre, voir détail, partager lien

RÉALITÉ:
  - ✅ Liste des commerciaux fonctionne (filtre role='commercial')
  - ❌ ref_code et ref_link toujours vides (BUG 1)
  - ❌ Boutons Copier/Partager inopérants (lien vide)
  - ✅ Stats agrégées (students_count, commissions) fonctionnent via overview
  - ✅ Modifier taux commission fonctionne
  - ✅ Suspendre/réactiver fonctionne
  - ✅ Détail commercial fonctionne
  - ✅ Milestone claims section fonctionne
```

---

## 6. RECOMMANDATIONS DE CORRECTION (par priorité)

### P0 — Critique (à corriger immédiatement)

1. **Unifier les unités de taux**: Choisir UNE convention (recommandation: fraction partout, 0.05 = 5%). Migrer `commercial_profiles.commission_rate` de pourcentage à fraction, ou adapter toutes les fonctions.

2. **Supprimer le double chemin commission**: Désactiver le trigger `trg_app_application_payments_referral_commission` et garder uniquement le chemin inline dans `app_admin_confirm_payment` (plus riche). Adapter le chemin inline pour diviser par 100 si on garde l'unité pourcentage.

3. **Corriger ref_code/ref_link dans l'écran admin**: Fusionner les données de `commercialsOverview` dans l'affichage de chaque commercial. Le `overviewItem` a déjà ces champs.

4. **Implémenter la capture de referral sur mobile**: Soit deep links, soit saisie manuelle du code à l'inscription.

### P1 — Important

5. **Renommer `total_confirmed_payments`** → `total_commissions_count` et aligner le calcul (COUNT(*) ou COUNT(DISTINCT student_id) selon le besoin).

6. **Unifier les domaines Netlify** dans les ref_links existants. Mettre à jour tous les profils avec le domaine actuel.

7. **Nettoyer les doublons de casse** dans `commission_rules` (Licence vs licence, etc.).

### P2 — Améliorations

8. **Ajouter `application_fee` et `td_access`** aux raisons éligibles dans `app_generate_referral_commission_for_payment` (ou supprimer cette fonction si le chemin inline est conservé).

9. **Ajouter un mécanisme de vérification** : un commercial devrait pouvoir vérifier si un étudiant est bien rattaché à son code (actuellement seul l'admin peut voir via `app_admin_get_commercial_detail`).

---

## 7. RÉSUMÉ EXÉCUTIF

| Aspect | État |
|--------|------|
| Tables Supabase | ✅ Structurées, 7 tables, cohérentes |
| RPCs | ⚠️ 24 fonctions mais 2 chemins conflictuels |
| Triggers | ⚠️ 7 triggers actifs, double génération commission |
| RLS Policies | ✅ Correctes (admin + own) |
| Données | ⚠️ Quasi-vides (0 commissions, 1 referral sur 46 étudiants) |
| Dashboard commercial Flutter | ✅ Fonctionnel (mais données vides) |
| Admin commerciaux Flutter | ❌ ref_code/ref_link invisibles |
| Capture referral | ❌ Ne fonctionne pas sur mobile |
| Génération commission | ❌ Double chemin + unités incompatibles |
| Cap dégressif | ❌ Non-fonctionnel (unités) |
| Compteur prospects | ⚠️ Techniquement correct mais inutile (capture cassée) |

**Verdict**: Le système est bien architecturé mais **inopérant en production** à cause de 4 bugs critiques. Le plus impactant est l'absence de capture de referral sur mobile, suivi par l'incohérence d'unités qui rend le cap dégressif non-fonctionnel. La correction de ces 4 bugs P0 devrait rendre le système pleinement opérationnel.
