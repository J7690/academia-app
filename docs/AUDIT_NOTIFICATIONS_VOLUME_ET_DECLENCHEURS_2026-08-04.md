# Audit — volume des notifications, déclencheurs, et le paiement de crédits

**Date :** 4 août 2026 · **Nature :** lecture seule, aucune modification.
**Répond à :** pourquoi tant de notifications, à quel moment elles partent, qui les reçoit, et pourquoi aucun paiement de crédits n'a été signalé hier.

---

## 1. « Je reçois beaucoup de notifications » — le compte est fait

**463 événements en 7 jours.** Répartition :

| Domaine | Événements | Destinataires | Part |
|---|---|---|---|
| `admin_audience` — digest d'activité | **385** | 7 admins | **83 %** |
| `admin_accounts` — nouveau compte | 63 | 7 admins | 14 % |
| `admin_applications` | 8 | 7 admins | 2 % |
| tout le reste | 7 | — | 1 % |

**83 % du bruit vient d'une seule source** : la tâche `admin-audience-digest`, qui tourne **toutes les 15 minutes** et crée un événement **pour chacun des 7 administrateurs**. Soit 55 exécutions × 7 = 385 notifications par semaine, dont le contenu est « 📊 Activité sur Academia — 3 visiteurs ».

### Et surtout : le multiplicateur d'appareils

Un événement ne produit pas une notification, mais **autant que l'utilisateur a de jetons actifs**. `send-push-notifications` boucle sur tous les jetons du destinataire.

| Compte | Rôle | Jetons actifs |
|---|---|---|
| **`wendenkoote@gmail.com`** | admin | **61** |
| `kayadejule@gmail.com` | commercial | 7 |
| `admin.review@academia.test` | admin | 5 |
| `nassiroumaiga@outlook.com` | manager | 3 |

**Un seul événement destiné à `wendenkoote@gmail.com` déclenche jusqu'à 61 envois.** Beaucoup de ces jetons sont morts (anciennes installations) et se désactivent au premier échec, mais chaque téléphone encore vivant reçoit sa copie. Combiné aux 385 digests, cela suffit à expliquer le déluge.

**Cause** : rien ne désenregistre jamais un appareil. `app_unregister_device_token` existe et n'est appelée par aucun code Dart ; la déconnexion laisse le jeton actif. 61 jetons = 61 installations ou réinstallations cumulées depuis le début.

---

## 2. « Cliquer sur payer envoie déjà une notification » — confirmé

Le déclencheur `app_notify_admin_payment_declared` ne filtre **aucun** statut :

```sql
IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status != OLD.status) THEN
```

| Geste de l'utilisateur | Statut | Notification ? |
|---|---|---|
| Le paiement est créé | `pending` | **oui** |
| **Il appuie sur « Payer »** (`ligdicash-initiate` pose `processing`) | `processing` | **oui** |
| L'OTP échoue | `failed` | **oui** |
| L'argent est réellement encaissé | `confirmed` | oui *(légitime)* |

Le libellé produit pour `processing` n'a même pas de cas dédié : il retombe sur le générique et affiche **« 💰 Paiement — Jean Dupont — processing »**, statut technique anglais compris.

Vous avez raison sur l'enjeu : une notification « paiement » qui part avant tout encaissement **détruit la confiance dans les notifications de paiement**. On finit par toutes les ignorer, y compris les vraies.

---

## 3. Doublons sur la création de compte

Deux défauts distincts, tous deux vérifiés :

**a) Double envoi.** Un compte créé par un manager déclenche **deux** notifications identiques : le déclencheur `trg_admin_new_account_notify` sur `auth.users`, **plus** un envoi explicite dans `app_manager_create_commercial`. Signature dans les données : `conseiller@gmail.com` notifié à 22:14:38 puis 22:15:03 — **25 secondes d'écart**.

**b) Notifications vides.** `app_notify_admin_new_account` se déclenche **AFTER INSERT sur `auth.users`**, instant où l'e-mail n'est pas encore renseigné pour une inscription par téléphone. Résultat :

```json
{"role": "student", "email": "", "new_user_id": "..."}
```

rendu en **« 👤 Nouveau compte créé — student — »**. **175 notifications de ce type sur 30 jours** (25 comptes × 7 admins), sans aucune information exploitable.

---

## 4. « Je n'ai pas été notifié du paiement de crédits d'hier »

**Vérification : aucun paiement de crédits n'a eu lieu depuis le 19 juillet 2026.**

Le dernier achat confirmé date du 19/07 (100 XOF). Les 13 mouvements de crédits des 7 derniers jours sont tous des **bonus hebdomadaires** (`weekly_bonus`, tâche automatique du lundi) — pas des achats :

| Type de mouvement (30 j) | Nombre | Crédits |
|---|---|---|
| `weekly_bonus` | 38 | 570 |
| `refund` | 5 | 75 |
| `purchase` | **3** | 1 790 — *derniers : 15 et 19 juillet* |

Aucun paiement n'est resté bloqué en `processing` (0 ligne). Il n'y a donc **rien eu à notifier**.

> ⚠️ **Mais si vous avez bien reçu un SMS LigdiCash hier**, alors de l'argent a été encaissé **sans qu'aucune ligne ne bouge dans l'application** — ni paiement, ni crédit, ni notification. Ce serait exactement le scénario que rendent possibles les faiblesses décrites dans `AUDIT_PAIEMENT_ET_NOTIFICATIONS_2026-08-04.md` (§2.3 et §2.4).
>
> **Donnez-moi la référence et l'heure du SMS LigdiCash** : je remonterai la trace côté journaux pour savoir si l'appel de confirmation a échoué, et si l'étudiant a payé sans rien recevoir.

---

## 5. `kayadejule@gmail.com` — incident confirmé

Vous confirmez qu'il s'agit d'un **commercial réel**, pas d'un compte de test. Le constat change donc de nature :

- son téléphone partage un jeton actif avec **`wendenkoote@gmail.com` (administrateur)** ;
- il reçoit donc les notifications d'administration : **candidatures, comptes créés avec leur rôle et leur e-mail, extraits de messages de support, et les paiements dès qu'il y en aura** ;
- il détient par ailleurs **7 jetons actifs**.

**Ce n'est plus une gêne de test : un commercial voit des données d'administration.** À refermer en priorité.

---

## 6. Vos règles, telles que je les retiens

> **Un achat de crédits IA ne doit notifier ni le manager, ni le commercial.**

État actuel : ni l'un ni l'autre n'est notifié — mais **par accident**, parce que la chaîne de commissions ne fonctionne pas du tout (cf. `AUDIT_MANAGER_COMMERCIAUX_GAINS_2026-08-04.md`). En revanche, **les 7 administrateurs sont bien notifiés**, y compris à la simple pression sur « Payer ».

Quand nous réparerons la chaîne des gains, il faudra donc **exclure explicitement `credit_purchase`** de la liste des motifs rémunérateurs — sans quoi le correctif créerait précisément les notifications que vous ne voulez pas.

---

## 7. Ce que je propose de corriger

**P1 — Le canal de fuite.** Ne garder qu'une inscription active par appareil physique, et appeler `app_unregister_device_token` avant chaque `signOut()`. Effet immédiat : `kayadejule` cesse de recevoir l'administration, et `wendenkoote` passe de 61 envois à 1.

**P2 — Notifier des encaissements, pas des intentions.** `app_notify_admin_payment_declared` ne doit se déclencher que sur `confirmed` et `declared_by_student`. Même correction pour `app_notify_university_payment`. Et compléter la table des libellés pour qu'aucun statut technique anglais n'atteigne un humain.

**P3 — Le digest d'activité.** 385 notifications par semaine pour annoncer « 3 visiteurs ». Passer de 15 minutes à **une fois par jour**, et ne l'envoyer qu'en cas d'activité réelle. À lui seul, ce réglage retire 83 % du volume.

**P4 — La création de compte.** Supprimer l'envoi explicite dans `app_manager_create_commercial` (le déclencheur suffit), et déplacer la notification **après** le renseignement de l'e-mail — ou ne pas notifier tant qu'il est vide.

**P5 — Périmètre des motifs.** Inscrire `credit_purchase` comme **non rémunérateur** et **non notifiable** pour le manager et le commercial, dans une configuration lisible plutôt qu'en dur.

---

## 8. Effet attendu

| | Aujourd'hui | Après P1–P4 |
|---|---|---|
| Événements / semaine | 463 | **~20** |
| Envois vers `wendenkoote` | jusqu'à 61 par événement | **1** |
| Notification à la pression sur « Payer » | oui | **non** |
| Notifications « compte créé » vides | 175 / mois | **0** |
| Un commercial voit l'administration | oui | **non** |

---

## 9. Limites

- Les journaux des fonctions Edge n'ont pas pu être récupérés (erreur du service côté Supabase). La vérification d'un éventuel encaissement LigdiCash non enregistré hier reste donc à faire, et nécessite la référence du SMS.
- Je n'ai pas vérifié si `app_admin_confirm_payment` (validation manuelle) écrit `amount_paid` ; cela conditionne la réparation de la chaîne des gains.
