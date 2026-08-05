# Correctifs appliqués — paiement, sécurité et commissions (04/08/2026)

Suite de `AUDIT_PAIEMENT_ET_NOTIFICATIONS_2026-08-04.md` et
`AUDIT_MANAGER_COMMERCIAUX_GAINS_2026-08-04.md`.
Tout ce qui suit est **appliqué en production** et vérifié.

---

## 0. Ce que la documentation LigdiCash a établi

Recherche préalable sur `developers.ligdicash.com`. Deux faits ont dicté la
conception :

**LigdiCash n'envoie ni signature HMAC, ni secret partagé, ni en-tête
d'authentification**, et ne publie pas d'IP source stables. Il n'existe donc
aucun moyen de prouver qu'une requête entrante vient de lui. D'où le principe
retenu :

> **Le callback est un signal de réveil, jamais une preuve.**
> Quoi qu'il annonce, on redemande nous-mêmes à LigdiCash, avec notre clé.

**Les statuts réels sont `pending`, `completed`, `notcompleted`.** Le code
guettait `failed`, `cancelled`, `rejected` — trois valeurs qui n'existent pas.
Un échec définitif n'était donc jamais reconnu : on attendait les dix
scrutations pour rendre un « délai dépassé » au lieu d'un refus franc.

---

## 1. Les trois portes ouvertes sur l'argent — fermées

### Deux barrières, pas une

`app_confirm_ligdicash_payment`, `app_confirm_credit_purchase` et
`app_auto_queue_payout` étaient `SECURITY DEFINER`, propriété de `postgres`
(donc RLS contournée), avec un `EXECUTE` pour `anon` et `authenticated` — soit
n'importe qui, la clé anon étant embarquée dans l'APK.

1. **Retrait de l'exposition.** Vérifié au préalable : aucune n'est appelée par
   le code Flutter ni par le code SQL. Seules les Edge Functions les appellent,
   avec `service_role`.
2. **Garde interne.** Elles refusent désormais tout appel portant un
   `auth.uid()`. Les Edge Functions utilisent la clé de service, où `auth.uid()`
   vaut NULL. **C'est cette seconde barrière qui survit à une erreur de
   configuration future.**

Vérifié : un appel avec une identité utilisateur simulée est rejeté en `42501`.

### L'étudiant ne confirme plus son propre paiement

`app_confirm_short_training_payment` passait le paiement à `confirmed` sur simple
demande du propriétaire. Son rôle réel, tel qu'il est appelé côté Flutter, est
de **débloquer l'accès après** confirmation par LigdiCash. Elle constate
désormais au lieu de décider — et refuse si le paiement n'est pas encaissé.

### Les fonctions futures sont fermées par défaut

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
```

Les 58 fonctions financières ouvertes à `anon` n'étaient pas une négligence
isolée : c'est le **comportement par défaut de PostgreSQL**, jamais révoqué.

> ⚠️ **Changement de méthode de travail.** Toute nouvelle RPC destinée à
> l'application doit désormais porter explicitement
> `GRANT EXECUTE ... TO authenticated;`, sinon elle répondra « permission
> denied ». C'est voulu : on déclare ce qu'on ouvre, au lieu de découvrir ce
> qu'on a laissé ouvert.

---

## 2. Le webhook ne confirme plus sur parole

`ligdicash-callback` (v64, déployée) applique cinq règles :

1. **Pas de jeton → refus.** C'était la faille : l'absence de jeton faisait
   *sauter* la vérification au lieu de l'imposer.
2. **Clés absentes → refus.** Une panne de configuration ne doit jamais ouvrir
   un chemin de confirmation.
3. **Vérification obligatoire** auprès de LigdiCash : `response_code === '00'`
   **et** `status === 'completed'`.
4. **Le montant retenu est celui que LigdiCash confirme**, jamais celui du corps.
5. **Le paiement est résolu par le jeton** — notre propre trace, écrite à
   l'initiation — et non par le `custom_data` fourni par l'appelant.

**Vérifié en production** contre la vraie URL :

| Requête forgée | Réponse |
|---|---|
| `custom_data.payment_id` sans jeton | `missing_token` |
| jeton inventé | `payment_not_completed` |

Le paiement visé est resté `pending`, `amount_paid` NULL.

## 3. `ligdicash-confirm` refuse au lieu de simuler

`ligdicash-confirm` (v68, déployée) :

- **Mode live sans clés → HTTP 503**, au lieu de basculer silencieusement en
  mode simulation où « 123456 » confirmait n'importe quel paiement. Une panne
  de configuration ne devient plus une faille.
- **Statuts réels** : `notcompleted` est reconnu comme un refus définitif.
- **Le montant encaissé est transmis** à la confirmation.

---

## 4. La chaîne des commissions est rétablie

### Le chaînon manquant

`app_confirm_ligdicash_payment` confirmait le paiement **sans jamais écrire
`amount_paid`**. Or les deux générateurs commencent par
`IF amount_paid IS NULL THEN RETURN 'no_amount_paid'`. Le générateur était
appelé, lisait NULL, abandonnait en silence — à chaque fois. D'où 18 paiements
confirmés et zéro commission.

La fonction accepte désormais `p_amount_paid` et l'enregistre.

### La règle métier sort du code

Nouvelle table `app.commission_motifs_eligibles` : quels motifs rémunèrent, et
lesquels notifient. Elle **reprend exactement le comportement actuel** — je n'ai
pas inventé de politique commerciale.

| Motif | Rémunère | Notifie | Statut |
|---|---|---|---|
| `registration_fee` | ✅ | ✅ | inchangé |
| `tuition_deposit` | ✅ | ✅ | inchangé |
| `application_fee` | ❌ | ❌ | **à arbitrer** — 8 paiements concernés |
| `td_access` | ❌ | ❌ | **à arbitrer** |
| `credit_purchase` | ❌ | ❌ | **votre décision du 04/08** |

Changer d'avis se fait par un `UPDATE` d'une ligne, sans migration ni
déploiement.

### Le manager voit juste, et il est prévenu

- **`app_manager_team_stats` exige `can_manager_act()`** au lieu de
  `is_manager()`. Un manager désactivé ou suspendu ne lit plus les finances de
  son ancienne équipe : le droit de lecture ne survit plus à la révocation.
- **Les gains sont ventilés** : `gains_verses` / `gains_valides` /
  `gains_en_attente`. La somme précédente ne filtrait aucun statut — une
  commission en attente comptait comme acquise.
- **Le montant du partage unifié** (`owner_commission_amount`) prime sur
  l'ancienne colonne.
- **Trois déclencheurs remontent désormais au manager** : déclaration,
  encaissement, commission. Un motif non notifiable ne réveille personne — ni le
  commercial, ni le manager.

### Vérification de bout en bout

Test complet exécuté puis **annulé par `RAISE EXCEPTION`** (aucune persistance) :

```
confirmation           = true
amount_paid écrit      = 100.00     (était NULL)
commissions créées     = 1, total 20.00   (20 % de 100)
notifications manager  = 2
notifications commercial = 1
```

État après annulation : paiement `pending`, `amount_paid` NULL, 0 commission,
0 notification. **Rien n'a persisté.**

---

## 5. Le seul déploiement en attente

`send-push-notifications` est **corrigée dans le dépôt** mais **non redéployée** :

- table des libellés complétée (`processing`, `pending`, `failed`, `cancelled`
  ne peuvent plus atteindre un humain en anglais brut) ;
- rendu du domaine `manager_equipe` — sans lui, les notifications d'équipe
  arrivent titrées « Academia » avec un corps vide.

Le fichier fait 31 Ko. Le retranscrire à la main pour le déployer par cet outil
présentait un risque d'erreur supérieur au bénéfice, sur une fonction qui marche.
À déployer par la CLI :

```bash
supabase functions deploy send-push-notifications
```

**Le dépôt est en avance sur la production, pas en retard** — c'est le sens sûr.

---

## 6. Le montant encaissé est recoupé au montant dû

### La référence : ce qui a été facturé, pas ce qui est dû

La facture envoyée à LigdiCash est `Math.round(amount_due)` — arrondie à
l'entier. C'est donc `ROUND(amount_due)` qui doit être comparé au montant
confirmé. Comparer au montant brut aurait fait échouer tout paiement à
décimales. La tolérance est de **1 XOF** : exactement l'écart que notre propre
arrondi peut introduire.

Pour un achat de crédits, la référence n'est pas la ligne de paiement mais
**le prix du pack**. Sans cela, quelqu'un payant 10 XOF pouvait recevoir un pack
à 750.

### Tout écart matériel arrête l'automatisme

| Situation | Décision |
|---|---|
| Écart ≤ 1 XOF | Confirmation normale |
| Sous-paiement | **Pas de confirmation.** Statut `under_verification` |
| Sur-paiement | **Pas de confirmation.** Un humain tranche |
| Montant non vérifié | Confirmation sur le dû, reçu portant `montant_verifie: false` |

Le sur-paiement est traité comme le sous-paiement : ce n'est pas une faveur à
accorder en silence. Quelqu'un a payé plus que dû — cela appelle un
remboursement ou une explication.

Chaque reçu porte désormais le détail du rapprochement : attendu, encaissé,
écart, sens. **La trace dit ce qu'on sait et ce qu'on ne sait pas.**

### Vérifié (tests annulés, aucune persistance)

```
rapprocher_montant(100, 100)    → conforme
rapprocher_montant(100.50, 101) → conforme   (arrondi toléré)
rapprocher_montant(100, 50)     → sous_paiement, écart -50
rapprocher_montant(100, 250)    → sur_paiement,  écart +150
rapprocher_montant(100, NULL)   → non vérifié

Pack « mini » (100 XOF) :
  10 XOF  → amount_mismatch · statut under_verification · 0 crédit accordé
  100 XOF → confirmé · 150 crédits (100 + bonus 1er achat)
```

État après annulation : paiement `pending`, 0 crédit, 0 reçu créé.

### Fonctions déployées

`ligdicash-callback` v65 et `ligdicash-confirm` v69 transmettent le montant
vérifié pour **les deux** chemins — générique et achat de crédits. Un écart
remonte à l'utilisateur en HTTP 409 avec un message clair, plutôt qu'un échec
opaque.

Contrôle final : callback sans jeton → `missing_token` ; jeton forgé →
`payment_not_completed` ; `confirm` sans authentification → HTTP 401 ;
**0 fonction d'argent encore exposée** à `anon` ou `authenticated`.

---

## 7. Ce qui reste ouvert

- **Arbitrer `application_fee` et `td_access`** : rémunérateurs ou non. Un
  `UPDATE` d'une ligne suffit.
- **`LIGDICASH_MODE`** n'a toujours pas pu être lu (secrets non exposés).
  Aucune transaction `MOCK_*` parmi les paiements confirmés suggère le mode
  `live`. À confirmer dans les secrets de la Edge Function.
- La clé `service_role` reste en clair dans 5 tâches cron (Vault sans rotation
  décidé, non encore appliqué).
- `send-push-notifications` reste à déployer (cf. §5).

## Décisions actées, sans suite à donner

- **Aucune commission rétroactive** sur les sommes déjà encaissées. Décision du
  04/08/2026. Les 18 paiements confirmés restent sans commission.
- **Un paiement sans parrainage ne génère rien**, et c'est correct : le
  générateur répond `no_referral_for_student`. Un étudiant venu directement,
  sans passer par le lien d'un commercial, ne doit rémunérer personne. Aucune
  correction n'était nécessaire sur ce point.
