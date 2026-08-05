# Audit — le manager, ses commerciaux, et le suivi des gains

**Date :** 4 août 2026
**Compte :** `nassiroumaiga@outlook.com` — Nassirou Maiga — rôle `manager` — 3 commerciaux rattachés
**Nature :** lecture seule. Aucune modification.

> Ce rapport remplace ma conclusion précédente sur les notifications. Vous aviez
> raison : je n'avais pas trouvé le vrai problème. Le voici.

---

## 0. Le vrai problème, en une phrase

**Le manager ne peut pas suivre les gains de ses commerciaux, parce qu'aucun gain n'est jamais créé.**
18 paiements confirmés, tous rattachés à un commercial parrain, et **zéro commission en base**. Ce n'est pas un retard d'affichage : c'est structurel, et aucun paiement futur n'en produira non plus en l'état.

---

## 1. Requalification de mon constat précédent

Vous m'avez expliqué que vous utilisez beaucoup de comptes pour tester les rôles. Cela change la lecture du partage de jetons d'appareil : sur **vos** téléphones de test, un même appareil enregistré sous plusieurs comptes est normal et attendu.

Ce qui reste à vérifier, et seulement cela : les jetons partagés entre des **personnes réelles distinctes**. Le téléphone de Nassirou porte une inscription active pour `wendenkoote@gmail.com` (admin) et `kayadejule@gmail.com` (commercial). Si ce sont vos propres comptes de test, il n'y a rien à corriger. **Si `kayadejule@gmail.com` est un commercial réel, alors un commercial reçoit les notifications d'administration** — et là il faut agir.

Le défaut technique demeure (la déconnexion ne désenregistre jamais l'appareil, `app_unregister_device_token` n'est appelée nulle part), mais je le repositionne : **gêne de test, pas incident**, tant que les comptes concernés sont les vôtres.

---

## 2. La chaîne des gains, et où elle est rompue

### Ce qui devrait se passer

```
Commercial parraine un étudiant   → app.user_referrals            ✅ 9 lignes
Étudiant paie                     → app.application_payments      ✅ 18 confirmés
Paiement confirmé                 → commission générée            ❌ 0 ligne
Commission                        → solde du commercial           ❌ 0 ligne
Solde                             → file de reversement           ❌ 0 ligne
Manager                           → voit les gains de son équipe  ❌ affiche 0
```

### Rupture n° 1 — le montant payé n'est jamais enregistré

`app_confirm_ligdicash_payment` confirme le paiement mais **n'écrit pas `amount_paid`** :

```sql
UPDATE app.application_payments SET
  status = 'confirmed', payment_method = 'ligdicash_otp',
  ligdicash_token = ..., ligdicash_transaction_id = ..., ligdicash_operator = ...,
  confirmed_at = NOW(), confirmed_by = NULL, updated_at = NOW()
WHERE id = p_payment_id;          -- ← amount_paid absent
```

Or **les deux** générateurs de commission commencent par :

```sql
IF v_payment.amount_paid IS NULL OR v_payment.amount_paid <= 0 THEN
    RETURN ... 'no_amount_paid';
```

La preuve dans les données — les six paiements `application_fee` passés par LigdiCash :

| Motif | Confirmé le | `amount_due` | `amount_paid` |
|---|---|---|---|
| application_fee | 07/07/2026 | 10.00 | **NULL** |
| application_fee | 07/07/2026 | 10.00 | **NULL** |
| application_fee | 29/05/2026 | 10.00 | **NULL** |
| application_fee | 29/05/2026 | 10.00 | **NULL** |
| application_fee | 27/05/2026 | 100.00 | **NULL** |
| application_fee | 17/04/2026 | 100.00 | **NULL** |

Le générateur est appelé, lit `amount_paid = NULL`, et abandonne silencieusement. **À chaque fois.**

Ceux qui portent un `amount_paid` sont soit des achats de crédits confirmés après le correctif de mi-juillet, soit d'anciens paiements validés **à la main** par un administrateur.

### Rupture n° 2 — deux motifs de paiement sur cinq seulement sont éligibles

Le générateur historique filtre en plus :

```sql
IF v_payment.payment_reason NOT IN ('registration_fee', 'tuition_deposit') THEN
    RETURN ... 'payment_reason_not_eligible';
```

Confronté au parc réel :

| Motif | Confirmés | Éligible ? |
|---|---|---|
| `application_fee` | 8 | ❌ |
| `credit_purchase` | 7 | ❌ |
| `registration_fee` | 1 | ✅ |
| `tuition_deposit` | 1 | ✅ |
| `td_access` | 1 | ❌ |

**16 paiements sur 18 sont écartés par ce seul filtre.** Et les 2 éligibles datent du 30 décembre 2025 — soit **avant** l'installation du dispositif de commissions (migrations du 14 juillet 2026). Ils n'ont donc jamais été traités.

### Rupture n° 3 — l'achat de crédits ne déclenche rien

`app_confirm_credit_purchase` écrit bien `amount_paid`… mais **n'appelle aucun générateur de commission**. Et `credit_purchase` est de toute façon exclu par le filtre de motifs.

C'est la ligne de revenu la plus active aujourd'hui — 7 des 18 paiements, et les 3 plus récents. **Elle ne rémunère aucun commercial.**

### Conséquence

Aucun des chemins automatiques de paiement ne peut produire une commission :

| Chemin | `amount_paid` écrit ? | Générateur appelé ? | Motif éligible ? | Commission |
|---|---|---|---|---|
| `app_confirm_ligdicash_payment` (frais, TD, abonnement) | ❌ | ✅ | ❌ pour la plupart | **jamais** |
| `app_confirm_credit_purchase` (crédits) | ✅ | ❌ | ❌ | **jamais** |
| `app_admin_confirm_payment` (validation manuelle) | à vérifier | ✅ | selon le motif | rare |

Les tables `referral_commissions`, `actor_balances` et `payout_queue` sont **toutes les trois vides**. Le déclencheur `fn_update_commercial_tier`, qui calcule le palier du commercial, se nourrit de `referral_commissions` : les paliers ne bougent donc jamais non plus.

---

## 3. Défauts propres à l'espace manager

### 3.1 — Un manager désactivé continue de voir les finances de son équipe

`app.app_manager_team_stats` :

```sql
IF NOT v_is_admin AND NOT app.is_manager() THEN ... forbidden
```

Elle utilise **`is_manager()`** — le simple rôle — alors que **toutes** les fonctions d'écriture utilisent `can_manager_act()`, qui vérifie en plus :

```sql
app.is_manager()
  AND manager_profiles.is_active
  AND NOT (user_admin_status.is_suspended OR is_deleted)
```

Autrement dit : on peut **désactiver** ou **suspendre** un manager — il ne pourra plus créer de commercial ni publier d'annonce, mais il continuera de consulter le chiffre d'affaires, les commissions et les effectifs de son ancienne équipe. **Le droit de lecture financière survit à la révocation.**

### 3.2 — Le montant des « gains » affiché serait faux

```sql
'commissions', (SELECT coalesce(sum(rc.commission_amount),0)
                FROM app.referral_commissions rc
                WHERE rc.commercial_user_id = cp.user_id)
```

Deux problèmes, invisibles aujourd'hui parce que la table est vide, mais qui apparaîtront dès la première commission :

- **Aucun filtre sur `status`.** Une commission `pending`, voire rejetée, serait comptée comme un gain acquis. Le manager annoncerait à son commercial de l'argent qui n'existe pas.
- **La colonne sommée est l'ancienne.** Le dispositif unifié écrit désormais dans `owner_commission_amount`, `promoter_commission_amount`, `creator_commission_amount` et `platform_commission_amount`. Sommer `commission_amount` ignore ce partage : le manager verra un chiffre qui ne correspondra ni à ce que touche le commercial, ni à ce que verse la plateforme.

### 3.3 — Le manager n'est jamais notifié de l'activité de son équipe

C'est précisément ce que vous décrivez comme son métier — suivre la prospection et les gains — et **rien ne l'en informe** :

| Événement | Notifié à |
|---|---|
| Un prospect déclare un paiement | le commercial seul |
| Le paiement du prospect est confirmé | le commercial seul |
| Une commission est créée | le commercial seul |
| Un commercial de l'équipe est créé | **les administrateurs**, pas le manager |

Les trois déclencheurs (`app_notify_commercial_prospect_payment`, `app_notify_commercial_payment_confirmed`, `app_notify_commercial_commission`) visent `commercial_user_id`. Aucun ne remonte au `manager_user_id`.

Et `app_manager_create_commercial` notifie **les admins** de la création — jamais le manager de sa propre équipe.

**Le manager ne reçoit donc rien de légitime.** C'est l'exacte inversion de ce que vous décrivez : il reçoit par accident ce qui ne le concerne pas (via le jeton d'appareil partagé), et rien de ce qui le concerne.

---

## 4. Ce qui est bien fait — à ne pas casser

- **Le rôle ne peut pas être usurpé.** Le déclencheur `trg_sync_role_from_app_metadata` réécrit à chaque UPDATE `raw_user_meta_data.role` depuis `raw_app_meta_data.role`, qui n'est pas modifiable par le client. Un utilisateur ne peut pas se déclarer manager.
- **Le périmètre d'équipe est juste** : `commercial_profiles.manager_user_id = auth.uid()`, sans fuite vers les autres équipes.
- **Les écritures sont bien gardées** par `can_manager_act()`.
- **Le rattachement à la création est correct** : un commercial créé par un manager lui est automatiquement rattaché.

Le modèle est sain. Ce sont la chaîne de valorisation et le canal d'information qui manquent.

---

## 5. Ce que je propose

**P1 — Faire exister les gains.** Dans `app_confirm_ligdicash_payment`, écrire `amount_paid = COALESCE(amount_paid, amount_due)` au moment de la confirmation. C'est une ligne, et elle débloque les deux générateurs d'un coup.

**P2 — Décider quels paiements rémunèrent.** Le filtre `registration_fee, tuition_deposit` écarte 16 paiements sur 18, dont toute la ligne « crédits ». **C'est une décision commerciale, pas technique** : dites-moi si l'achat de crédits, les frais de dossier et l'accès TD doivent rémunérer le commercial. Je n'ai pas à en décider à votre place. La liste doit ensuite vivre en configuration, pas en dur dans une fonction.

**P3 — Brancher l'achat de crédits.** `app_confirm_credit_purchase` doit appeler le générateur, comme le fait `app_confirm_ligdicash_payment`.

**P4 — Aligner la lecture sur l'écriture.** `app_manager_team_stats` doit utiliser `can_manager_act()`. Un manager révoqué ne doit plus lire les finances de son ancienne équipe.

**P5 — Dire la vérité sur les montants.** Séparer dans l'affichage : *acquis* (`status = 'paid'`), *validé* (`approved`), *en attente* (`pending`). Et sommer les colonnes du partage unifié, pas l'ancienne.

**P6 — Notifier le manager.** Ajouter le `manager_user_id` comme destinataire lorsqu'un membre de son équipe génère un paiement confirmé ou une commission. C'est le geste qui rend son rôle opérant.

**P7 — Reprise de l'historique.** Une fois P1–P3 en place, décider si les 18 paiements déjà confirmés doivent être rattrapés. Techniquement faisable ; c'est un choix de gestion, avec un impact réel sur ce que doivent trois commerciaux.

---

## 6. Limites

- Je n'ai pas vérifié si `app_admin_confirm_payment` (validation manuelle) écrit `amount_paid` — les paiements de décembre 2025 en portent un, mais ils sont antérieurs au code actuel.
- Le calcul du partage lui-même (`app_generate_commission_split_for_payment`, `commission_share_config`) n'a pas été audité sur le fond : je n'ai vérifié que ses conditions de déclenchement. Impossible de valider les montants sans une seule commission existante.
- `commercial_profiles.total_confirmed_payments`, affiché au manager, n'a pas été tracé jusqu'à son alimentation.
