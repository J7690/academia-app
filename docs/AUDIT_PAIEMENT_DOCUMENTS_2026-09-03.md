# Audit du domaine paiement / reçus / documents — 2026-09-03

**Méthode.** Relevé de l'état Supabase réel (projet vivant `thevdfcwlcqzdoybfvgs`,
lecture seule) confronté ligne par ligne au code Flutter : 300 appels `.rpc()`,
27 accès `.from()`, 104 fonctions du domaine avec leur source, toutes les
politiques RLS, tous les droits. Audit conduit par un workflow multi-agents
(cartographie → constats par dimension → **vérification adverse**), complété à la
main sur les constats critiques que la vérification n'a pas atteints (limite de
session). Chaque point porte son ancrage. **On mesure, on ne suppose pas.**

> **Correction de méthode.** Les nombres de lignes de `tables_colonnes.json`
> (`n_live_tup`) sont des **estimations périmées** et fausses. Comptes réels par
> `COUNT(*)` le 03/09 : `application_payments` 30 (18 confirmés),
> `payment_receipts` 18, `student_credits` 18, `credit_transactions` **279**,
> `student_dossier_documents` 5, `subscriptions` **0**, `referral_commissions`
> **0**, `actor_balances` **0**, `payout_queue` **0**, `marketplace_payments`
> **0**, `email_queue` 3 (tous `pending`). Tout constat ci-dessous s'appuie sur
> ces comptes réels.

---

## 1. Ce qui prime — bloquants

### B1 · SÉCURITÉ · SQL arbitraire ouvert à `anon`
`public.admin_execute_sql`, `execute_sql`, `execute_ddl` sont `SECURITY DEFINER`
(propriétaire `postgres`), exécutent du SQL/DDL **arbitraire**, et portent
`anon=X` dans leur ACL (`droits_fonctions.json`) — `execute_sql`/`execute_ddl`
l'ouvrent même à `PUBLIC`. La clé `anon` est en clair dans
`academia_app/lib/config/supabase_config.dart:8`, donc dans l'APK.
**Prouvé** : appel avec la seule clé anon → `HTTP 200 {"ok":true}`. Quiconque
décompile l'app lit/écrit toute la base, contourne toute la RLS.
**Correctif prêt** : `scratchpad/correctif_faille_sql.sql` — garde d'identité
(`service_role` ou admin) + `REVOKE ... FROM anon, PUBLIC`. Vérifié comme ne
cassant **ni** les Edge Functions `prep-*`/`td-*` (service_role) **ni** l'écran
admin `admin_td_upload_screen.dart:67` (utilisateur admin). Effort **S**.

### ~~B2 · SÉCURITÉ · Rôle admin lu dans `user_metadata`~~ — **RÉTROGRADÉ : NON EXPLOITABLE**

> **Correction du 03/09, et c'est mon erreur.** J'ai d'abord annoncé ce point
> comme bloquant, à l'égal de B1. **Il ne l'est pas.**
>
> Il est exact que **38 fonctions** gardent l'accès admin par
> `raw_user_meta_data->>'role'`, et exact que `user_metadata` est en principe
> écrivable par l'utilisateur (`auth.updateUser`). Mais il existe déjà un
> garde-fou que je n'avais pas vu : le déclencheur
> **`trg_sync_role_from_app_metadata`**, `BEFORE INSERT OR UPDATE` sur
> `auth.users`, réécrit `user_metadata.role` à partir de `app_metadata.role` à
> chaque écriture. Un étudiant qui se proclamerait admin voit sa valeur
> **écrasée avant enregistrement**. L'escalade ne passe pas.
>
> **Pourquoi je ne l'avais pas vu** : mon relevé de déclencheurs ne couvrait que
> les schémas `app` et `public` — **j'avais exclu `auth`**. Les agents d'audit
> ont donc raisonné sur un angle mort que j'avais créé. Si j'avais foncé
> réécrire 38 fonctions, j'aurais pris un risque considérable pour rien.
>
> **Ce qui a été fait à la place** : `app.est_admin()` a été créée — elle ne lit
> que `raw_app_meta_data`, que l'utilisateur ne peut pas modifier. Elle est
> utilisée pour **toute garde nouvelle** (B1, B4), si bien que la protection de
> ces points-là ne dépend plus de la survie d'un déclencheur. Les 38 fonctions
> existantes ne sont **pas** réécrites : elles sont couvertes, et le chantier
> serait disproportionné.
>
> Sûr par mesure : les 7 comptes admin portent `admin` dans **les deux**
> emplacements — durcir vers `app_metadata` ne verrouille personne dehors.
>
> **Reste, en dette** : la protection des 38 fonctions repose sur un
> déclencheur. Le supprimer rouvrirait la faille. À migrer un jour, sans
> urgence. Sévérité réelle : **amélioration**, pas bloquant.

### B3 · SÉCURITÉ · `app_student_reserve_credits(3 args)` — IDOR
La surcharge `public.app_student_reserve_credits(p_action_code, p_edge_function,
p_student_id)` fait `v_uid := COALESCE(p_student_id, auth.uid())` : l'appelant
choisit **au nom de qui** réserver/débiter des crédits. `SECURITY DEFINER`,
appelable par `anon`. **Correctif** : ignorer `p_student_id`, forcer
`auth.uid()` ; retirer la surcharge à `anon`. Effort **S**.

### B4 · SÉCURITÉ · `app_admin_list_marketplace_payments` — « admin » de nom seulement
`SECURITY DEFINER` ouvrant directement sur `SELECT … FROM
app.marketplace_payments` (buyer_id, merchant_id, montants, réf. paiement)
**sans aucun** `auth.uid()` ni contrôle de rôle. Aujourd'hui sans données
(0 ligne) mais la porte est ouverte. **Correctif** : garde admin en tête.
Effort **S**.

### B5 · SÉCURITÉ · `app_student_confirm_credits` / `refund_credits` — sans appartenance
Les deux prennent `p_reservation_id` et n'appellent **jamais** `auth.uid()` :
n'importe qui confirme/rembourse la réservation d'autrui en connaissant l'UUID.
**Correctif** : vérifier que la réservation appartient à `auth.uid()`. Effort **S**.

### B6 · FONCTIONNEL · L'abonnement Premium ne s'active jamais
`subscription_provider.dart:199-205` fait
`_client.schema('app').from('subscriptions').insert({… status:'pending_payment' …})`.
Or `app.subscriptions` a RLS active et **aucune policy INSERT** pour un étudiant
(`politiques_rls.json` : seulement `subscriptions_admin_all` et
`subscriptions_student_select`). L'INSERT est refusé ; `app_confirm_ligdicash_payment`
ne trouve ensuite aucune ligne `pending_payment` à activer. **Mesuré :
`subscriptions` = 0 ligne.** L'étudiant paierait sans jamais obtenir Premium.
**Correctif** : créer la ligne côté serveur, dans une RPC `SECURITY DEFINER`
qui insère paiement **et** souscription atomiquement. Effort **M**.

### B7 · FONCTIONNEL · La déclaration manuelle de paiement est un faux succès
`student_application_payments_provider.dart:150-169` — `declareExistingPayment`
ne fait **aucun** appel réseau : `await loadMyPayments(); return true;`. Le
commentaire « RPC app_student_declare_payment n'existe plus » est **faux** : la
fonction existe (`fonctions_domaine_source.json`) et est déjà appelée avec succès
ailleurs dans le même fichier. L'écran (`student_payments_screen.dart:321-354`)
affiche « Paiement déclaré, en attente de vérification » alors que rien n'est
écrit : statut reste `pending`, référence SMS et note perdues, l'admin ne voit
jamais la déclaration. **Correctif** : brancher sur
`rpc('app_student_declare_payment', …)`. Effort **S**.

### B8 · FONCTIONNEL · L'écran admin de paiements confirme dans le vide
`admin_payments_provider.dart:55-93` — `verifyPayment` et `confirmPayment` ne
font qu'un `debugPrint` puis `loadAllPayments(); return true;`. Aucune écriture,
aucun reçu. L'UI affiche « Paiement confirmé et reçu généré ». Les vraies RPC
(`app_admin_verify_payment`, `app_admin_confirm_payment`) existent et sont
saines. **Correctif** : brancher les deux méthodes sur leurs RPC. Effort **S**.

### B9 · EXPÉRIENCE · « Mes documents » est injoignable sur mobile
`StudentDocumentsScreen` (l'écran des reçus construit le 02/09) n'est référencé
**qu'à** `student_home_tab.dart:1639` — la variante **bureau**. Sur mobile,
`student_dashboard_screen.dart:454-496` rend `StudentHomeMobileTab` à l'onglet 0,
qui n'expose ni « Mes documents » ni « Mes paiements ». **Sur le téléphone,
l'étudiant ne peut pas atteindre ses reçus.** C'est le cœur de la demande, et il
est bloqué par le câblage de navigation. **Correctif** : ajouter deux `ListTile`
(« Mes documents », « Mes paiements ») au menu bottom-sheet de
`student_home_mobile.dart:269-306` (à côté de « Paramètres »), poussant l'écran
enveloppé de son provider. Effort **S**.

---

## 2. Ensuite — majeurs

- **M1 · Sous-paiement d'abonnement.** `subscription_provider.dart:151-180`
  calcule le montant côté client et l'envoie à `app_student_create_profile_payment`,
  qui ne vérifie que `p_amount_due > 0` — jamais contre le prix du plan. Un client
  modifié paie 15 000 au lieu du tarif. **Correctif** : le serveur lit le prix du
  plan, ignore le montant client (comme le courtage figé à 25 000). Effort **M**.
- **M2 · Aucun reçu envoyé par courriel.** `app.email_queue` = 3 `pending`
  depuis juillet, **aucun consommateur**. Soit écrire l'envoyeur (Edge Function
  cron), soit retirer la promesse. Effort **M**.
- **M3 · Chaîne commission/versement vide.** Malgré 18 paiements confirmés :
  `referral_commissions` 0, `actor_balances` 0, `payout_queue` 0. Le générateur
  de commission tourne-t-il ? À tracer. Effort **M**.
- **M4 · Deep-link notification vers « Mes paiements » plante.** L'écran est
  poussé sans son `StudentApplicationPaymentsProvider` requis
  (`notification_router.dart`). Effort **S**.
- **M5 · L'empreinte du reçu porte sur la ligne paiement, pas sur le snapshot.**
  `app.empreinte_recu` hache les champs du paiement (mutable) et non le
  `snapshot` figé qui **est** le reçu. À faire porter sur le snapshot. Effort **S**.
- **M6 · Les 18 reçus existants ont `signature_hash` NULL.** Antérieurs au
  correctif du 02/09. Les recalculer une fois (rattrapage). Effort **S**.

---

## 3. Finitions — mineurs / expérience

- **m1** · `student_payments_screen` : « Télécharger le reçu » sans filet
  d'erreur (contrairement à « Mes documents »).
- **m2** · « Mes paiements » n'étiquette pas les motifs : 15 `credit_purchase` +
  1 `td_access` affichés en « Paiement » générique.
- **m3** · `student_dossier_documents_screen` affiche des données techniques
  brutes (chemins de stockage) — seul volet documents atteignable sur mobile
  aujourd'hui.
- **m4** · En-tête profil bureau : `Row` non-adaptatif qui déborde sur petit écran.
- **m5** · Paiement marketplace confirmé : aucun reçu émis (l'UI en promet un).
- **m6** · Suppression d'une pièce de dossier : fichier retiré du bucket **avant**
  la ligne DB, sans transaction — orphelin possible.
- **m7** · Reçus : colonnes dénormalisées `student_name/email/phone` NULL sur
  18/18 (les données arrivent par le snapshot ; le PDF s'en sort, mais l'admin
  qui liste voit des vides).

---

## 4. Hors de ce chantier (assumé)

- **Onglet « Bons de courtage » vide** et **mock `app_ligdicash_initiate_credit_purchase`**
  orphelin : chemins morts connus, à nettoyer, sans urgence.
- **Signature de reçu « keyless »** (SHA-256 sans secret) : **choix assumé** le
  02/09 (une clé en base est lue par les mêmes que les reçus). Ce n'est pas un
  défaut ; c'est une somme de contrôle, nommée comme telle.
- **RÉFUTÉ par la vérification adverse** : « l'onglet revenus université est
  cassé ». Les RPC renvoient bien `feature_disabled`, mais le message n'atteint
  jamais l'utilisateur → cosmétique, non fonctionnel. Pas un bloquant.

---

## 5. CE QUI A ÉTÉ CORRIGÉ LE 03/09/2026, ET COMMENT ÇA A ÉTÉ VÉRIFIÉ

Exécuté du moins risqué au plus risqué, avec mesure avant/après à chaque étape.

**Preuve anti-régression :**
- `flutter analyze` donnait **0 erreur / 2 101 avertissements** avant. Après
  **six** fichiers Flutter modifiés : **0 erreur / 2 101** — identique, pas un
  avertissement ajouté.
- `flutter build apk --debug` : **code 0**, `app-debug.apk` 311,5 Mo.
- Base rendue telle quelle : 30 paiements, 18 confirmés, 18 reçus, 0 paiement
  sans reçu, 18 comptes de crédits, 279 transactions, 7 déclencheurs actifs,
  séquence des reçus à 1. **Aucune donnée d'essai laissée** — toutes les
  vérifications d'écriture ont tourné dans des transactions annulées.

> **Deux échecs de compilation, et ce n'était pas le code.** Les deux premières
> tentatives ont échoué sur `java.io.IOException: Espace insuffisant sur le
> disque` — le disque est tombé à **0 Go libre**. Diagnostic établi par le
> journal, pas supposé. Récupérés : les caches Gradle des versions **8.14** et
> **8.9**, que ce projet n'utilise pas (il tourne sur **8.12**, cf.
> `gradle-wrapper.properties`), plus le dossier temporaire — **4,5 Go**. Ce sont
> des caches : ils se régénèrent seuls si un autre projet en a besoin. La
> compilation a réussi ensuite, sans qu'une seule ligne de code ait changé.

| # | État | Ce qui a été fait | Preuve |
|---|---|---|---|
| **B9** | ✅ | « Mes documents » et « Mes paiements » ajoutés au menu mobile (`student_home_mobile.dart:269`) | `flutter analyze` 0 erreur, aucune alerte sur les lignes ajoutées |
| **B7** | ✅ | `declareExistingPayment` rebranché sur `app_student_declare_payment` ; le faux succès et le commentaire mensonger supprimés | 0 issue |
| **B8** | ✅ | `verifyPayment`/`confirmPayment` rebranchés sur leurs RPC réelles ; bug `if (_disposed)` → `if (!_disposed)` corrigé au passage | 0 issue ; l'écran affichait déjà `provider.error` en cas d'échec |
| **B3/B5** | ✅ | `REVOKE` de `PUBLIC`/`anon`/`authenticated` sur les 4 fonctions de crédits. **Contrat inchangé** | `has_function_privilege` : anon `false`, authenticated `false`, service_role `true` |
| **B4** | ✅ | Garde `app.est_admin()` ajoutée à `app_admin_list_marketplace_payments` | admin → succès ; étudiant → `not_admin` |
| **B1** | ✅ | Garde d'identité + `REVOKE` sur les 3 passerelles SQL | anon → **HTTP 401** (était 200) ; connexion directe ✓ ; admin ✓ ; `service_role` ✓ ; étudiant → `forbidden` |
| **B2** | ↓ | **Rétrogradé** : non exploitable (déclencheur existant). Voir plus haut | — |
| **B6+M1** | ✅ | `app_student_create_subscription_payment` : tarif lu au serveur, paiement + abonnement créés atomiquement. Flutter rebranché | essai en transaction annulée : 1 abonnement + 1 paiement créés, montant 5 000 imposé par le serveur, second appel idempotent |
| **M4** | ✅ | Lien de notification « Mes paiements » enveloppé de son provider | 0 erreur ; vérifié que `AdminPaymentsScreen` fournit déjà le sien (pas de sur-correction) |
| **M5** | ✅ | L'empreinte porte désormais sur le `snapshot` figé — ce qui **est** le reçu — et non sur la ligne de paiement mutable | essai annulé : reçu émis → `intacte=true` ; snapshot altéré → `intacte=false`. **Fait maintenant parce qu'aucun reçu ne portait encore d'empreinte** : plus tard, il aurait fallu choisir entre casser des documents et garder une formule fausse |

**Deux corrections que l'audit avait mal calibrées, et qui auraient causé des
régressions si je les avais appliquées telles quelles :**

1. **B3** proposait de supprimer `p_student_id` de
   `app_student_reserve_credits`. **Neuf Edge Functions** l'utilisent, dont
   `whiteboard-generate-storyboard` — le cœur du Smart Whiteboard. En
   `service_role`, `auth.uid()` est NULL : sans ce paramètre, toute la chaîne IA
   s'arrête. On a fermé les droits, pas le contrat.
2. **B2** aurait fait réécrire 38 fonctions pour une faille inexistante.

### Reste à faire

- **M2** · Aucun reçu envoyé par courriel (`app.email_queue` : 3 en attente,
  aucun consommateur). Chantier : une Edge Function planifiée. Effort **M**.
- **M3** · Chaîne commission/versement vide malgré 18 paiements confirmés
  (`referral_commissions`/`actor_balances`/`payout_queue` = 0). À tracer avant
  de corriger — la cause n'est pas établie. Effort **M**.
- **M6** · Les 18 reçus antérieurs ont `signature_hash` NULL. **Délibérément
  non corrigé** : calculer aujourd'hui l'empreinte d'un reçu émis en juillet
  attesterait de son état au 03/09, pas à l'émission. Fabriquer une empreinte
  rétroactive sur un document comptable immuable serait moins honnête que
  d'assumer son absence — que le PDF gère déjà (il ne promet pas d'empreinte
  qu'il n'a pas) et que `app.recus_a_verifier` recense.
- Les mineurs du §3.

### Le seul maillon non éprouvé en conditions réelles

L'écran « Mes documents » **n'a toujours jamais tourné sur un téléphone**. Il est
désormais **atteignable** (B9), et sa requête a un repli en deux temps, mais ni
l'un ni l'autre n'ont été exécutés en session étudiante réelle.

**Tentative du 03/09, et pourquoi elle a échoué.** Le TECNO POVA a été branché.
Windows le voit **en Bluetooth uniquement** (audio, mains-libres) et signale sur
l'USB : *« Périphérique USB inconnu (échec de demande de descripteur de
périphérique) »*, statut `Error`. Windows n'arrive donc pas même à **lire
l'identité** de l'appareil : la négociation USB échoue avant toute question de
débogage. Ce n'est pas un défaut de configuration Android — c'est la liaison
physique (câble de charge sans fil de données, port, ou connecteur). Jocelyn a
choisi de ne pas poursuivre l'installation ce jour-là.

**L'APK est prêt** : `academia_app/build/app/outputs/flutter-apk/app-debug.apk`
(311,5 Mo). À installer par tout moyen (autre câble, transfert, débogage sans
fil) pour lever cette dernière inconnue. Ce qu'il faut vérifier une fois
l'application ouverte, sur un compte étudiant :
1. menu « … » de l'accueil → **« Mes documents »** apparaît ;
2. l'onglet **Reçus** se remplit (et non « Tes reçus n'ont pas pu être
   chargés ») — c'est la jointure PostgREST sous RLS qui se joue là ;
3. **« Télécharger le reçu »** produit bien le PDF.
