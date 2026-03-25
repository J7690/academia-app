# Plan d'implémentation — Refonte Marketplace (v2)
# Module "Opportunités" → Marketplace Multi-Vendeurs Amazon/Alibaba
# Date: 14 mars 2026

---

## VISION GLOBALE

L'onglet "Opportunités" devient un **marketplace multi-vendeurs** style Amazon (présentation) + Alibaba (mécanisme B2B : devis, MOQ, négociation). Tout concept emploi/stage est supprimé.

**2 rôles principaux :**
- **Vendeur (merchant)** : publie des produits/services, gère ses commandes, répond aux demandes
- **Acheteur (student)** : browse, ajoute au panier, commande, laisse des avis, envoie des demandes de devis

**Admin** : contrôle total (validation, vérification vendeurs, modération, commissions, KPIs)

**Paiement** : prévu dans le schéma dès le départ (tables, colonnes, FK), implémenté dans une phase ultérieure. Mécanisme escrow avec prélèvement de commission plateforme.

---

## SCHÉMA GLOBAL CIBLE (toutes phases confondues)

Ce schéma est la référence pour CHAQUE phase. Aucune implémentation ne doit diverger de ce schéma.

### Tables CONSERVÉES et RENFORCÉES

```
app.marketplace_listings          — Table centrale produit/annonce
app.marketplace_listing_media     — Photos + vidéos par produit (carousel)
app.marketplace_categories        — Catégories et sous-catégories
app.marketplace_listing_bookmarks — Favoris acheteur
app.marketplace_carts             — Paniers acheteur
app.marketplace_cart_items        — Items dans le panier
app.marketplace_orders            — Commandes
app.marketplace_order_items       — Items dans une commande
app.marketplace_merchants         — Profils vendeurs (table unique fusionnée)
app.opportunity_inquiries         — Demandes de devis (Alibaba-style)
app.opportunity_inquiry_messages  — Messages sur les demandes
```

### Tables À CRÉER

```
app.marketplace_reviews           — Avis acheteurs (lié à un achat vérifié)
app.marketplace_payments          — Paiements avec commission (escrow)
app.marketplace_merchant_balances — Solde vendeur (pour versement)
```

### Tables À SUPPRIMER (après migration données)

```
app.opportunities                 — Absorbée par marketplace_listings
app.opportunity_applications      — Concept emploi supprimé
app.opportunity_types             — Remplacé par marketplace_categories
app.opportunity_reactions         — Rebranchées sur marketplace_listings
app.opportunity_comments          — Remplacées par marketplace_reviews
app.opportunity_bookmarks         — Remplacées par marketplace_listing_bookmarks
app.opportunity_views             — Compteur intégré dans marketplace_listings
app.marketplace_products          — Doublon avec marketplace_listings
app.merchant_profiles             — Fusionné dans marketplace_merchants
```

### Colonnes à AJOUTER sur marketplace_listings

```sql
cover_url           TEXT          -- Image de couverture principale
video_url           TEXT          -- Vidéo produit (Amazon-style)
rating_avg          NUMERIC(2,1) DEFAULT 0  -- Note moyenne calculée
rating_count        INT DEFAULT 0           -- Nombre d'avis
sales_count         INT DEFAULT 0           -- Nombre de ventes
views_count         INT DEFAULT 0           -- Nombre de vues
reactions_count     INT DEFAULT 0           -- Likes
comments_count      INT DEFAULT 0           -- Commentaires (deprecated → reviews)
tags                TEXT[]                  -- Tags pour recherche full-text
specifications      JSONB                   -- Spécifications techniques
variants            JSONB                   -- Variantes (taille, couleur) avec prix
is_bookmarked       -- (calculé côté RPC, pas colonne)
```

### Colonnes marketplace_merchants (fusionné)

```sql
id                  UUID PK DEFAULT gen_random_uuid()
user_id             UUID FK → auth.users UNIQUE
business_name       TEXT NOT NULL
display_name        TEXT
description         TEXT
logo_url            TEXT
banner_url          TEXT
country             TEXT
city                TEXT
phone               TEXT
email               TEXT
is_verified         BOOLEAN DEFAULT FALSE
verification_level  TEXT DEFAULT 'none'  -- none, verified, gold, platinum
is_active           BOOLEAN DEFAULT TRUE
rating_avg          NUMERIC(2,1) DEFAULT 0
total_sales         INT DEFAULT 0
total_products      INT DEFAULT 0
created_at          TIMESTAMPTZ DEFAULT NOW()
updated_at          TIMESTAMPTZ DEFAULT NOW()
```

### Table marketplace_reviews

```sql
id                  UUID PK DEFAULT gen_random_uuid()
listing_id          UUID FK → marketplace_listings NOT NULL
buyer_id            UUID FK → auth.users NOT NULL
order_id            UUID FK → marketplace_orders  -- avis lié à un achat
rating              INT NOT NULL CHECK (rating BETWEEN 1 AND 5)
title               TEXT
content             TEXT
media_urls          TEXT[]  -- photos de l'avis
is_verified_purchase BOOLEAN DEFAULT FALSE
seller_reply        TEXT
seller_replied_at   TIMESTAMPTZ
is_active           BOOLEAN DEFAULT TRUE
created_at          TIMESTAMPTZ DEFAULT NOW()
updated_at          TIMESTAMPTZ DEFAULT NOW()
UNIQUE(listing_id, buyer_id, order_id)
```

### Table marketplace_payments (préparée, pas implémentée immédiatement)

```sql
id                  UUID PK DEFAULT gen_random_uuid()
order_id            UUID FK → marketplace_orders NOT NULL
buyer_id            UUID FK → auth.users NOT NULL
merchant_id         UUID FK → marketplace_merchants NOT NULL
gross_amount        NUMERIC NOT NULL        -- montant brut payé
commission_rate     NUMERIC NOT NULL        -- ex: 0.10 = 10%
commission_amount   NUMERIC NOT NULL        -- montant commission
net_amount          NUMERIC NOT NULL        -- = gross - commission
currency            TEXT DEFAULT 'XOF'
payment_method      TEXT                    -- mobile_money, card, bank_transfer
payment_provider    TEXT                    -- nom du provider
payment_provider_ref TEXT                   -- référence externe
status              TEXT DEFAULT 'pending'  -- pending, captured, released, refunded, failed
escrow_released_at  TIMESTAMPTZ
created_at          TIMESTAMPTZ DEFAULT NOW()
updated_at          TIMESTAMPTZ DEFAULT NOW()
```

### Table marketplace_merchant_balances (préparée)

```sql
id                  UUID PK DEFAULT gen_random_uuid()
merchant_id         UUID FK → marketplace_merchants UNIQUE
available_balance   NUMERIC DEFAULT 0       -- solde disponible
pending_balance     NUMERIC DEFAULT 0       -- en escrow
total_earned        NUMERIC DEFAULT 0       -- historique total
total_commission    NUMERIC DEFAULT 0       -- total prélevé
currency            TEXT DEFAULT 'XOF'
updated_at          TIMESTAMPTZ DEFAULT NOW()
```

---

## MODE OPÉRATOIRE (appliqué à CHAQUE phase)

### Protocole d'entrée de phase

```
┌─────────────────────────────────────────────────┐
│ ÉTAPE 1 — AUDIT FLUTTER                         │
│ • Cartographier les fichiers concernés          │
│ • Lister les RPCs appelées par le code Flutter  │
│ • Lister les providers/screens impactés         │
│ • Identifier le code mort à supprimer           │
│ • Vérifier 0 erreur de compilation              │
├─────────────────────────────────────────────────┤
│ ÉTAPE 2 — AUDIT SUPABASE                        │
│ • Via RPC-PY (.windsurf/supabase_auto_manager)  │
│ • Lister les tables concernées + colonnes       │
│ • Lister les RPCs existantes + signatures       │
│ • Vérifier les RLS policies                     │
│ • Vérifier les données existantes               │
│ • Consigner dans .windsurf/logs/                │
├─────────────────────────────────────────────────┤
│ ÉTAPE 3 — IMPLÉMENTATION                        │
│ • Supabase d'abord (migrations SQL)             │
│ • Vérification post-migration (audit SQL)       │
│ • Flutter ensuite (providers → screens)         │
│ • Build vérifié (0 erreur)                      │
├─────────────────────────────────────────────────┤
│ ÉTAPE 4 — BILAN DE PHASE                        │
│ • Résumé de ce qui a été fait                   │
│ • Ce qui reste / ce qui a changé                │
│ • Demander autorisation pour phase suivante     │
└─────────────────────────────────────────────────┘
```

### Règles impératives
1. **Aucune supposition** : si info manquante → audit Flutter + Supabase
2. **Pas de question pendant une phase** : terminer, puis bilan
3. **Schéma global comme référence** : chaque table/colonne/RPC créée doit être cohérente avec le schéma cible ci-dessus
4. **Paiement préparé** : les FK vers marketplace_payments sont créées même si la table n'est pas remplie
5. **Pas de code mort** : tout code supprimé est listé dans le bilan

---

## PHASES D'IMPLÉMENTATION

---

### PHASE 1 — Nettoyage & Consolidation Supabase
**Durée estimée : 2-3 jours**

#### Objectif
Unifier le schéma DB : une seule table produit, un seul profil vendeur, supprimer les doublons.

#### 1.1 — Audit Flutter
- Lister tous les providers qui appellent des RPCs `*opportunity*`
- Lister tous les providers qui appellent des RPCs `*marketplace*`
- Identifier les dépendances croisées (provider A utilise données de provider B)
- Lister le code mort (providers/méthodes jamais appelés dans le build)

#### 1.2 — Audit Supabase
- Lister toutes les tables `opportunity*` et `marketplace*` avec colonnes
- Lister toutes les RPCs `*opportunity*` et `*marketplace*` avec signatures
- Compter les données dans chaque table (pour migration)
- Vérifier les FK entre tables
- Exporter les données à migrer (opportunities → marketplace_listings)

#### 1.3 — Implémentation Supabase
- 1.3.1 — Fusionner `merchant_profiles` dans `marketplace_merchants` (ajouter colonnes manquantes)
- 1.3.2 — Ajouter colonnes manquantes sur `marketplace_listings` (cover_url, rating_avg, tags, specifications, variants, views_count, sales_count)
- 1.3.3 — Migrer les 3 opportunities existantes vers marketplace_listings (si pertinentes)
- 1.3.4 — Créer table `marketplace_reviews`
- 1.3.5 — Créer table `marketplace_payments` (structure uniquement, pas de RPCs paiement)
- 1.3.6 — Créer table `marketplace_merchant_balances` (structure uniquement)
- 1.3.7 — Rebrancher `opportunity_reactions` pour qu'elles pointent vers `marketplace_listings.id` (ou créer `marketplace_listing_reactions`)
- 1.3.8 — Créer index sur les colonnes de recherche/filtre

#### 1.4 — Bilan
- Tables créées/modifiées
- Données migrées
- Tables deprecated listées

---

### PHASE 2 — RPCs Manquantes Critiques
**Durée estimée : 2-3 jours**

#### Objectif
Créer toutes les RPCs manquantes pour que le panier, le checkout, les avis, et la vérification marchands fonctionnent.

#### 2.1 — Audit Flutter
- Lister TOUTES les RPCs appelées par TOUS les providers marketplace/opportunity
- Croiser avec les RPCs existantes en Supabase
- Produire la liste exacte des RPCs manquantes

#### 2.2 — Audit Supabase
- Vérifier les RPCs existantes (signatures, paramètres)
- Identifier les RPCs à modifier (rebrancher sur marketplace_listings au lieu de opportunities)
- Vérifier les RLS policies sur les nouvelles tables

#### 2.3 — Implémentation Supabase
- 2.3.1 — Créer les 6 RPCs panier :
  - `app_student_get_cart`
  - `app_student_cart_add_item(p_listing_id, p_quantity, p_variant)`
  - `app_student_cart_update_quantity(p_item_id, p_quantity)`
  - `app_student_cart_remove_item(p_item_id)`
  - `app_student_cart_clear`
  - `app_student_checkout_create_order_from_cart(p_shipping_address, p_notes)`
- 2.3.2 — Créer `app_admin_set_merchant_verification(p_merchant_id, p_level, p_is_verified)`
- 2.3.3 — Créer RPCs reviews :
  - `app_student_add_listing_review(p_listing_id, p_order_id, p_rating, p_title, p_content, p_media_urls)`
  - `app_student_list_listing_reviews(p_listing_id, p_limit, p_offset, p_sort)`
  - `app_merchant_reply_review(p_review_id, p_reply)`
  - `app_admin_moderate_review(p_review_id, p_is_active)`
- 2.3.4 — Réécrire les RPCs sociales pour cibler marketplace_listings :
  - `app_listing_toggle_reaction(p_listing_id, p_reaction_type)` (remplace app_opportunity_toggle_reaction)
  - `app_listing_get_reactions(p_listing_id)`
- 2.3.5 — Créer `app_student_get_listing_detail_v2(p_listing_id)` — retourne produit + médias + vendeur + avis + réactions en une seule requête
- 2.3.6 — RLS policies sur marketplace_reviews, marketplace_payments, marketplace_merchant_balances
- 2.3.7 — Triggers : update rating_avg/rating_count sur marketplace_listings après INSERT/UPDATE/DELETE sur marketplace_reviews

#### 2.4 — Bilan
- RPCs créées
- RPCs rebranchées
- Test d'appel de chaque RPC via script audit

---

### PHASE 3 — Nettoyage Flutter (Providers & Code Mort)
**Durée estimée : 1-2 jours**

#### Objectif
Supprimer tout le code mort lié aux opportunités emploi/stage. Rebrancher les providers existants sur les nouvelles RPCs.

#### 3.1 — Audit Flutter
- Cartographier chaque fichier `*opportunit*` dans lib/
- Pour chaque fichier : lister les méthodes, lesquelles sont appelées, lesquelles sont mortes
- Cartographier les imports croisés

#### 3.2 — Audit Supabase
- Vérifier que toutes les RPCs appelées par les providers restants existent
- Vérifier les signatures (paramètres Flutter vs paramètres Supabase)

#### 3.3 — Implémentation Flutter
- 3.3.1 — Supprimer `StudentOpportunitiesProvider` (plus utilisé)
- 3.3.2 — Supprimer `AdminOpportunitiesScreen` (fusionné dans marketplace admin)
- 3.3.3 — Nettoyer `student_opportunities_tab.dart` :
  - Supprimer `_applyToOpportunity()`
  - Supprimer `_contactMerchant()` (remplacé par inquiry via provider existant)
  - Supprimer `_buildProgressCard()`
  - Supprimer `_buildCareerTipCard()`
  - Supprimer les imports morts
- 3.3.4 — Rebrancher `OpportunityReactionsProvider` :
  - Renommer en `ListingReactionsProvider`
  - Appeler `app_listing_toggle_reaction` au lieu de `app_opportunity_toggle_reaction`
- 3.3.5 — Rebrancher `OpportunityCommentsProvider` :
  - Ce provider sera remplacé par un `ListingReviewsProvider` en Phase 5
  - Pour l'instant : désactiver les appels morts
- 3.3.6 — Supprimer les widgets orphelins dans `lib/widgets/opportunities/` qui ne sont plus utilisés
- 3.3.7 — Mettre à jour `main.dart` : retirer les providers supprimés, ajouter les nouveaux
- 3.3.8 — Build vérifié (0 erreur)

#### 3.4 — Bilan
- Fichiers supprimés
- Fichiers modifiés
- Providers renommés/rebranchés
- Build status

---

### PHASE 4 — Packages Flutter + Widget Card Produit Amazon-Style
**Durée estimée : 2-3 jours**

#### Objectif
Ajouter les packages UI modernes et créer le widget Card Produit avec carousel photo/vidéo.

#### 4.1 — Audit Flutter
- Vérifier les packages déjà dans pubspec.yaml (éviter doublons)
- Vérifier les versions minimales compatibles avec le SDK Flutter actuel
- Lister les widgets existants dans `lib/widgets/marketplace/` et `lib/widgets/opportunities/`

#### 4.2 — Audit Supabase
- Vérifier que la RPC `app_student_list_marketplace_listings` retourne bien cover_url, media_count, rating_avg, rating_count, merchant info
- Vérifier que `app_student_get_listing_detail_v2` retourne les médias triés

#### 4.3 — Implémentation Flutter
- 4.3.1 — Ajouter packages dans pubspec.yaml :
  ```yaml
  smooth_page_indicator: ^1.2.0
  flutter_staggered_grid_view: ^0.7.0
  photo_view: ^0.15.0
  readmore: ^3.0.0
  flutter_rating_bar: ^4.0.1
  ```
- 4.3.2 — Créer `lib/widgets/marketplace/marketplace_product_card.dart` :
  - Carousel PageView avec photos + vidéo du produit
  - SmoothPageIndicator (ExpandingDotsEffect)
  - Titre (maxLines: 2)
  - Rating stars + count
  - Prix (gras, vert) + devise
  - Méta Alibaba (MOQ, délai, prêt à expédier)
  - Bouton panier animé
  - Badge vendeur vérifié
  - Compteur réactions/avis
- 4.3.3 — Créer `lib/widgets/marketplace/marketplace_product_grid.dart` :
  - MasonryGridView.count (flutter_staggered_grid_view) — 2 colonnes
  - Shimmer loading skeleton
  - Infinite scroll
- 4.3.4 — Créer `lib/widgets/marketplace/marketplace_media_carousel.dart` :
  - PageView.builder pour photos + vidéo
  - Lecture auto vidéo muet (comme Amazon)
  - SmoothPageIndicator overlay
  - Gestion cached_network_image pour les photos
  - Gestion video_player pour les vidéos
- 4.3.5 — Créer `lib/widgets/marketplace/marketplace_seller_badge.dart` :
  - Badge vérifié / gold / platinum
  - Nom boutique + avatar
  - Note vendeur
- 4.3.6 — Build vérifié

#### 4.4 — Bilan
- Packages ajoutés
- Widgets créés
- Résolution de conflits de version si besoin

---

### PHASE 5 — Écran Principal Marketplace Étudiant
**Durée estimée : 3-4 jours**

#### Objectif
Refondre complètement `student_opportunities_tab.dart` en écran marketplace Amazon/Alibaba.

#### 5.1 — Audit Flutter
- Lire l'intégralité de student_opportunities_tab.dart
- Identifier ce qui est réutilisable vs à réécrire
- Vérifier la navigation (bottom nav, tabs, routes)

#### 5.2 — Audit Supabase
- Tester app_student_list_marketplace_listings avec différents filtres
- Vérifier les données retournées (cover_url, rating, merchant info)
- Tester app_list_marketplace_categories

#### 5.3 — Implémentation Flutter
- 5.3.1 — Refondre le layout principal :
  - Sticky search bar en haut
  - Chips catégories scrollables horizontaux
  - Bannière promo (PageView + SmoothPageIndicator)
  - Section "Meilleures ventes" (scroll horizontal)
  - Section "Nouveautés" (scroll horizontal)
  - Grille "Tous les produits" (MasonryGridView, infinite scroll)
- 5.3.2 — Implémenter la recherche :
  - TextField avec debounce 300ms
  - Appel RPC avec p_search
  - Résultats en temps réel
- 5.3.3 — Implémenter les filtres :
  - Bottom sheet avec : tri (prix, note, récent), catégorie, vérifiés, prêt à expédier, fourchette prix
  - Chips actifs affichés sous la search bar
- 5.3.4 — Bottom navigation bar :
  - [Accueil] [Catégories] [Panier 🔴] [Compte]
  - Badge panier avec compteur en temps réel
- 5.3.5 — Onglet Catégories :
  - Grid de catégories avec icônes
  - Sous-catégories en drill-down
- 5.3.6 — Onglet Compte :
  - Mes commandes
  - Mes demandes (inquiries)
  - Mes favoris
  - Mes avis
- 5.3.7 — Animations :
  - FadeInUp staggeré sur les cards (animate_do)
  - Shimmer skeleton pendant le chargement
  - Hero animation vers le détail produit
- 5.3.8 — Build vérifié

#### 5.4 — Bilan
- Écrans créés/refondus
- Navigation vérifiée
- Performance scroll vérifiée

---

### PHASE 6 — Écran Détail Produit
**Durée estimée : 2-3 jours**

#### Objectif
Créer l'écran détail produit style Amazon avec galerie, avis, vendeur, actions.

#### 6.1 — Audit Flutter
- Vérifier l'écran existant StudentMarketplaceProductDetailScreenV1
- Évaluer ce qui est réutilisable

#### 6.2 — Audit Supabase
- Tester app_student_get_listing_detail_v2 (ou app_student_get_marketplace_listing_detail)
- Vérifier que les médias, le vendeur, les avis sont retournés

#### 6.3 — Implémentation Flutter
- 6.3.1 — Galerie plein écran :
  - PageView avec photos + vidéo
  - photo_view pour zoom pinch
  - SmoothPageIndicator
  - Compteur "3/7"
- 6.3.2 — Section infos produit :
  - Titre complet
  - Rating stars + nombre d'avis (tappable → section avis)
  - Prix / fourchette prix / devise
  - Pills info : MOQ, délai livraison, prêt à expédier
  - Description avec readmore (3 lignes + "Voir plus")
  - Spécifications (table depuis JSONB)
  - Variantes (chips sélectionnables)
- 6.3.3 — Card vendeur :
  - Avatar + nom boutique + badge vérifié
  - Note vendeur + nb produits
  - Boutons : "Contacter" (inquiry) + "Voir boutique"
- 6.3.4 — Section avis :
  - 3 derniers avis avec rating, texte, date, photo
  - Bouton "Voir tous les avis"
  - Réponse vendeur affichée sous l'avis
- 6.3.5 — Sticky bottom bar :
  - [❤️ Favori] [🛒 Ajouter au panier] [💬 Demander un devis]
  - Animation ajout panier (fly-to-cart)
- 6.3.6 — Produits similaires (même catégorie/vendeur) — scroll horizontal en bas
- 6.3.7 — Build vérifié

#### 6.4 — Bilan

---

### PHASE 7 — Panier & Checkout
**Durée estimée : 2-3 jours**

#### Objectif
Panier fonctionnel avec checkout (sans paiement réel pour l'instant).

#### 7.1 — Audit Flutter
- Vérifier StudentMarketplaceCartProviderV1 et StudentMarketplaceCartScreenV1
- Vérifier les RPCs appelées

#### 7.2 — Audit Supabase
- Vérifier que les 6 RPCs panier créées en Phase 2 fonctionnent
- Tester le flux complet : add → update qty → checkout

#### 7.3 — Implémentation Flutter
- 7.3.1 — Rebrancher le provider panier sur les vraies RPCs
- 7.3.2 — Écran panier :
  - Liste items avec photo, titre, prix, quantité (+/-)
  - Bouton supprimer par item
  - Résumé : sous-total, frais estimés, total
  - Bouton "Commander"
- 7.3.3 — Écran checkout :
  - Résumé commande
  - Adresse de livraison
  - Notes
  - Bouton "Confirmer la commande"
  - (Futur : sélection mode de paiement)
- 7.3.4 — Écran confirmation commande
- 7.3.5 — Écran "Mes commandes" (liste + détail)
- 7.3.6 — Notifications vendeur (trigger existant)
- 7.3.7 — Build vérifié

#### 7.4 — Bilan

---

### PHASE 8 — Avis & Reviews
**Durée estimée : 1-2 jours**

#### Objectif
Système d'avis lié aux achats vérifiés.

#### 8.1 — Audit Flutter/Supabase
- Vérifier RPCs reviews créées en Phase 2
- Vérifier le trigger de mise à jour rating_avg

#### 8.2 — Implémentation
- 8.2.1 — `ListingReviewsProvider` (nouveau)
- 8.2.2 — Écran "Laisser un avis" (après réception commande)
  - flutter_rating_bar pour les étoiles
  - Titre + contenu
  - Upload photos de l'avis
- 8.2.3 — Liste des avis dans le détail produit
- 8.2.4 — Badge "Achat vérifié" ✓
- 8.2.5 — Réponse vendeur (côté merchant console)
- 8.2.6 — Build vérifié

#### 8.3 — Bilan

---

### PHASE 9 — Admin Marketplace Unifié
**Durée estimée : 2-3 jours**

#### Objectif
Un seul écran admin avec tabs, remplaçant les 2 écrans actuels (AdminOpportunitiesScreen + AdminMarketplaceControlTowerScreen).

#### 9.1 — Audit Flutter/Supabase
- Cartographier les 2 écrans admin existants
- Lister toutes les RPCs admin

#### 9.2 — Implémentation
- 9.2.1 — Écran admin unifié avec tabs :
  - [Dashboard] — KPIs (ventes, commissions, vendeurs, produits)
  - [Annonces] — Pending / Published / Rejected / All
  - [Vendeurs] — Liste avec vérification / suspension
  - [Commandes] — Toutes les commandes, statuts
  - [Avis] — Modération avis
  - [Catégories] — CRUD catégories/sous-catégories
- 9.2.2 — Supprimer AdminOpportunitiesScreen
- 9.2.3 — Supprimer les routes vers l'ancien écran
- 9.2.4 — Build vérifié

#### 9.3 — Bilan

---

### PHASE 10 — Console Commerçant Améliorée
**Durée estimée : 2-3 jours**

#### Objectif
Améliorer la console commerçant (déjà existante) pour le nouveau flux.

#### 10.1 — Audit Flutter/Supabase
- Cartographier merchant_marketplace_console_screen_v2.dart
- Lister les RPCs merchant

#### 10.2 — Implémentation
- 10.2.1 — Dashboard KPI vendeur (ventes, note, produits, commandes)
- 10.2.2 — CRUD annonces amélioré (upload photos/vidéos, variantes, spécifications)
- 10.2.3 — Gestion commandes (accepter, expédier, marquer livré)
- 10.2.4 — Inbox inquiries (répondre aux demandes)
- 10.2.5 — Réponse aux avis
- 10.2.6 — Build vérifié

#### 10.3 — Bilan

---

### PHASE 11 — Paiement & Commission (PRÉPARATION)
**Durée estimée : 2-3 jours**

#### Objectif
Préparer le mécanisme de paiement avec escrow et commission. Tables déjà créées en Phase 1. Ici on crée les RPCs et le flux backend.

#### 11.1 — Audit Supabase
- Vérifier marketplace_payments et marketplace_merchant_balances
- Vérifier commission_rules (table existante)

#### 11.2 — Implémentation Supabase
- 11.2.1 — RPC `app_process_marketplace_payment(p_order_id, p_payment_method, p_provider_ref)`
  - Calcule commission via fn_resolve_commission_rate
  - Crée entrée marketplace_payments
  - Met à jour marketplace_merchant_balances (pending_balance)
  - Met à jour marketplace_orders.status = 'paid'
- 11.2.2 — RPC `app_release_escrow(p_order_id)`
  - Transfère pending_balance → available_balance
  - Met à jour marketplace_payments.status = 'released'
- 11.2.3 — RPC `app_admin_list_marketplace_payments(p_status, p_limit, p_offset)`
- 11.2.4 — RPC `app_merchant_get_my_balance`
- 11.2.5 — Trigger : release auto escrow après X jours si pas de litige

#### 11.3 — Implémentation Flutter (UI préparée mais pas connectée au vrai provider paiement)
- 11.3.1 — Écran checkout avec sélection mode de paiement (placeholder)
- 11.3.2 — Écran admin tableau de bord financier
- 11.3.3 — Écran vendeur solde et historique

#### 11.4 — Bilan
- Le mécanisme est prêt, il ne manque que l'intégration du provider paiement (mobile money, etc.)

---

### PHASE 12 — Polish & Performance
**Durée estimée : 1-2 jours**

#### Objectif
Optimisations, animations, gestion d'erreurs, tests finaux.

#### 12.1 — Implémentation
- 12.1.1 — Optimiser les requêtes RPC (pagination, index)
- 12.1.2 — Préchargement images (precacheImage)
- 12.1.3 — Gestion d'erreurs réseau (retry, messages utilisateur)
- 12.1.4 — Animations de transition (Hero, page transitions)
- 12.1.5 — Responsive (petits/grands écrans)
- 12.1.6 — Supprimer définitivement les tables deprecated (opportunities, opportunity_applications, etc.)
- 12.1.7 — Build final vérifié

---

## RÉSUMÉ DES PACKAGES FLUTTER

| Package | Version | Statut | Rôle |
|---|---|---|---|
| cached_network_image | ^3.4.1 | ✅ Présent | Cache images produit |
| shimmer | ^3.0.0 | ✅ Présent | Loading skeleton |
| animate_do | ^4.2.0 | ✅ Présent | Animations entrée |
| video_player | ^2.10.1 | ✅ Présent | Vidéo produit |
| cached_video_player_plus | ^4.1.0 | ✅ Présent | Vidéo cache |
| share_plus | ^10.0.3 | ✅ Présent | Partage produit |
| file_picker | ^10.3.6 | ✅ Présent | Upload médias |
| smooth_page_indicator | ^1.2.0 | 🆕 Phase 4 | Dots carousel photos |
| flutter_staggered_grid_view | ^0.7.0 | 🆕 Phase 4 | Grille produits |
| photo_view | ^0.15.0 | 🆕 Phase 4 | Zoom galerie |
| readmore | ^3.0.0 | 🆕 Phase 4 | Description tronquée |
| flutter_rating_bar | ^4.0.1 | 🆕 Phase 4 | Étoiles notation |

---

## FICHIERS DE RÉFÉRENCE

- Audit Supabase : `.windsurf/logs/audit_opportunities_module.json`
- Script audit : `.windsurf/audit_opportunities_module.py`
- Script audit extra : `.windsurf/audit_opp_extra.py`
- Ancien plan (obsolète) : `docs/plan_marketplace_alibaba_like.md`
- **CE PLAN (actif)** : `docs/plan_marketplace_refonte_v2.md`

---

## CALENDRIER ESTIMÉ

| Phase | Durée | Cumul |
|---|---|---|
| Phase 1 — Nettoyage Supabase | 2-3j | 2-3j |
| Phase 2 — RPCs manquantes | 2-3j | 4-6j |
| Phase 3 — Nettoyage Flutter | 1-2j | 5-8j |
| Phase 4 — Packages + Card produit | 2-3j | 7-11j |
| Phase 5 — Écran principal marketplace | 3-4j | 10-15j |
| Phase 6 — Détail produit | 2-3j | 12-18j |
| Phase 7 — Panier & Checkout | 2-3j | 14-21j |
| Phase 8 — Avis & Reviews | 1-2j | 15-23j |
| Phase 9 — Admin unifié | 2-3j | 17-26j |
| Phase 10 — Console commerçant | 2-3j | 19-29j |
| Phase 11 — Paiement & Commission | 2-3j | 21-32j |
| Phase 12 — Polish & Performance | 1-2j | 22-34j |
