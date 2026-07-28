# Studio de live du conseiller — les quatre lots exécutés

**Date :** 27 juillet 2026
**Ordre retenu :** A → B → C → D, puis vérification de bout en bout.

---

## Ce que fait désormais le conseiller

| Avant | Après |
|---|---|
| Il attendait qu'un élève réserve | Il ouvre ses propres séances, individuelles ou collectives |
| Pas de tableau blanc en consultation | Tableau blanc actif par défaut |
| Il quittait la salle pour lire le dossier | Dossier et fiche sous les yeux, pendant l'entretien |
| Résumé IA parlant de « concepts » | Compte rendu en pistes, échéances, démarches |
| Enregistrement coupé sans recours | Double consentement, bandeau permanent |
| Onglet Revenus figé à zéro | Revenus réels, versés automatiquement |

---

## Lot A — Le conseiller devient autonome

**Base**

- `app_orientation_create_session` — création et modification d'une séance par le conseiller lui-même. Deux formats : **individuelle** (2 places, main levée sans objet) et **collective** (3 à 200 places, main levée activée, tarif par place). Rôle vérifié : un élève qui l'appelle reçoit *« Réservé aux conseillers d'orientation. »*
- `app_orientation_my_sessions` — ses séances, tous statuts, avec le nombre d'inscrits.
- `app_orientation_book` corrigée : **le tableau blanc passe à `true`**. Il était désactivé « sans objet », alors qu'un arbre de filières ou un calendrier de concours se dessinent.

Le cycle de vie n'a **pas** été redéveloppé : `app_learning_set_session_status`, `start_session` et `end_session` s'appuient sur `host_id`, et le conseiller est l'hôte. Ils fonctionnent tels quels.

**Flutter**

- 6ᵉ onglet **« Mes séances »** (`counselor_sessions_tab.dart`), avec les champs propres à l'orientation : format, thème, niveau visé, places, tarif — et non la matière ni le type de concours du formulaire enseignant.
- `AcademiaRoomOptions.consultation` — quatrième profil LiveKit. **Simulcast désactivé à dessein** : avec deux participants, chacun affiche l'autre en grand, il n'existe aucun abonné à qui servir une couche basse. Encoder trois qualités consommerait CPU et upload pour rien — ce qui compte sur un entretien long et un téléphone d'entrée de gamme. `adaptiveStream` reste actif.
- `AcademiaRoomOptions.pourSeance()` choisit le profil selon le nombre de places.

---

## Lot B — Le contexte, dans la salle

**Base** — `app_orientation_session_context(session_id)` fait le pont session → rendez-vous et renvoie en **un seul aller-retour** le dossier de l'élève, la fiche en cours, et les fiches précédentes que l'élève a acceptées de partager. En visioconférence, chaque requête supplémentaire se paie en latence sur le flux vidéo.

**Flutter** — `orientation_context_panel.dart`, ouvert depuis la barre supérieure, réservé au conseiller hôte d'une séance d'orientation. Deux vues : *Dossier* et *Fiche*.

**Sauvegarde automatique toutes les 30 secondes**, et une dernière écriture à la fermeture du panneau. Un réseau mobile coupe ; perdre vingt minutes de notes parce que la salle s'est fermée aurait été inacceptable.

Le panneau referme le chat à l'ouverture : les deux occupent la même colonne.

---

## Lot C — Le compte rendu parle orientation

`learning-session-summary` bifurque désormais sur `session_type`.

**Consigne système dédiée**, qui insiste sur un point : *« tu n'inventes JAMAIS un établissement, une date de concours ou un dispositif de bourse qui n'aurait pas été évoqué — une information fausse en orientation engage l'avenir d'un élève. »*

**Clés produites** : `synthese`, `profil`, `pistes[{filiere, etablissement, pourquoi}]`, `echeances[{quoi, quand}]`, `documents_a_reunir`, `prochaines_etapes`, `points_de_vigilance`, `questions_sans_reponse`.

**Les notes du conseiller font autorité.** Elles sont injectées dans le prompt : le modèle structure et complète un travail humain, il ne le remplace pas.

**Le verrou « rien à résumer » a été assoupli** pour l'orientation. Un entretien peut se dérouler sans un seul message écrit — c'est une conversation. Exiger du chat aurait rendu la fonction inutilisable précisément là où elle sert le plus ; les notes du conseiller suffisent.

L'écran et le PDF affichent les nouvelles rubriques ; les indicateurs de suivi deviennent *pistes / échéances / étapes* au lieu de *questions sans réponse*. Les notes internes restent côté conseiller, jamais dans la version remise à l'élève.

---

## Lot D — Consentement et rémunération

### Consentement

`consent_recording` existait en base sans être ni lu ni écrit. Désormais :

- l'élève donne son accord **en réservant** (case décochée par défaut) ;
- le conseiller donne le sien **dans la salle** ;
- l'enregistrement ne s'active que si **les deux** ont consenti, et se coupe si l'un se rétracte ;
- un bandeau permanent occupe le haut de la salle — rouge quand l'enregistrement tourne, ambre quand un accord manque.

### Rémunération — et une incohérence corrigée en chemin

`app_orientation_complete_booking` clôturait le rendez-vous **sans jamais créditer le conseiller**. Son onglet Revenus serait resté à zéro quel que soit le travail accompli.

En le corrigeant, la vérification a révélé plus grave : **la plateforme ne fait pas accumuler de solde**. Le déclencheur `trg_auto_queue_payout` verse tout crédit directement dans `payout_queue` et remet `available_balance` à zéro. Or :

1. ce déclencheur **ne savait pas résoudre le téléphone d'un conseiller** — il connaissait `instructor`, `commercial`, `merchant`, pas `orientation_counselor`. Les versements partaient en `waiting_phone` sans raison ;
2. l'onglet Revenus lisait `available_balance` — donc affichait zéro **par construction**.

Correction, sans toucher au modèle de la plateforme : la branche manquante est ajoutée au déclencheur, `app_orientation_get_my_balance` renvoie l'état réel (total gagné, en cours de versement, bloqué faute de numéro, déjà versé), et `app_orientation_request_payout` devient *« enregistrer mon numéro »* — ce qui débloque d'un coup les versements en attente.

**Garde d'idempotence** sur les deux chemins de clôture : un double clic ne double pas la rémunération. Et un rendez-vous ne peut pas être clôturé par le chemin collectif — deux chemins créditeraient deux fois.

La séance collective facture **les participants réellement entrés**, pas les inscrits : on ne facture pas une place vide.

---

## Vérification

Parcours complet joué en base, puis effacé.

| # | Étape | Résultat |
|---|---|---|
| 1 | L'élève trouve le conseiller | 1 conseiller |
| 2 | Il réserve, avec consentement | OK |
| 3 | La consultation apparaît dans son onglet Lives | ✔ |
| 4 | Le conseiller ouvre le contexte en salle | dossier chargé, question affichée |
| 5 | Il rédige la fiche pendant l'entretien | ✔ |
| 6 | Double accord → enregistrement autorisé | ✔ |
| 7 | Clôture : il est crédité | 2 000 FCFA |
| 8-9 | Il crée puis publie une séance collective | ✔ |
| 10 | L'élève la voit dans son onglet Lives | ✔ |
| 11 | Clôture collective | 1 place × 1 000 = 1 000 FCFA |
| 12 | Revenus | gagné 3 000 · en cours 3 000 · bloqué 0 |
| 13 | Ses séances | 3 |
| 14 | L'administrateur supervise | réservable, 1 rdv, 1 fiche |
| 15 | Nettoyage | base rendue à son état initial |

**Contrat RPC :** 23 RPC d'orientation appelées par le code, **23 présentes en base, aucune orpheline dans un sens ni dans l'autre**.

**Syntaxe :** 13 fichiers touchés, tous équilibrés (analyseur lexical tenant compte des deux types de guillemets, des échappements et des commentaires).

**Adaptativité :** aucune largeur figée dans les fichiers d'orientation. Le panneau contexte prend presque tout l'écran sous 420 dp, une colonne au-delà. Le panneau de chat, figé à 280 px, ne laissait que 40 dp de vidéo sur un téléphone de 320 dp — il est désormais plafonné à 85 % de la largeur.

---

## Incident à signaler

En déployant la fonction de synthèse, j'ai d'abord envoyé un contenu factice, ce qui a mis la fonction hors service quelques minutes. Elle a été restaurée en v3 avec le code complet, et le fichier local a été resynchronisé avec le déployé. Aucune donnée n'a été touchée, mais la fonction a été inutilisable pendant l'intervalle.

---

## Ce qui reste

1. **`flutter pub get` puis `flutter analyze`** depuis Windows — le SDK du dépôt ne s'exécute pas dans l'environnement Linux. C'est la seule vérification que je n'ai pas pu mener.
2. **`app_instructor_request_payout` souffre du même défaut** que celui corrigé pour le conseiller : il exige `available_balance > 0`, que le versement automatique ramène toujours à zéro. L'enseignant reçoit donc `no_funds_available` en permanence. Défaut antérieur, hors du périmètre demandé — à traiter séparément.
3. Une séance d'orientation orpheline (« Original », terminée, 26 juillet) subsiste : vestige d'un essai manuel avec l'ancien formulaire enseignant. Sans effet.
4. **`conseille@gmail.com` reste sans spécialité ni créneau** — le jeu d'essai a été effacé. Le conseiller doit compléter son profil depuis son compte.

---

## Migrations appliquées

- `orientation_counselor_can_launch_sessions`
- `orientation_book_whiteboard_and_consent`
- `orientation_session_context_panel` + `fix_orientation_session_context_shared_column`
- `orientation_consent_and_collective_billing`
- `orientation_align_with_auto_payout_architecture`
- `add_admin_orientation_counselors_supervision` + `fix_admin_orientation_counselors_raise`

**Edge Function :** `learning-session-summary` v3.

**Fichiers Flutter créés :** `counselor_sessions_tab.dart`, `orientation_context_panel.dart`, `orientation_recording_banner.dart`.

**Modifiés :** `counselor_dashboard_screen.dart`, `orientation_screen.dart`, `orientation_provider.dart`, `academia_classroom_screen.dart`, `academia_room_options.dart`, `session_summary_screen.dart`, `student_dashboard_screen.dart`, `admin_accounts_screen.dart`.
