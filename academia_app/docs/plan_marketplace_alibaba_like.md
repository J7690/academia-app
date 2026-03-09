---
description: Plan d’implémentation Marketplace Alibaba-like (Admin contrôle total + rôle Commerçant)
---

# Plan d’implémentation — Marketplace Alibaba-like (Academia)

## Objectif
Mettre en place une expérience inspirée d’Alibaba pour l’onglet Opportunités, avec :
- un **rôle Commerçant (seller)**,
- une **console Commerçant** (publication, gestion annonces, réponse aux demandes),
- une **console Admin** (contrôle total, validation avant publication, vérification des commerçants, modération),
- un **parcours Étudiant/Acheteur** centré sur **la découverte + la demande (inquiry/contact)** (plutôt qu’un checkout obligatoire).

> Contrainte majeure (validée) : **l’admin doit valider avant toute publication**.

---

## Principes “Alibaba” à reproduire (adaptés à Academia)
- **Conversion = Contact / Inquiry** : l’action principale n’est pas “acheter”, c’est **contacter** et négocier.
- **Confiance visible** : badges type **Vérifié / Gold / Trade Assurance** (chez nous : Verified/Gold + règles de conformité internes).
- **Scannabilité** : cards très lisibles (image, prix/"à partir", lieu, badges, CTA).
- **Recherche + filtres puissants** : type, prix, lieu, “ready-to-ship”, “verified”.
- **Admin Control Tower** : validation, feature, blocage, modération, audit.

---

## Rôles & responsabilités
### Rôles auth
- `admin`
  - contrôle total (CRUD global),
  - valide/rejette publications,
  - vérifie commerçants,
  - modère listings/inquiries,
  - accède à toutes les stats.
- `merchant` (Commerçant)
  - crée/édite **ses** annonces,
  - soumet pour validation,
  - répond aux inquiries **qui le concernent**,
  - ne publie pas directement.
- `student`
  - browse les annonces publiées,
  - envoie inquiries,
  - pour `job` : postule (optionnel, si on conserve candidature).

### Workflow publication (obligatoire)
1) Merchant crée une annonce en `draft`
2) Merchant soumet → `pending_review`
3) Admin :
   - accepte → `published`
   - refuse → `rejected` (avec motif)
   - archive/désactive si nécessaire

---

## Architecture data recommandée (adaptée au contexte)
On **garde** le modèle “Opportunités” comme table pivot (simple, compatible, déjà en prod) et on l’étend.

### Table pivot
- `app.opportunities`
  - continue à porter `type in (job, service, product)`
  - conserve `status`, `is_active`, `is_featured`
  - garde les compteurs sociaux (reactions/comments/bookmarks/views)

### Extensions indispensables
#### 1) Commerçants
- `app.merchant_profiles`
  - `user_id` (PK)
  - `display_name`
  - `logo_url`
  - `bio`
  - `city`, `country`
  - `is_verified` (bool)
  - `verification_level` (enum text: `none|gold|verified`)
  - `is_active`
  - `created_at`, `updated_at`

#### 2) Lien annonce → commerçant
- ajouter `merchant_id` (UUID) sur `app.opportunities`
  - `merchant_id` = `auth.uid()` du seller

#### 3) Inquiries (Request for quotation / Contact supplier)
- `app.opportunity_inquiries`
  - `id`
  - `opportunity_id`
  - `buyer_id`
  - `merchant_id`
  - `message`
  - `quantity` (nullable)
  - `budget` (nullable)
  - `status` (`open|replied|closed`)
  - `created_at`, `last_message_at`

#### 4) Messages (option recommandé)
- soit réutiliser le système DM existant (si adapté)
- soit créer un mini thread :
  - `app.opportunity_inquiry_messages(inquiry_id, sender_id, content, created_at)`

#### 5) Champs Alibaba-like (progressifs)
Sur `app.opportunities` (surtout pour `product/service`) :
- `price_from`, `price_to`, `currency`
- `min_order_qty` (MOQ)
- `lead_time_days`
- `is_ready_to_ship`
- `dispatch_time_days` (option)

#### 6) Média
- si pas déjà couvert : `app.opportunity_media(opportunity_id, storage_path/url, sort_order)`

---

## Sécurité (RLS) — invariants
- Les **lectures publiques** (étudiant) : uniquement `published AND is_active=true`.
- Le **merchant** :
  - CRUD uniquement sur ses opportunités (`merchant_id = auth.uid()`)
  - ne peut pas passer à `published` (uniquement via RPC admin)
  - lecture/écriture uniquement sur ses inquiries
- L’**admin** :
  - accès global via RPC `SECURITY DEFINER` + check du rôle.

---

# Phases d’implémentation

## Phase 1 — Fondations DB (tables + colonnes + index) (2–3 jours)
### Objectifs
- Introduire `merchant_profiles`
- Relier opportunités ↔ merchants
- Créer `opportunity_inquiries` (+ messages si retenu)
- Ajouter champs Alibaba-like minimum

### Livrables
- Migration SQL `.windsurf/sql_changes/phase_marketplace_01_foundations.sql`
- Audit `.windsurf/audit_marketplace_01_foundations.py`

### Critères d’acceptation
- Tables existent + indexes
- Contraintes FK OK

---

## Phase 2 — RLS + RPC (Admin validation & Merchant console-ready) (2–4 jours)
### Objectifs
- RLS complète
- RPC admin/merchant/buyer
- Workflow `draft → pending_review → published/rejected`

### RPC minimales
#### Merchant
- `app_merchant_upsert_opportunity(...)`
- `app_merchant_submit_opportunity_for_review(p_opportunity_id)`
- `app_merchant_list_my_opportunities(p_status, p_limit, p_offset)`
- `app_merchant_list_my_inquiries(...)`
- `app_merchant_reply_inquiry(...)`

#### Admin
- `app_admin_list_pending_opportunities(...)`
- `app_admin_review_opportunity(p_opportunity_id, p_decision, p_reason)`
- `app_admin_set_merchant_verification(p_merchant_id, p_level, p_is_verified)`
- `app_admin_list_all_inquiries(...)`

#### Buyer (student)
- `app_student_list_opportunities(...)` (enrichie: merchant badge + ready_to_ship + moq)
- `app_student_create_inquiry(p_opportunity_id, p_message, p_quantity, p_budget)`
- `app_student_list_my_inquiries()`

### Livrables
- Migration SQL `.windsurf/sql_changes/phase_marketplace_02_rpcs_rls.sql`
- Audit `.windsurf/audit_marketplace_02_rpcs_rls.py`

### Critères d’acceptation
- Un merchant ne peut pas publier
- Un admin peut publier/rejeter
- Un buyer ne voit que `published`

---

## Phase 3 — Console Admin “Control Tower” (Flutter) (3–5 jours)
### Objectifs
- Admin contrôle total
- Validation des annonces
- Gestion commerçants (verify, suspend)
- Modération inquiries

### Écrans
- `Admin Marketplace > Annonces` (Pending/Published/Rejected)
- `Admin Marketplace > Commerçants`
- `Admin Marketplace > Inquiries`

### Critères d’acceptation
- Workflow complet admin fonctionnel
- Audit rapide (stats: nb pending, nb published, merchants verified)

---

## Phase 4 — Interface Commerçant (Flutter) (4–7 jours)
### Objectifs
- Dashboard seller
- CRUD annonces + upload médias
- Soumission validation
- Inbox inquiries + réponses

### Écrans
- `Merchant Dashboard` (KPIs)
- `Mes annonces` (draft/pending/published/rejected)
- `Créer/éditer annonce`
- `Inquiries Inbox`

### Critères d’acceptation
- Seller peut créer et soumettre
- Seller voit retours admin
- Seller répond aux demandes

---

## Phase 5 — UI Étudiant/Acheteur (Alibaba browsing) (3–6 jours)
### Objectifs
- Cards “Alibaba-like”
- Recherche + filtres
- Détail annonce + seller card
- CTA sticky: `Contacter` (product/service) / `Postuler` (job)

### Patterns UI à intégrer
- Badges: `Nouveau`, `À la une`, `Vérifié`, `Ready to ship`
- “À partir de …” (prix)
- MOQ (si product)

---

## Phase 6 — Migration & Rollout (1–3 jours)
### Objectifs
- Migration douce: continuer à afficher opportunités existantes
- Backfill `merchant_id` pour anciennes annonces (admin owner) si nécessaire
- Feature flag `merchant_marketplace_enabled`

### Stratégie
- Lancement progressif:
  1) Admin only
  2) Merchants (petit groupe)
  3) Étudiants (tous)

---

## Phase 7 — Confiance & protection (post-MVP)
- Système de “vérification” détaillé
- Historique conformité / sanction
- Templates de réponse
- Anti-spam inquiries
- (Option) Paiement/commande si besoin (non requis pour Alibaba-like MVP)

---

# Notes d’implémentation (priorités)
- Priorité 1 : **workflow validation admin** + **inquiry** (cœur Alibaba).
- Priorité 2 : **console merchant** + **cards scannables**.
- Priorité 3 : badges trust + filtres avancés.

---

# Fichiers de référence
- SQL existant opportunités : `.windsurf/supabase_opportunities.sql`
- Extensions sociales : `.windsurf/sql_changes/phase1_opportunities_social.sql`
- Favoris : `.windsurf/sql_changes/phase2_opportunities_bookmarks.sql`
- Badges new: `.windsurf/sql_changes/phase6_opportunities_notifications.sql`

