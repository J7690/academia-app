# Audit — système de paiement et notifications de paiement

**Date :** 4 août 2026
**Périmètre :** chaîne LigdiCash (initiation, confirmation, webhook, reversement), déclencheurs de notification, RPC financières, droits d'exécution, appels côté application.
**Nature :** audit en **lecture seule**. Aucune modification apportée. Aucun test d'exploitation n'a été exécuté contre la production — les conclusions reposent sur la lecture du code déployé et sur l'état réel des droits en base.

---

## 0. En un paragraphe

La cause des fausses notifications est identifiée et bénigne : **un déclencheur notifie à chaque changement de statut, sans filtrer** — appuyer sur « payer » fait passer le paiement en `processing`, ce qui suffit à envoyer « 💰 Paiement » aux 7 comptes administrateurs. C'est réparable en quelques lignes.

Mais l'audit a mis au jour beaucoup plus grave. **Trois fonctions financières sont exécutables par n'importe qui, sans authentification, et confirment un paiement ou déclenchent un reversement sans qu'un franc ait été encaissé.** Elles ne sont appelées ni par l'application, ni par le code SQL : ce sont des portes ouvertes sans usage. C'est le sujet urgent de ce rapport.

---

## 1. La question posée : les fausses notifications

### Ce qui se passe

`app.application_payments` porte **sept déclencheurs**, dont quatre sur `INSERT OR UPDATE`. Le fautif est `trg_admin_payment_declared_notify` → `app_notify_admin_payment_declared` :

```sql
IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status != OLD.status) THEN
    -- ... notifie TOUS les administrateurs ...
```

**Aucun filtre sur le statut.** La fonction s'appelle « payment_declared » mais elle notifie sur *tout* :

| Moment | Statut | Notification ? |
|---|---|---|
| Création du paiement | `pending` | **Oui** |
| L'utilisateur appuie sur « Payer » (`ligdicash-initiate`) | `processing` | **Oui** ← *le cas signalé* |
| Échec de l'OTP | `failed` | **Oui** |
| Paiement réellement encaissé | `confirmed` | Oui (légitime) |

Le rendu (`send-push-notifications`, ligne 434) n'a pas de cas pour `processing` : il retombe sur le générique et produit **« 💰 Paiement — Jean Dupont — processing »**. Le statut anglais brut est affiché à l'utilisateur.

Multiplié par les **7 comptes administrateurs** notifiés en boucle, une seule tentative de paiement produit jusqu'à **21 notifications** (pending, processing, échec).

### Contre-exemple dans le même fichier

`app_notify_commercial_prospect_payment` fait les choses correctement :

```sql
IF (TG_OP = 'INSERT' AND NEW.status = 'declared_by_student')
   OR (TG_OP = 'UPDATE' AND NEW.status = 'declared_by_student' AND OLD.status IS DISTINCT FROM NEW.status)
```

Le filtre existe donc dans le projet. Il n'a simplement pas été appliqué au déclencheur administrateur ni à `app_notify_university_payment` (même défaut).

### Précision sur « le manager »

**Le rôle `manager` ne reçoit aucune notification de paiement.** Vérifié :
- un seul compte porte `role = 'manager'` ;
- `app_get_notification_summary` ne contient **aucune** occurrence de `manager` — ce rôle n'a pas de branche, il reçoit un résumé vide ;
- la file `app.notification_events` ne contient aucun événement de paiement vers ce compte.

Les destinataires réels sont les **7 comptes `admin`** (368 événements `admin_payments`). Si la personne que vous appelez « le manager » reçoit ces notifications, c'est qu'elle utilise un compte **administrateur**. Cela ne change rien au correctif, mais c'est utile pour savoir qui débrancher.

---

## 2. Ce que l'audit a trouvé de bien plus grave

### 2.1 — CRITIQUE : confirmer un paiement sans payer, depuis n'importe où

Deux fonctions sont `SECURITY DEFINER` (propriétaire `postgres`, donc **RLS contournée**) et disposent d'un `EXECUTE` accordé à **`anon`, `authenticated` et `PUBLIC`** :

- `public.app_confirm_ligdicash_payment(...)`
- `public.app_confirm_credit_purchase(...)`

Ni l'une ni l'autre ne vérifie :
- qui appelle (aucun contrôle de rôle, aucun `auth.uid()` de contrôle) ;
- si l'appelant possède le paiement ;
- **si LigdiCash a effectivement encaissé quoi que ce soit** — le jeton reçu en paramètre est écrit tel quel (`COALESCE(p_ligdicash_token, ligdicash_token)`), jamais vérifié auprès du prestataire.

Elles se contentent de vérifier que le statut est dans `('pending','declared_by_student','under_verification','processing')`, puis :
confirment le paiement · émettent un **reçu** · écrivent au **grand livre** (`platform_ledger`) · génèrent les **commissions** · créditent les **soldes des bénéficiaires** · accordent les **crédits** achetés.

La clé `anon` est publique par construction — elle est embarquée dans l'APK. **Toute personne disposant de l'application peut donc appeler ces fonctions directement.** Pour un achat de crédits, l'attaquant génère lui-même l'UUID du paiement côté client (c'est le fonctionnement documenté dans `ligdicash-initiate`) : il connaît donc l'identifiant à confirmer.

> **Aucun appelant légitime.** Vérifié : ces deux fonctions ne sont appelées ni par l'application Flutter, ni par aucune autre fonction SQL. Seules les Edge Functions les invoquent, et celles-ci utilisent la clé `service_role`. **Révoquer `anon` et `authenticated` ne casserait rien.**

### 2.2 — CRITIQUE : faire sortir de l'argent

`public.app_auto_queue_payout(p_actor_type, p_actor_id, p_amount, p_currency, p_reason, p_source_payment_id)`

`SECURITY DEFINER`, ouverte à `anon`, **aucun contrôle d'aucune sorte**. Elle insère directement dans `app.payout_queue` avec le montant fourni par l'appelant.

La tâche planifiée `process_pending_payouts` traite cette file **toutes les 15 minutes** et déclenche les virements mobile money réels via `ligdicash-payout`. Un bénéficiaire dont le profil porte un `payout_phone` obtient le statut `pending` — donc payable.

**Cette fonction n'est appelée par rien** : ni l'application, ni aucune fonction SQL. C'est du code mort doté d'un accès public à la sortie de trésorerie.

### 2.3 — ÉLEVÉ : le webhook public confirme sans vérifier

`ligdicash-callback` est déployée avec `verify_jwt: false` — URL publique, par nécessité. Sa protection annoncée est la re-vérification du jeton auprès de LigdiCash. Or (lignes 157-185) :

```js
if (LIGDICASH_MODE !== 'mock' && token && LIGDICASH_API_KEY) {
    // ... vérification auprès de LigdiCash ...
} else {
    verified = true;   // ← « Mock mode — on fait confiance au callback »
}
```

La branche `else` se déclenche aussi lorsque **`token` est vide** — et le corps de la requête est entièrement contrôlé par l'appelant. Un POST sans jeton, portant seulement `custom_data.payment_id`, saute la vérification, obtient `verified = true`, et confirme le paiement.

L'allowlist IP est **désactivée par défaut** (`LIGDICASH_ALLOWED_IPS` vide → « autorise tout »), choix documenté et défendable puisque LigdiCash ne publie pas d'IP stables — mais il ne reste alors **aucune** barrière.

> Version déployée comparée au dépôt : **identiques**. Le chemin est actif en production.

### 2.4 — ÉLEVÉ : une erreur de configuration rend les paiements gratuits

`ligdicash-confirm`, ligne 101 :

```js
if (LIGDICASH_MODE !== 'mock' && LIGDICASH_API_KEY && LIGDICASH_BEARER_TOKEN) {
    // ... appel réel à LigdiCash ...
} else {
    // MOCK MODE : le code OTP « 123456 » confirme le paiement
```

Si les clés LigdiCash expirent, sont mal orthographiées ou effacées, la fonction **ne signale pas d'erreur** : elle bascule silencieusement en mode simulation, où `123456` suffit à confirmer n'importe quel paiement. `ligdicash-initiate` refuse explicitement ce cas (`ligdicash_not_configured`) ; `ligdicash-confirm` ne le fait pas.

**Une panne de configuration devient une faille de sécurité.** C'est le contraire d'une dégradation sûre.

### 2.5 — ÉLEVÉ : un étudiant confirme son propre paiement

`app_confirm_short_training_payment(p_payment_id, p_receipt_number)` vérifie l'appartenance (`student_id = auth.uid()`) mais **rien d'autre** : ni le statut de départ, ni le paiement effectif. Elle passe le paiement à `confirmed` et débloque l'accès à la formation.

Elle est appelée **directement depuis l'application** ([student_short_trainings_section.dart:446](academia_app/lib/features/student/widgets/student_short_trainings_section.dart:446)). Un étudiant peut donc créer un paiement puis le confirmer lui-même, sans passer par LigdiCash.

### 2.6 — MOYEN : surface d'attaque générale

**58 fonctions financières** en `SECURITY DEFINER` portent un `EXECUTE` pour `anon` / `authenticated` / `PUBLIC`. C'est le comportement **par défaut** de PostgreSQL — toute fonction créée dans `public` est exécutable par tous — et personne ne l'a jamais révoqué.

La bonne nouvelle : la majorité des `app_admin_*` contrôlent le rôle en interne (`app_admin_confirm_payment`, `app_admin_verify_payment`, `app_admin_upsert_commission_rule`…). `app_admin_confirm_payment_with_share` délègue à une fonction qui contrôle — elle est saine malgré son nom exposé.

La mauvaise : rien ne garantit que la prochaine fonction ajoutée le fera. **La sécurité repose sur la discipline de chaque auteur, jamais sur une barrière.**

### 2.7 — FAIBLE : déclencheur de push non authentifié

`send-push-notifications` est déployée en `verify_jwt: false` et appelée sans en-tête d'autorisation (`trg_instant_push_notification` et `app_run_send_push_notifications` envoient `{"Content-Type":"application/json"}` seul). N'importe qui peut la déclencher.

L'impact est limité — elle ne fait que vider une file existante, sans permettre d'injecter du contenu — mais elle permet de forcer l'envoi et de sonder le rythme d'activité.

---

## 3. Synthèse par gravité

| # | Constat | Gravité | Exploitable par |
|---|---|---|---|
| 2.1 | `app_confirm_ligdicash_payment` / `app_confirm_credit_purchase` ouvertes à `anon` | **Critique** | Quiconque a l'application |
| 2.2 | `app_auto_queue_payout` ouverte à `anon` — sortie d'argent | **Critique** | Quiconque a l'application |
| 2.3 | Webhook public : jeton vide ⇒ vérification sautée | **Élevé** | Quiconque connaît un UUID de paiement |
| 2.4 | Repli silencieux en mode simulation si clés absentes | **Élevé** | Déclenché par une panne, pas par un attaquant |
| 2.5 | L'étudiant confirme son propre paiement de formation | **Élevé** | Tout étudiant |
| 1 | Notifications sur chaque changement de statut | **Moyen** (bruit, confiance) | — |
| 2.6 | 58 fonctions financières exécutables par `anon` | **Moyen** (surface) | — |
| 2.7 | Déclencheur de push non authentifié | **Faible** | Quiconque |

**Volume actuel concerné** : 18 paiements confirmés pour 7 260 XOF au total, 9 en attente. Aucune transaction en mode simulation détectée. **Rien n'indique une exploitation passée** — l'exposition est réelle, l'abus ne l'est pas encore. C'est le bon moment pour refermer.

---

## 4. Ce que je propose : simple, et sûr par construction

Quatre règles. Aucune n'est complexe ; chacune remplace une discipline par une barrière.

### Règle 1 — Un paiement n'est confirmé que par le prestataire

Une seule fonction confirme, et elle exige la preuve. Concrètement :

- `app_confirm_ligdicash_payment` et `app_confirm_credit_purchase` : **révoquer `anon`, `authenticated`, `PUBLIC`**. Ne laisser que `service_role`. Aucun impact client — personne ne les appelle depuis l'application.
- Y ajouter une garde interne : refuser si `auth.uid()` n'est pas nul (c'est-à-dire refuser tout appel venant d'un utilisateur, même si un `GRANT` réapparaissait un jour par accident). **Ceinture et bretelles, pour trois lignes.**
- Exiger un `p_ligdicash_transaction_id` non vide : aujourd'hui une confirmation sans référence de transaction est acceptée.

### Règle 2 — Refuser plutôt que simuler

- `ligdicash-confirm` : si `LIGDICASH_MODE = 'live'` et qu'une clé manque, **retourner une erreur**, comme le fait déjà `ligdicash-initiate`. Ne jamais retomber en mode simulation.
- Le mode simulation ne doit s'activer que sur `LIGDICASH_MODE = 'mock'` **explicite**, jamais par défaut ni par accident. Aujourd'hui la valeur par défaut du code est `'mock'` — l'inverse de ce qu'il faut : **la valeur par défaut devrait être le refus.**
- `ligdicash-callback` : si le jeton est absent, **rejeter** au lieu de faire confiance. Un webhook sans jeton n'est pas un webhook de LigdiCash.

### Règle 3 — Une machine à états explicite

Les transitions de `application_payments.status` doivent être décrites une fois et gardées par un déclencheur `BEFORE UPDATE` :

```
pending → processing → confirmed
   ↓          ↓
cancelled   failed
```

Toute autre transition est refusée par la base. En particulier, **rien ne doit pouvoir mener à `confirmed` en dehors du chemin prévu** — cela neutralise d'un coup 2.1, 2.3 et 2.5, même si un chemin d'appel était oublié.

### Règle 4 — Notifier des faits, pas des intentions

- `app_notify_admin_payment_declared` : filtrer sur les statuts qui méritent une notification — `declared_by_student` et `confirmed`. Rien d'autre. Même correction pour `app_notify_university_payment`.
- Ne jamais afficher un statut technique brut (`processing`) à un humain : compléter la table de correspondance dans `send-push-notifications`.
- Grouper : sept administrateurs recevant sept fois la même notification est un bruit qui finit par faire ignorer les vraies alertes. Une notification par événement, adressée à un rôle, vaut mieux que sept.

### Et une mesure d'hygiène

Révoquer `EXECUTE` à `anon` sur l'ensemble des fonctions financières, puis le réaccorder **explicitement** aux seules fonctions que l'application appelle vraiment (l'inventaire des appels Flutter est court : quatre entrées). Poser ensuite `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` pour que la prochaine fonction créée soit fermée par défaut.

C'est la seule mesure qui protège aussi le code **futur**.

---

## 5. Ordre que je recommande

1. **Révoquer les trois fonctions critiques** (2.1, 2.2). Une migration, quelques secondes, aucun impact client. Referme les deux trous les plus graves.
2. **Corriger `ligdicash-confirm` et `ligdicash-callback`** (2.3, 2.4). Un déploiement.
3. **Corriger `app_confirm_short_training_payment`** (2.5) — nécessite d'ajuster l'appel côté application, donc une nouvelle version de l'APK.
4. **Filtrer les notifications** (§1). Indépendant du reste, peut se faire en parallèle.
5. **Machine à états** (règle 3) puis **hygiène des droits** (règle 4) — les deux mesures de fond.

---

## 6. Limites de cet audit

- **Aucun test d'exploitation n'a été exécuté.** Confirmer un paiement fictif en production aurait créé un reçu, une écriture au grand livre et des commissions. Les conclusions viennent de la lecture du code déployé et de l'état des droits — les chemins sont sans ambiguïté, mais je n'ai pas de preuve d'exécution. Si vous en voulez une, elle doit se faire sur une branche de base de données dédiée.
- **La valeur de `LIGDICASH_MODE` en production n'a pas pu être lue** (les secrets des Edge Functions ne sont pas exposés). L'absence de transaction `MOCK_*` parmi les 18 paiements confirmés suggère le mode `live`, sans le prouver. **À vérifier en priorité** : si le mode est resté `mock`, le point 2.4 n'est plus un risque mais un fait.
- Le module marketplace n'a été parcouru que sur son chemin de paiement ; sa logique d'entiercement n'a pas été auditée.
- Les montants et le calcul des commissions (`app_resolve_revenue_split`, `app_generate_commission_split_for_payment`) n'ont pas été vérifiés sur le fond — l'audit a porté sur *qui peut déclencher*, pas sur *combien est calculé*.
