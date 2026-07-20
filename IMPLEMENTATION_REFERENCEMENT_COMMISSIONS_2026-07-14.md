# Implémentation — Référencement multi-acteurs & commissions partagées

**Date :** 14 juillet 2026
**Statut :** appliqué en production (schéma + logique), validé par test simulé (rollback). Reste : build app + config Play Store.

---

## Ce qui a été construit

### 1. Un registre de commission unique et cohérent
`referral_commissions` devient **le** registre des commissions commerciales (dashboard commercial, paliers, validation admin). Fini les deux chemins incohérents : `app_admin_confirm_payment` (confirmation manuelle) **et** `app_confirm_ligdicash_payment` (mobile money, le vrai chemin de production) appellent désormais **la même** fonction : `app_generate_commission_split_for_payment`.

Cette fonction conserve la philosophie existante — taux résolu par la grille `commission_rules` + cap dégressif par prospect — et applique **par-dessus** la répartition entre acteurs.

### 2. Double crédit corrigé
Avant, un commercial était crédité **deux fois** sur un paiement : une ligne `referral_commissions` **et** un crédit `actor_balances` (règle `commercial` de `revenue_split_rules`), avec des taux différents. Le bénéficiaire `commercial` de `revenue_split_rules` a été **désactivé** : le commercial n'est plus crédité que via `referral_commissions`. `actor_balances` continue de gérer plateforme / université / instructeur / marchand. *(Réversible : réactiver la règle rétablit l'ancien comportement.)*

### 3. Attribution multi-commerciaux (votre vision)
Pour chaque paiement, la fonction résout :

- **Owner** = commercial par qui le prospect est arrivé (`user_referrals` / `students.commercial_owner_id`), figé, fenêtre 12 mois conservée.
- **Promoteur** = commercial dont le lien/la pub a déclenché la souscription (`share_tracking`), dans une **fenêtre configurable** (défaut 30 j).
- **Créateur** = propriétaire du visuel utilisé dans la pub (`content_assets` → `share_tracking`).
- **Plateforme** = le reste (et 100 % si arrivée directe Nexium, sans commercial).

Une **ligne de commission distincte par bénéficiaire** est créée (chaque acteur voit donc sa part dans son propre dashboard). Cas gérés : promoteur = owner (parts fusionnées), owner hors fenêtre (part → plateforme), aucun commercial (100 % plateforme).

### 4. Répartition 100 % pilotée par l'admin
Aucun pourcentage n'est codé en dur. L'admin définit les scénarios dans l'écran **Configuration Partage Commissions** : Owner % / Promoteur % / Créateur % / Plateforme % (total = 100) + fenêtre promoteur. Un seul scénario actif à la fois, activable en un clic. Scénario actif actuel : **`first_click_100`** (100 % owner) → **rien ne change** tant que vous n'activez pas un partage.

### 5. Rôle créateur de contenu (plomberie posée)
- Table `content_assets` : bibliothèque de visuels rattachés à leur créateur, avec approbation admin et RLS (créateur voit les siens, commercial voit les approuvés).
- RPC : `app_creator_upsert_content_asset`, `app_list_content_assets`, `app_admin_approve_content_asset`.
- Quand un visuel est partagé (`?asset=<id>` dans le lien), le créateur est référencé et touche sa part à la vente.

### 6. Comptage des prospects verrouillé
Confirmé en base : contrainte `UNIQUE (student_id)` active, dashboard en `COUNT(DISTINCT)`, rattachement idempotent (`ON CONFLICT`). L'index unique `(payment_id, commercial_user_id, beneficiary_role)` empêche tout double-comptage de commission.

### 7. Play Store
La chaîne lien `/ref/CODE` → redirection Netlify → edge function `referral-redirect` → token → Play Store (Install Referrer) est en place et branchée. **Reste côté ops** (hors code) : DNS/HTTPS du domaine `academiea.com`, build AAB, test sur device, soumission.

---

## Validation

Test simulé complet **puis annulé (rollback)** sur un paiement réel, scénario 70/20/10 :
commission totale 5,00 → **owner 3,50 · promoteur 1,00 · créateur 0,50 · plateforme 0**, en 3 lignes distinctes. 2ᵉ appel = 0 ligne (idempotence). Aucune donnée de test persistée.

---

## Fichiers

**Base (migrations versées, appliquées en prod)**
`supabase/migrations/20260714000106_referral_multiactor_schema.sql` + README listant les 5 migrations.

**Flutter**
- `lib/providers/admin_commission_share_config_provider.dart` — modèle + upsert avec créateur % et fenêtre.
- `lib/features/admin/admin_commission_share_config_screen.dart` — champs créateur % / fenêtre, total sur 4 parts.
- `lib/services/share_tracking_service.dart` — capture du visuel (`asset`) → créateur.

---

## À faire ensuite (hors de ce lot)

1. **Sécurité (urgent)** : révoquer la clé `service_role` exposée dans 50+ scripts `.windsurf` versionnés par git (cf. rapport d'audit).
2. **Ops Play Store** : DNS/HTTPS + build + soumission.
3. **Créateur (activation)** : écrans dédiés (upload de visuels côté créateur, galerie côté commercial) quand vous voudrez ouvrir le rôle.
4. **`supabase db pull`** pour finir de résorber la dérive de schéma historique.
