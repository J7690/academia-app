# Marketplace — État des lieux (5 octobre 2026)

Audit lecture seule : code Flutter + base de production `thevdfcwlcqzdoybfvgs` (catalogue PostgreSQL, comptages, corps des fonctions). Aucune modification effectuée.

## 1. Verdict

Le marketplace est **affichable mais pas transactionnel**. Un étudiant peut parcourir, mettre au panier et « commander », mais **aucun paiement n'est jamais déclenché**, le commerçant **ne peut pas faire avancer une commande**, donc **aucun avis ne peut être laissé** et **aucun revenu n'est versé**.

Preuve en base : 5 commandes (4 `pending`, 1 `confirmed`), **0 paiement**, 0 avis, 0 solde commerçant.

## 2. Ce qui est en base

### Tables (schéma `app`, toutes avec RLS activé)

| Table | Lignes | Remarque |
|---|---|---|
| marketplace_listings | 4 | toutes `published` / `approved` |
| marketplace_listing_media | 3 | |
| marketplace_categories | **0** | écran Catégories vide |
| marketplace_carts / cart_items | 39 / 5 | |
| marketplace_orders / order_items | 5 / 6 | dernière commande : 16/04/2026 |
| marketplace_payments | **0** | jamais créé (bug B1) |
| marketplace_reviews | 0 | impossible (bug B3) |
| marketplace_merchant_balances | 0 | |
| marketplace_merchants | 2 | NEXIOM SARL `approved`, R-Nexiom `pending` |
| merchant_profiles | 2 | |
| marketplace_products | 2 | ancien modèle, non utilisé par le code |
| opportunity_inquiries / messages | 2 / 1 | questions acheteur → vendeur |
| marketplace_listing_bookmarks | 1 | |

### Fonctions, triggers, cron, stockage

- **43/43 RPC appelées par le code existent dans `public`**, donc toutes sont accessibles par l'API. Aucun appel ne tombe dans le vide.
- Environ 60 RPC marketplace/opportunités existent en base sans être utilisées par le code. On y trouve l'ancien modèle `products`, `app_marketplace_release_escrow`, `app_merchant_get_my_balance`, `app_merchant_request_payout`, `app_admin_moderate_review` et `app_admin_list_marketplace_payments`.
- **Triggers** : notification admin à chaque nouvelle commande, audit des paiements, recalcul de la note d'une annonce après un avis, notification à chaque message d'une question.
- **Cron** : **aucun** job marketplace (pas de libération du séquestre).
- **Enum** `payment_reason` contient bien `marketplace_purchase`. `payment_channel` contient `ligdicash`.
- **Buckets** : `marketplace-media` existe (public) mais **le code envoie les images dans `landing-media`**.

## 3. Ce qui est dans le code

| Rôle | Point d'entrée | Écrans |
|---|---|---|
| Étudiant | `student_opportunities_tab.dart` | catalogue, fiche produit, panier, confirmation, mes commandes, détail, avis, favoris, questions, profil marchand |
| Commerçant | `auth_wrapper.dart:344` → `MerchantDashboardScreenV2` → `MerchantMarketplaceConsoleScreenV2` (1 495 lignes) | annonces, médias, soumission en validation, commandes, questions, avis, revenus |
| Admin | onglet `AdminMarketplaceControlTowerScreen` (`admin_dashboard_screen.dart:469`) | annonces en attente/publiées, médias, marchands (statut, vérification), commandes |

Fichiers **vides (0 ligne)**, vestiges : `admin_marketplace_screen.dart`, `merchant_dashboard_screen.dart`, `student_marketplace_tab.dart`, `student_marketplace_orders_screen.dart`, `admin_marketplace_provider.dart`, `merchant_marketplace_provider.dart`, `student_marketplace_provider.dart`.

## 4. Ce qui est fonctionnel, flux par flux

### Étudiant

| Étape | État |
|---|---|
| Parcourir / rechercher / fiche produit | OK |
| Catégories | Vide (0 catégorie en base) |
| Favoris | OK |
| Panier (ajout, quantité, suppression) | OK |
| Commander | Crée la commande, **mais sans paiement** (B1) |
| Payer via LigdiCash | **Jamais affiché** (B1) |
| Suivre ses commandes | OK (lecture) |
| Laisser un avis | **Impossible** (B3) |
| Poser une question au vendeur | Données présentes (2 questions) — à tester en réel |

### Commerçant

| Étape | État |
|---|---|
| Créer / modifier une annonce, médias | OK (images dans `landing-media`) |
| Soumettre en validation | OK (`draft`/`rejected` → `pending_review`) |
| Voir ses commandes | OK |
| **Changer le statut d'une commande** | **Cassé** (B2) |
| Voir ses avis | **Cassé** (B4) |
| Répondre aux questions | Probablement OK — à tester |
| Onglet « Mes revenus » | Toujours 0 (B5) |
| Comptes marchands | 4 utilisateurs `merchant`, 1 seul a les deux fiches (B6) |

### Admin

| Étape | État |
|---|---|
| Valider / rejeter une annonce | OK (`pending_review` → `published` ou `draft`) |
| Gérer les médias | OK |
| Statut / vérification marchand | OK, mais **sans effet** sur la visibilité des annonces (R-Nexiom `pending` a des annonces publiées) |
| Lister les commandes | OK |
| Voir les paiements marketplace | Pas d'écran (la RPC `app_admin_list_marketplace_payments` existe, non utilisée) |
| Modérer les avis | Pas d'écran (RPC `app_admin_moderate_review` non utilisée) |

## 5. Bugs bloquants (cause racine)

**B1 — Le checkout ne crée aucun paiement.**
`app_student_checkout_create_order_from_cart` insère les lignes `marketplace_orders` et `order_items`, mais jamais `marketplace_payments`. Il retourne `{order_id, merchant_id, total_amount, currency}` sans `marketplace_payment_id`. Or `student_marketplace_cart_screen_v1.dart:252-258` n'ouvre `LigdiCashPaymentSheet` que si ce champ est présent. La feuille de paiement n'est donc jamais affichée, et l'étudiant arrive directement sur « Commande confirmée ».

**B2 — Le commerçant ne peut pas changer le statut d'une commande.**
`app_merchant_update_marketplace_order_status` filtre `WHERE merchant_id = auth.uid()`. Mais `marketplace_orders.merchant_id` contient `marketplace_merchants.id` (ex. `b5f6…`), pas l'identifiant utilisateur (`489b…`). La fonction répond donc toujours `order_not_found`. Les fonctions de lecture (`list_my_orders`, `get_order_detail`) font correctement la traduction via `owner_user_id`. De plus, aucune transition n'est contrôlée : n'importe quelle chaîne est acceptée comme statut.

**B3 — Avis impossibles.**
`app_student_add_listing_review` exige une commande au statut `delivered` ou `completed`. Avec B1 et B2, aucune commande n'atteint jamais ces statuts.

**B4 — Clés marchand incohérentes entre tables.**
- `marketplace_listings.merchant_id` contient l'**id utilisateur** (upsert, submit et checkout comparent à `auth.uid()` / `owner_user_id`).
- `marketplace_orders.merchant_id` contient l'**id de `marketplace_merchants`**.
- `app_merchant_list_my_reviews` fait la jointure `mm.id = l.merchant_id`, ce qui mélange les deux : aucun avis ne remonterait même s'il en existait.
- `app_get_public_merchant_profile` lit `merchant_profiles.user_id`, alors que la fiche produit transmet un `merchant_id` : à vérifier selon l'identifiant passé.

**B5 — Deux systèmes de soldes, et le séquestre n'est jamais libéré.**
- Une fois le paiement confirmé, `app_confirm_ligdicash_payment` (branche `marketplace`) met le paiement en `captured`, passe la commande en `paid`, écrit `escrow_hold` au grand livre et applique la répartition `marketplace_purchase` (vers `actor_balances`).
- `app_marketplace_release_escrow` crédite, lui, `marketplace_merchant_balances`. Il n'est appelé par **aucun code et aucun cron**.
- L'onglet « Mes revenus » lit `marketplace_merchant_balances` (0 ligne).

Il faut choisir **un seul** circuit, sous peine de double crédit ou de solde toujours vide.

**B6 — Comptes marchands incomplets.**
Sur les 4 utilisateurs `role=merchant` :
- 1 seul a `marketplace_merchants` et `merchant_profiles` ;
- 1 n'a que `marketplace_merchants`, 1 n'a que `merchant_profiles` ;
- 1 (créé le 02/06/2026) n'a **aucune** fiche : il ne peut pas voir ses commandes (`v_merchant_id IS NULL`).

Le checkout crée par ailleurs à la volée des lignes `marketplace_merchants` en `pending`.

## 6. Sécurité

**S1 — `landing-media` est modifiable par tous.** Ce bucket a les politiques `landing_media_write` (ALL), plus INSERT, UPDATE et DELETE pour tout utilisateur `authenticated`, sans aucune condition sur le propriétaire. N'importe quel étudiant connecté peut donc supprimer ou remplacer les médias de la landing page et ceux des annonces. Les images marchandes devraient aller dans `marketplace-media`, sous un préfixe `<user_id>/`.

## 7. Corrections appliquées (5 octobre 2026)

Migration `supabase/migrations/20261005150000_marketplace_paiement_statuts.sql`, déployée en production.

- **B4 — convention retenue** : `listings.merchant_id` = id utilisateur ; `orders/payments/balances.merchant_id` = `marketplace_merchants.id` (imposé par les FK). `app_merchant_list_my_reviews` et `app_merchant_reply_review` sont corrigées.
- **B1** :
  - le checkout crée un `marketplace_payments` (`pending`, commission prise dans la règle `marketplace_purchase`, soit 10 %) et renvoie `marketplace_payment_id` ;
  - nouvelle RPC `app_student_ensure_marketplace_payment` ;
  - bouton « Payer maintenant » sur le détail d'une commande `pending` ;
  - le détail commande renvoie aussi `payment`.
- **B2** : filtre marchand corrigé. Transitions autorisées : `pending→cancelled`, `paid|confirmed→accepted`, `accepted→shipped`, `shipped→delivered`. Les transitions interdites sont refusées (`invalid_transition`). La console marchand ne propose que les transitions autorisées, avec des libellés en français.
- **B3** : débloqué dès qu'une commande est `delivered`.

Reste ouvert :
- **B5** : la confirmation LigdiCash crédite déjà 90 % au marchand dans `actor_balances`, versés automatiquement, donc avant la livraison. Le séquestre n'est pas effectif.
- Annulation d'une commande payée et remboursement.
- Passage `delivered→completed` par l'étudiant.
- **B6**, **S1**.

## 8. Ordre de correction recommandé

1. **Unifier la clé marchand** (B4) : choisir `user_id` partout, ou `marketplace_merchants.id` partout, puis corriger les RPC concernées.
2. **B2** : corriger le filtre et ajouter une machine à états (`paid` → `processing` → `shipped` → `delivered` → `completed`, plus `cancelled`).
3. **B1** : le checkout crée `marketplace_payments` (montant brut, taux de commission, montant net) et retourne `marketplace_payment_id`. Tester ensuite `ligdicash-initiate`/`confirm` en mode test.
4. **B5** : choisir le circuit des soldes. Brancher la libération du séquestre sur `delivered`/`completed` (ou sur un délai via cron) et aligner l'onglet « Mes revenus ».
5. **B6** : régulariser les comptes et garantir les deux fiches à la création (`admin-create-merchant-compte`).
6. **S1** : restreindre `landing-media` et basculer les uploads marchands vers `marketplace-media`.
7. Confort : semer `marketplace_categories`, écrans admin paiements et modération des avis, supprimer les 7 fichiers vides.
