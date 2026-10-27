# Marketplace — Règles métier (référence)

Version du 6 octobre 2026. Ce document est la source de vérité. La base de données l'applique dans `supabase/migrations/20261006090000_marketplace_sequestre_cycle_commande.sql` ; l'application Flutter ne fait qu'afficher les actions que le serveur autorise.

Modèle retenu : **place de marché à séquestre** (même logique que la protection acheteur de Jumia, Etsy ou AliExpress). La plateforme encaisse, conserve les fonds pendant l'exécution, puis verse le vendeur ou rembourse l'acheteur.

## 1. Cycle de vie d'une commande

| Statut | Signification | Qui le déclenche |
|---|---|---|
| `pending` | Commande créée, en attente de paiement | Étudiant (checkout) |
| `paid` | Paiement confirmé par LigdiCash, fonds en séquestre | Système |
| `accepted` | Le vendeur s'engage à exécuter | Marchand |
| `shipped` | Remis au transporteur ou prêt à être retiré | Marchand |
| `delivered` | Le vendeur déclare la livraison effectuée | Marchand |
| `completed` | Réception confirmée, fonds versés au vendeur | Étudiant ou système |
| `disputed` | Réclamation ouverte, fonds gelés | Étudiant |
| `cancelled` | Annulée avant expédition, remboursement intégral si elle était payée | Étudiant, marchand, admin ou système |
| `refunded` | Litige tranché en faveur de l'acheteur | Admin |

Transitions autorisées :

- `pending` → `paid` (système), `cancelled` (étudiant, marchand, système)
- `paid` → `accepted` (marchand), `cancelled` (étudiant, marchand, admin, système)
- `accepted` → `shipped` (marchand), `cancelled` (marchand, admin, système)
- `shipped` → `delivered` (marchand), `completed` (étudiant), `disputed` (étudiant)
- `delivered` → `completed` (étudiant, système), `disputed` (étudiant)
- `disputed` → `completed` ou `refunded` (admin)
- `confirmed` (statut historique) → `accepted` (marchand)

Les autres transitions sont refusées par le serveur (`invalid_transition`). Chaque changement est journalisé dans `marketplace_order_events` : ancien statut, nouveau statut, auteur, rôle, motif, date.

## 2. Délais de service (contrôlés toutes les 15 minutes)

| Règle | Délai | Conséquence automatique |
|---|---|---|
| Paiement | 24 h après la commande | Annulation (« paiement non reçu ») |
| Acceptation par le vendeur | 48 h après le paiement (rappel à 24 h) | Annulation et remboursement intégral |
| Expédition | 5 jours après l'acceptation | Annulation et remboursement intégral |
| Protection acheteur | 72 h après `delivered` | Validation automatique et versement au vendeur |
| Réclamation « non reçu » | Possible 7 jours après `shipped` | — |

## 3. Argent

- **Encaissement** : le paiement LigdiCash est mis en séquestre (`captured`). Le vendeur ne reçoit rien à ce stade.
- **Commission plateforme** : le taux de la règle `marketplace_purchase` (10 % aujourd'hui), figé sur le paiement au moment de la commande.
- **Versement** au passage à `completed` :
  - le montant net (brut moins commission) est crédité au marchand ;
  - le versement LigdiCash est mis en file automatiquement (cron toutes les 15 min), vers `payout_phone`, à défaut `contact_phone` ;
  - le paiement passe à `released`.
- **Remboursement** (annulation d'une commande payée, ou litige perdu par le vendeur) :
  - 100 % du montant payé ;
  - versé sur le numéro qui a payé, via la même file de versements ;
  - le paiement passe à `refunded`. La plateforme ne prélève aucune commission.
- **Paiement tardif** : si un paiement arrive sur une commande déjà annulée, il est encaissé puis remboursé immédiatement.
- **Grand livre** (`platform_ledger`) : `escrow_hold`, `escrow_release`, `revenue_split`, `commission`, `escrow_refund`.

## 4. Annulation

- **Étudiant** : sans justification tant que la commande n'est pas acceptée (`pending`, `paid`).
- **Marchand** : jusqu'à l'expédition (`paid`, `accepted`), avec un motif obligatoire, que l'étudiant voit.
- **Admin** : à tout moment avant `completed`, avec un motif obligatoire.
- **Après expédition** : uniquement via une réclamation.

## 5. Réclamation (litige)

- **Quand** : dans les 72 h suivant `delivered`, ou 7 jours après `shipped` si rien n'est arrivé.
- **Motif** : obligatoire (10 caractères minimum).
- **Effet** : fonds gelés, validation automatique suspendue, vendeur et admins notifiés.
- **Décision de l'admin** :
  - « Rembourser » : `refunded`, l'acheteur est remboursé à 100 % ;
  - « Libérer » : `completed`, le vendeur est versé.

  La décision est motivée et notifiée aux deux parties.

## 6. Notifications

| Événement | Étudiant | Marchand | Admin |
|---|---|---|---|
| Annonce soumise | | | ✅ |
| Annonce validée ou rejetée (avec motif) | | ✅ | |
| Nouvelle question sur une annonce | | ✅ | |
| Message dans une conversation | ✅ | ✅ | |
| Commande payée | ✅ | ✅ (à accepter sous 48 h) | ✅ |
| Rappel d'acceptation (24 h) | | ✅ | |
| Acceptée, expédiée, livrée | ✅ | | |
| Validée, fonds versés | ✅ (invitation à laisser un avis) | ✅ (montant net) | |
| Annulée | ✅ (motif et remboursement) | ✅ | |
| Réclamation ouverte | | ✅ | ✅ |
| Litige tranché | ✅ | ✅ | |
| Nouvel avis | | ✅ | |

Domaines push : `student_marketplace`, `merchant_marketplace`, `admin_marketplace`. Le titre et le texte sont rédigés côté serveur (`push_title`, `push_body`). Un clic ouvre « Mes commandes », la console marchand ou la tour de contrôle admin.

## 7. Avis

Un avis par article et par commande, possible à partir de `delivered`. Le marchand peut répondre publiquement une fois.

## 8. Hors périmètre de cette version

- Vérification du marchand obligatoire pour vendre : à activer après la régularisation des comptes marchands (B6).
- Retours après réception (droit de rétractation) : à traiter par réclamation.
- Remboursement partiel.
