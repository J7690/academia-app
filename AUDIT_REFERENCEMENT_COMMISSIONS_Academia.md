# Audit du système de référencement & commissions — Academia / Nexium Group

**Date :** 13 juillet 2026
**Périmètre :** rôles commercial + admin, comptabilisation des prospects, attribution, commissions, redirection Play Store, et préparation des rôles « créateur de contenu / influenceur ».
**Base auditée :** dépôt `academia` (Flutter + Supabase, projet `thevdfcwlcqzdoybfvgs`), docs internes, scripts `.windsurf`, **+ vérification directe de la base de production** (13 juillet, connecteur Supabase en lecture).

---

## 0. Vérification directe en production (13 juillet) — faits confirmés

Contrairement à un audit sur code seul, les points ci-dessous ont été **vérifiés dans la vraie base** :

| Vérification | Résultat réel |
|--------------|---------------|
| Contrainte `UNIQUE (student_id)` sur `user_referrals` | ✅ **Présente** — le correctif anti-doublon est appliqué en prod |
| `app_commercial_get_dashboard` en `COUNT(DISTINCT student_id)` | ✅ **Oui** — corrigé |
| Ancien trigger `trg_app_application_payments_referral_commission` | ✅ **Désactivé** (`D`) — plus de double chemin par trigger |
| Tables `referral_tokens`, `commission_share_config`, `share_tracking` | ✅ **Présentes** |
| Colonnes owner/promoter/platform sur `referral_commissions` + `students.commercial_owner_id` | ✅ **Présentes** |
| Chemin de commission réellement appelé par l'app | ⚠️ **`app_admin_confirm_payment` (version SANS partage)** — la version `_with_share` existe mais **n'est pas branchée** |
| Scénario de partage actif | `first_click_100` → **100 % owner, 0 % promoteur, 0 % plateforme** |
| Migrations versionnées de tout le domaine commercial | ❌ **Aucune** — l'historique de migration s'arrête au 06/04/2026 ; tout le schéma commercial a été appliqué hors migration |
| Données réelles | 8 commerciaux · 3 referrals (sur 96 étudiants) · **0 commission** · 0 token · 0 partage · 3 étudiants avec owner |

**Lecture d'ensemble :** le schéma cible de votre vision est **déjà déployé en base**, mais il n'a **jamais servi** (0 commission, 0 token, 0 partage) et **n'est pas branché** dans l'app (chemin sans partage, scénario 100 % owner). C'est une fondation présente mais dormante et non finie.

---

## 1. Verdict en une page

Le système commercial est **bien architecturé sur le papier mais fragile en réalité**, pour trois raisons :

1. **La comptabilisation des prospects a été corrigée en base, mais reste non verrouillée en amont.** Le correctif anti-doublon (`UNIQUE (student_id)` + `COUNT(DISTINCT)`) est **bien appliqué en production** (vérifié §0). Le zéro-comptage mobile, lui, dépend d'un déploiement Play Store **non fait**. Et surtout **le schéma n'est pas versionné** (voir §6).
2. **Votre vision multi-commerciaux existe déjà… mais dormante et non branchée.** Les tables `commission_share_config`, `share_tracking`, la notion `owner` + `promoter` + `platform` sont **déployées en base**. Mais l'app appelle encore le chemin de commission **sans partage**, le scénario actif est **100 % owner**, aucune commission n'a jamais été générée, et le rôle « créateur de contenu » n'existe nulle part.
3. **Faille de sécurité critique :** la clé `service_role` Supabase (accès admin total, contourne toute sécurité RLS) est écrite **en clair dans plus de 50 scripts** suivis par git.

**Ce qui marche :** structure des tables, dashboard commercial, RLS de lecture, grille de commissions configurable, redirection Netlify `/ref/*` en place.

**Ce qui ne marche pas / n'est pas fiable :** garantie anti-doublon en base non confirmée, attribution mobile fragile, deux systèmes d'attribution parallèles non réconciliés, aucune traçabilité versionnée du schéma réel, rôle créateur absent.

---

## 2. Ce qui existe réellement (cartographie)

### 2.1 Tables (schéma `app`)

| Table | Rôle | Remarque |
|-------|------|----------|
| `commercial_profiles` | Profil commercial : `ref_code`, `ref_link`, `commission_rate`, `tier`, `max_commissions_per_prospect` | 7 commerciaux, tous `bronze` |
| `user_referrals` | Attribution prospect → commercial | **1 seule ligne** sur 46 étudiants |
| `referral_commissions` | Commissions générées | **0 ligne** (jamais déclenché en vrai) |
| `commission_rules` | Grille de taux configurable | 13 règles (avec doublons de casse) |
| `commercial_milestones` / `_claims` | Bonus de paliers (5/15/30/50) | claims = 0 |
| `referral_tokens` | Tokens d'installation Play Store | créée le 9 juil. via script, **hors migrations** |
| `commission_share_config` | Scénarios de partage owner/promoteur/plateforme | créée le 9 juil., **hors migrations** |
| `share_tracking` | Traçabilité des partages tous canaux | créée le 9 juil., **hors migrations** |
| `students.commercial_owner_id` | Propriétaire permanent du prospect | colonne ajoutée le 9 juil., **hors migrations** |

### 2.2 Edge functions & redirection

- `referral-redirect` : reçoit `/ref/REF_CODE`, génère un token 128 bits, l'enregistre dans `referral_tokens`, puis **redirige en HTTP 302 vers le Play Store** avec `?referrer=TOKEN`. C'est exactement le mécanisme que vous décrivez (lien commercial → Play Store).
- `netlify.toml` : la redirection `/ref/* → …/functions/v1/referral-redirect/ref/:splat` **est bien en place**.

### 2.3 Côté application (Flutter)

- `install_referrer_service.dart` : lit l'Install Referrer du Play Store au premier lancement et résout le token → commercial (package `installreferrer: ^2.0.1`).
- `auth_wrapper.dart` : rattache le parrainage après login (Priorité 1 = Install Referrer, Priorité 2 = paramètres URL).
- `share_tracking_service.dart` : génère les liens et enregistre les partages.
- Boutons de partage multi-canaux (WhatsApp, Facebook, Instagram, X, LinkedIn, Telegram, Email, SMS).

---

## 3. Faille n°1 — Comptabilisation des prospects

### 3.1 Double-comptage

**Cause racine confirmée** (audit du 9 juillet, requêtes SQL réelles) :

- `app_commercial_get_dashboard` comptait les prospects avec `COUNT(*)` sur `user_referrals` au lieu de `COUNT(DISTINCT student_id)`.
- La table `user_referrals` **n'a aucune contrainte `UNIQUE`** sur `student_id` : seuls la PK (`id`) et les clés étrangères existent. Rien n'empêche, en base, d'insérer plusieurs lignes pour le même étudiant.
- Côté app, `_attachReferralIfNeeded()` est appelé dans `build()` (potentiellement plusieurs fois) ; seul un flag mémoire `_referralHandledForSession` protège, réinitialisé à chaque changement d'auth. Aucune protection réseau/retry.

> Conséquence : le rempart contre le doublon est purement applicatif et fragile. Une race condition ou un rebuild peut créer des doublons que `COUNT(*)` gonfle ensuite.

**Correctif existant :** `fix_double_comptage_prospects.sql` ajoute `UNIQUE (student_id)`, passe le dashboard en `COUNT(DISTINCT student_id)`, et réécrit `app_register_referral_for_current_user` avec `INSERT … ON CONFLICT (student_id) DO NOTHING`.
**⚠️ Non vérifié en production** — ce script est un fichier local, pas une migration appliquée et tracée.

### 3.2 Zéro-comptage

**Cause racine confirmée :**

- Sur mobile natif, `Uri.base` ne renvoie pas l'URL du lien cliqué → la capture web ne fonctionne pas.
- `AndroidManifest.xml` **ne contient aucun intent-filter App Links / deep link**.
- Le champ « Code de parrainage » à l'inscription est **optionnel** : si le prospect ne le saisit pas, rien n'est enregistré.
- Résultat mesuré : **1 seul referral pour 46 étudiants** → système quasi inopérant.

**Correctif en cours :** la chaîne Install Referrer (lien `/ref/CODE` → Netlify → edge function → token → Play Store → `installreferrer` → résolution) répond précisément à ce problème et **est codée**. Mais elle dépend de deux prérequis **non faits** : DNS/HTTPS du domaine public et build + soumission Play Store d'une version embarquant le package. Tant que ce n'est pas déployé et testé sur device réel, le zéro-comptage persiste sur mobile.

---

## 4. Faille n°2 — Génération des commissions

Historiquement (audit du 15 mars), **deux chemins concurrents** généraient les commissions (inline dans `app_admin_confirm_payment` + trigger `app_generate_referral_commission_for_payment`), avec des **unités de taux incompatibles** (fractions `0.12` vs pourcentages `5.0`), rendant le **cap dégressif totalement contourné**. Les docs indiquent que ces points ont été corrigés (trigger désactivé, unités unifiées en fraction, index unique `(commercial_user_id, payment_id)`).

**Limites actuelles :**

- `referral_commissions` est **vide** : aucune commission n'a jamais été réellement générée en production. Les corrections n'ont donc **jamais été validées sur données réelles**.
- La cohérence du compteur `total_confirmed_payments` (mal nommé, mélange `COUNT(*)` et `COUNT(DISTINCT)`) reste un point de dette.

---

## 5. État de votre vision cible

### 5.1 Lien commercial → Play Store → création de compte ✅ (codé, ⏳ à déployer)

Le mécanisme que vous décrivez (« le lien envoie sur le Play Store, et si l'app est déjà installée on continue ») est **implémenté** via Install Referrer + fallback deep link. **Reste à faire :** DNS + HTTPS du domaine, build AAB avec le package, test sur téléphone réel, soumission Play Store. Sans ces étapes, ça ne fonctionne pas encore pour un vrai utilisateur.

### 5.2 Multi-attribution : commercial A (inscription) + commercial B (souscription) ⚠️ (prototype non unifié)

C'est le point le plus important, et **vous avez déjà une base solide** :

- **Propriétaire (owner)** = commercial par qui le prospect est arrivé : `students.commercial_owner_id`.
- **Promoteur (promoter)** = commercial dont la pub a déclenché la souscription : tracé via `share_tracking` + colonnes `owner_commercial_id` / `promoter_commercial_id` sur `referral_commissions`.
- **Répartition configurable** : `commission_share_config` (owner % / promoter % / platform %), avec un scénario par défaut `first_click_100` (100 % owner). Vous pourrez passer à 80/20 sans refonte.
- **Cas « pub Nexium sans commercial »** : le champ `source` de `share_tracking` peut porter cette origine (partage direct plateforme, sans promoteur) → 100 % plateforme.

**Écarts à combler :**

1. **Deux systèmes d'attribution non réconciliés.** Le nouveau chemin owner passe par Install Referrer (`referral_tokens`), pendant que le tracking promoteur passe par l'ancien `?promo=CODE` / `captureFromUrl()` qui **ne marche que si l'app est déjà installée**. Il faut une **source de vérité unique** pour l'attribution.
2. **RPC de commission avec partage non branchée par défaut.** `app_admin_confirm_payment_with_share` et `…_for_payment_with_share` existent, mais rien n'indique qu'elles remplacent le chemin actuel. Tant qu'elles ne sont pas le chemin unique, les commissions partagées ne se déclencheront pas.
3. **Fenêtre d'attribution du promoteur non définie.** Combien de temps le clic sur la pub de B reste-t-il valable pour lui attribuer la souscription ? À trancher (règle métier).
4. **Aucune donnée réelle** n'a validé le partage (`referral_commissions` = 0).

### 5.3 Rôle « créateur de contenu / influenceur » ❌ (inexistant)

Recherche exhaustive : **aucune trace** de `creator`, `influencer`, `content_creator` dans Supabase ni dans l'app. C'est un développement **entièrement neuf**. Pour supporter votre règle « le créateur du visuel touche aussi une commission quand le visuel vend », il faudra au minimum :

- un **rôle** `content_creator` (profil + auth) ;
- une **bibliothèque de visuels** (`content_assets`) reliée à son créateur ;
- un lien **visuel → partage** : quand un commercial partage/publie un visuel, `share_tracking` doit stocker `content_asset_id` (et donc le créateur) en plus du promoteur ;
- une **3ᵉ part** dans `commission_share_config` : owner % / promoter % / **creator %** / platform % ;
- l'extension de la table des commissions pour porter `creator_commercial_id` + `creator_commission_amount`.

La bonne nouvelle : `share_tracking` a déjà un champ `item_type` et une logique multi-canal — c'est le bon point d'ancrage pour rattacher le visuel et son créateur.

---

## 6. Failles transverses (les plus dangereuses)

### 6.1 🔴 CRITIQUE — Clé `service_role` exposée dans le dépôt

La clé `service_role` (accès admin total, **contourne toute la sécurité RLS**) est écrite **en clair dans plus de 50 fichiers** `.windsurf/*.py` (83 occurrences). Le `.gitignore` n'exclut que `__pycache__` et les `.env` — **pas les scripts `.py`**. Ces fichiers sont donc **versionnés dans git**.

**Impact :** quiconque accède au dépôt (ou à son historique) obtient un contrôle total de la base : lecture/écriture de toutes les données étudiants, paiements, commissions, suppression, etc.

**Actions immédiates :**
1. **Révoquer et régénérer** la clé `service_role` dans Supabase (Settings → API) **aujourd'hui**.
2. Purger la clé de l'historique git (`git filter-repo` / BFG) ou considérer le repo comme compromis.
3. Déplacer tous les secrets vers `.windsurf/.env` (déjà ignoré) et charger via variables d'environnement.
4. Ajouter `.windsurf/*.py` contenant des secrets au `.gitignore`, ou mieux, sortir ces scripts du repo.

### 6.2 🔴 CRITIQUE — Dérive de schéma (schema drift), pas de migrations versionnées

Toutes les évolutions commerciales majeures (referral_tokens, commission_share_config, share_tracking, `commercial_owner_id`, les RPC de partage, les correctifs de comptage) ont été **appliquées directement en production via `admin_execute_sql`**, dans des scripts Python locaux. **Aucune n'existe dans `supabase/migrations/`** (qui ne contient que des migrations vidéo/contenu/whiteboard).

**Impact :**
- La structure réelle de la base **n'est nulle part dans le code** : impossible de reconstruire l'environnement, de faire une revue, ou de savoir ce qui est réellement déployé.
- On ne peut pas confirmer, sans interroger la base, si `fix_double_comptage_prospects.sql` ou les RPC de partage sont **réellement actifs**.

**Confirmé en prod :** l'historique de migration Supabase s'arrête au **6 avril 2026** et ne contient **aucune** des évolutions commerciales (referral_tokens, share_config, share_tracking, colonnes owner/promoter, correctifs de comptage). Tout a été appliqué hors migration.

**Action :** rapatrier l'état réel de la base dans des migrations versionnées (`supabase db pull`), puis n'appliquer **plus aucun** changement de schéma hors migration.

### 6.4 🟠 Backlog de sécurité Supabase (advisors)

L'analyseur de sécurité Supabase remonte, en plus de la fuite de clé : **~11 erreurs** dont des **tables du schéma `public` sans RLS** (`rls_disabled_in_public`) — donc exposées via l'API — et un très grand nombre de **fonctions `SECURITY DEFINER` sans `search_path` fixe** (`function_search_path_mutable`), vecteur classique d'élévation de privilèges, d'autant plus critique combiné au RPC `admin_execute_sql`. À traiter dans un chantier de durcissement dédié.

### 6.3 🟠 Existence d'un RPC générique `admin_execute_sql`

Un RPC permettant d'exécuter du SQL arbitraire existe et est exploité par les scripts. Combiné à la fuite de clé, c'est un vecteur d'attaque majeur. À restreindre fortement (ou supprimer) une fois les migrations en place.

---

## 7. Recommandations priorisées

### P0 — À faire cette semaine (sécurité & fondations)

1. **Révoquer/régénérer la clé `service_role`** et purger le dépôt (§6.1).
2. **Rapatrier le schéma réel en migrations versionnées** (`supabase db pull`) et geler les modifs hors migration (§6.2).
3. **Confirmer en base** que le correctif anti-doublon est appliqué : contrainte `UNIQUE (student_id)` + dashboard en `COUNT(DISTINCT)` + `ON CONFLICT`. Sinon, l'appliquer proprement en migration.

### P1 — Fiabiliser la comptabilisation & finir le Play Store

4. Rendre le rattachement idempotent **côté base** (déjà prévu) et déplacer l'appel hors de `build()`.
5. Configurer **DNS + HTTPS** du domaine public, builder l'AAB avec `installreferrer`, **tester sur device réel**, soumettre au Play Store.
6. Générer **au moins une vraie commission** en environnement de test pour valider le calcul (la table est vide → 0 validation réelle à ce jour).

### P2 — Unifier la multi-attribution (votre vision)

7. Choisir **une source de vérité unique** d'attribution :
   - **owner** figé à la création du compte (via Install Referrer) dans `students.commercial_owner_id` ;
   - **promoter** = dernier commercial dont le lien/visuel a été utilisé dans une **fenêtre d'attribution** à définir (ex. 7–30 j), tracé dans `share_tracking`.
8. Faire des RPC `…_with_share` le **chemin unique** de confirmation de paiement, et retirer l'ancien.
9. Définir les **règles métier** : fenêtre promoteur, cas « owner = promoter » (un seul commercial → 100 %), cas « pas de promoteur » (100 % owner), cas « ni owner ni promoteur, pub Nexium directe » (100 % plateforme).

### P3 — Rôle créateur de contenu

10. Créer le rôle `content_creator`, la table `content_assets` (visuel → créateur), rattacher `content_asset_id` à `share_tracking`, ajouter une **part créateur** dans `commission_share_config` et sur la table des commissions.

---

## 8. Modèle d'attribution cible (proposé)

Répartition d'une commission sur une souscription, résolue dans l'ordre :

| Scénario | Owner (A) | Promoteur (B) | Créateur du visuel | Plateforme |
|----------|-----------|---------------|--------------------|------------|
| A amène le prospect **et** vend | 100 % | — | — | — |
| A amène, B vend via sa pub | ex. 70 % | ex. 20 % | — | ex. 10 % |
| A amène, B vend via un visuel du créateur C | ex. 60 % | ex. 20 % | ex. 10 % | ex. 10 % |
| Pub Nexium directe (pas de commercial), visuel de C | — | — | ex. 15 % | reste |
| Pub Nexium directe, aucun visuel identifié | — | — | — | 100 % |

*(Pourcentages illustratifs, à fixer dans `commission_share_config` — l'architecture les rend configurables sans refonte.)*

---

## 9. Points vérifiés en base (réponses confirmées)

Les questions ouvertes de la version précédente ont été **tranchées directement en production** :

1. **Anti-doublon actif ?** ✅ Oui — `UNIQUE (student_id)` présente + dashboard en `COUNT(DISTINCT)`.
2. **Quel chemin de commission est branché ?** ⚠️ `app_admin_confirm_payment` **sans partage**. `app_admin_confirm_payment_with_share` existe mais n'est **pas appelée** par l'app. (Note : un commentaire dans `admin_payments_provider.dart` indique que les paiements seraient confirmés via l'edge function `ligdicash-callback` — à réconcilier, car `admin_application_payments_provider.dart` appelle bien la RPC. Il existe donc une ambiguïté sur le vrai chemin de confirmation à clarifier.)
3. **Scénario de partage actif ?** `first_click_100` (100 % owner). L'infrastructure de split existe mais n'est pas configurée pour partager.
4. **RPC de partage utilisées ?** Non — présentes en base, jamais exercées (0 partage, 0 commission).

---

## 10. Prochaine étape possible

Avec l'accès Supabase désormais disponible, je peux, si vous le souhaitez :

- générer les **migrations versionnées** correspondant à l'état réel de la base (résorber le schema drift, §6.2) ;
- écrire la **spécification technique** complète du modèle multi-attribution + créateur de contenu (tables, RPC, règles) ;
- produire un **diagramme de flux** de l'attribution cible (owner / promoteur / créateur / plateforme).

Dites-moi lequel de ces livrables vous voulez en premier.

---

*Fin du rapport.*
