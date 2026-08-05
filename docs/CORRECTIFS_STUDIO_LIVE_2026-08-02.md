# Correctifs Studio Live — vérification de l'audit et mise en œuvre (02/08/2026)

> Fait suite à `AUDIT_FLUX_STUDIO_TOUS_ROLES_2026-08-02.md`. Chaque affirmation
> de cet audit a été revérifiée sur le code **et sur la production** avant toute
> correction. Trois de ses constats étaient faux ; deux défauts qu'il ne voyait
> pas ont été trouvés.

---

## Le constat qui change tout : le dépôt ne reflétait pas la production

L'audit concluait que « l'étudiant ne peut jamais parler », en s'appuyant sur
`supabase/functions/livekit-token/index.ts`. **Ce fichier n'était pas ce qui
tournait.** La fonction déployée (v67, 30/07/2026) dérivait déjà le droit de
parole du type de séance. Le correctif du 30/07 avait été **déployé sans jamais
être committé**.

Ampleur mesurée : **neuf fonctions Edge déployées n'avaient aucune source dans
git**, et `livekit-token` y était périmée. Un `supabase functions deploy
livekit-token` fait de bonne foi aurait **rendu l'étudiant muet en orientation**.

C'est aussi ce qui a coûté l'audit : lire le dépôt ne suffisait pas.

---

## Ce qui a été corrigé

### P0 — Réalignement dépôt / production
Rapatriées dans git : `livekit-moderate`, `livekit-env-diag`,
`orientation-analyser`, `orientation-result`, `orientation-lead`,
`content-watermark`, `manager-create-commercial-account`,
`admin-create-orientation-counselor`,
`admin-promote-to-orientation-counselor`. `livekit-token` remise à la v67 réelle.

### P1 — Trous du correctif du 30/07 *(déployé v68)*
`BIDIRECTIONAL_KINDS` contenait quatre valeurs **inatteignables**
(`consultation`, `workshop`, `atelier`, `tutoring` — absentes de
`academia_sessions_session_type_check` comme de `livekit_lookup_session`), et
omettait `revision_collective` : ses participants recevaient un jeton muet.
Découvert au passage : un **défi en mode `duo`** est un face-à-face, et le
second joueur était muet lui aussi. Corrigé par `BIDIRECTIONAL_GAME_MODES`.
`revision_collective` ajouté au filtre étudiant, avec mention de valeur couplée
des deux côtés.

### P2 — Écran admin et source de vérité `isHost`
`admin_live_sessions_screen` **fabriquait** une `AcademiaSession` (type forcé à
`course`, `hostId` forcé à l'administrateur, `isHost: true`) — alors que cet
écran pilote les séances **historiques**. Conséquence non vue par l'audit :
`_cleanup()` appelait `endSession()` **à la simple fermeture de l'écran**.
Le classroom lit désormais `is_host` du jeton (`_isHost`) pour tout ce qui suit
la connexion ; `widget.isHost` ne sert plus qu'avant l'obtention du jeton.

### P3 — Boucle de la synthèse fermée
Mesuré : 7 séances terminées, **0 synthèse, 0 événement**. Trois causes, dont
une que l'audit désignait à tort : `AcademiaObservability` visait
`public.academia_session_events` — table qui n'existe que dans le schéma `app`,
avec des colonnes qui ne sont pas les siennes. **Elle n'aurait jamais rien
écrit.** Supprimée au profit de `app_learning_log_event`.
Journalisation branchée (`seance_demarree`, `main_levee`, `quiz_envoye`,
`partage_ecran_demarre`, `enregistrement_demarre`, `seance_terminee`), fin de
séance menant à la fiche, et portes d'entrée ouvertes pour l'enseignant, le
conseiller et l'étudiant.

### P4 — Contrôle d'accès *(migration appliquée)*
`app_learning_join_session` ne vérifiait **rien**. Elle contrôle désormais le
statut et `max_participants`. Un participant déjà inscrit repasse même si la
salle est pleine — sans quoi une coupure réseau expulserait définitivement.
Côté application, le refus était **invisible** : le service avalait l'échec et
l'écran ignorait son résultat. Corrigé.
L'audit Supabase signalait par ailleurs cette fonction `SECURITY DEFINER`
appelable sans connexion : `EXECUTE` retiré à `anon` et `PUBLIC`.

### P5 — Doublons
Supprimés : `livekit_room_screen.dart` (orphelin), `orientation_screen.dart`
(inatteignable — `auth_wrapper:363` route le conseiller ailleurs),
`features/university/sedaLV1XI` (copie octet pour octet de
`university_dashboard_screen.dart`, 216 Ko).
**`OrientationBookingSheet` extraite au préalable** dans son propre fichier :
elle vivait dans `orientation_screen.dart` et porte la case de consentement à
l'enregistrement. La supprimer aurait cassé la réservation étudiante — ce que
la recommandation initiale de l'audit aurait provoqué.

### P6 — Clé `service_role` hors des tâches planifiées *(appliqué)*
La clé était en clair dans **5 tâches cron** (6, 8, 9, 13, 15 ; deux fois dans
6 et 9) et dans **13 417 lignes** de `cron.job_run_details`.
Déplacée dans Vault, extraite par la base elle-même — la valeur n'a transité par
aucun outil. Les tâches passent par `app.appeler_fonction_edge`, en
`SECURITY INVOKER` et exécutable par `postgres` seul : un `SECURITY DEFINER`
aurait remplacé une clé mal rangée par une porte dérobée.
Historique **caviardé plutôt que supprimé** : le secret s'en va, les 198 368
lignes de traçabilité restent.

---

## Ce que l'audit affirmait à tort

| Affirmation | Réalité |
|---|---|
| L'étudiant ne peut jamais parler | Corrigé et déployé le 30/07 ; le dépôt était périmé |
| L'administrateur « croit animer, il ne fait rien » | Il publie et modère depuis le 30/07 ; le vrai défaut était l'appel à `endSession` en partant |
| Régression du consentement dans `StudentOrientationTab` | Faux : l'onglet délègue à `OrientationBookingSheet`, qui porte la case |
| Brancher `AcademiaObservability` | N'aurait rien produit : mauvaise table, mauvaises colonnes |
| « 0 message » = chaîne cassée | Le chat persiste bien ; personne n'avait écrit en 7 séances de test |
| Clé exposée dans `studio-orchestrateur` | 5 tâches, pas une ; mais `cron.job` n'est lisible que par `postgres` |

---

## Reste ouvert

1. **La clé `service_role` n'a pas été régénérée** (choix explicite). Elle
   demeure valide et présente dans les sauvegardes antérieures au 02/08. La
   rotation suppose de recenser d'abord toutes les intégrations qui l'utilisent.
2. **L'administrateur ne peut pas lire les fiches de séance** :
   `app_learning_get_summary` exige d'avoir participé, et le jeton n'inscrit
   délibérément pas l'administrateur. Lui ouvrir l'accès poserait une question
   de fond — la version `host` d'un entretien d'orientation contient les
   `notes_internes` du conseiller sur un élève mineur. **Décision produit, pas
   correctif technique.**
3. **Inscription et paiement** ne sont toujours pas vérifiés à l'entrée d'une
   salle. Les règles diffèrent par parcours (TD ↔ `td_enrollments`, prépa ↔
   abonnement, orientation ↔ réservation) : à traiter parcours par parcours.
4. **Dossier Play Store** : voir
   `PLAY_STORE_DONNEES_CONFIDENTIALITE_MINEURS_2026-08-02.md`. Le point le plus
   lourd n'est pas technique — c'est la position à tenir sur les consultations
   individuelles adulte ↔ mineur.

---

## Vérifications effectuées

- `flutter analyze` sur tout le projet : **aucune erreur**.
- `livekit-token` v68 déployée, contenu comparé au dépôt : identique.
- Migration `app_learning_join_session` appliquée, `GRANT` contrôlés.
- Chaîne Vault essayée en réel sur `runpod-watchdog` : **HTTP 200**.
- Les 5 tâches rebranchées tournent : 28 réponses HTTP 200 en 15 minutes.
- Aucune clé en clair ne subsiste dans `cron.job` ni `cron.job_run_details`.
