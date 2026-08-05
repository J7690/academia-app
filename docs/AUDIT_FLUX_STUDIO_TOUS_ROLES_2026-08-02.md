# Audit des flux du Studio Live — quatre rôles, tous les types de séance

**Date :** 2 août 2026
**Périmètre :** conseiller, enseignant, administrateur, étudiant · types cours, TD, prépa concours, orientation, masterclass, révision collective.
**Nature :** audit en lecture seule. Aucune modification apportée.

---

## 1. Le constat le plus lourd : l'étudiant ne peut jamais parler

`livekit-token/index.ts`, ligne 218 :

```
canPublish: isHost,
canSubscribe: true,
```

Un seul booléen gouverne toute la plateforme. **Quiconque n'est pas l'hôte reçoit un jeton qui interdit de publier micro et caméra**, quel que soit le type de séance.

C'est défendable pour un cours magistral, une masterclass, une conférence. C'est tenable nulle part ailleurs :

| Type | Ce qui se passe aujourd'hui |
|---|---|
| **Orientation** | L'élève entre dans un tête-à-tête où **il ne peut pas répondre à son conseiller**. Toute la chaîne que nous venons de construire aboutit à un entretien muet d'un côté. |
| **TD** | L'atelier interdit à l'étudiant de présenter son travail. |
| **Révision collective** | Même chose : personne ne révise collectivement en silence. |
| **Examen blanc** | Défendable. |

L'interface, elle, affiche les boutons micro et caméra à l'étudiant (`AcademiaStudentControls` expose `onToggleMic` et `onToggleCamera`). Il appuie, rien ne se passe, aucun message ne l'explique.

**Ce qu'il faudrait :** dériver les droits du type de séance et du rôle du participant, pas d'un unique `isHost`. Un modèle à trois niveaux — *diffuseur* (hôte), *intervenant* (peut publier sur autorisation), *spectateur* — couvrirait les six types sans exception. La table `academia_session_participants` porte déjà une colonne `role` (`host`, `co_host`, `participant`, `observer`) : elle est écrite, jamais lue par la fonction jeton.

---

## 2. Le miroir hôte/participant est déclaré côté client, calculé côté serveur — et les deux divergent

`isHost` est passé en dur à l'écran de salle dans **quinze** des seize points d'entrée. Un seul le calcule : `student_live_sessions_tab.dart:93` (`myId == session.hostId`).

Le serveur, lui, le recalcule toujours : `isHost = user.id === sessionData.host_id`.

Conséquence démontrable : `admin_live_sessions_screen.dart:364` passe `isHost: true` pour un administrateur. S'il n'est pas l'hôte enregistré de la séance, il obtient une interface d'hôte complète — micro, caméra, partage d'écran, bouton *terminer la séance* — servie par un jeton qui refuse tout. **L'administrateur croit animer, il ne fait rien.**

L'autre écran admin (`admin_studio_live_screen.dart:165`) passe `isHost: false` et supervise correctement. Les deux coexistent sans que rien n'indique lequel employer.

**Ce qu'il faudrait :** l'écran de salle ne devrait pas *recevoir* `isHost` mais le *lire* dans la réponse du jeton — le champ `is_host` y figure déjà, ligne 253. Une seule source de vérité, celle du serveur.

---

## 3. La synthèse IA : tout est construit, rien n'est atteignable

C'est le point qui vous tient à cœur, et c'est celui où l'écart est le plus net.

**Mesure en base, aujourd'hui :**

| Indicateur | Valeur |
|---|---|
| Séances terminées | 7 |
| Synthèses générées | **0** |
| Messages de chat | **0** |
| Événements de séance | **0** |

Trois causes, empilées :

**a) Aucun rôle ne peut ouvrir l'écran.** `SessionSummaryScreen` existe, sait afficher les deux versions et produire le PDF — et n'est **instancié nulle part** dans l'application. Ni l'enseignant, ni le conseiller, ni l'étudiant, ni l'administrateur n'y accède.

**b) Rien ne déclenche la génération.** Aucun déclencheur sur `academia_sessions`, aucune tâche planifiée, aucun appel Flutter à la fin d'une séance. `app_learning_end_session` pose bien `actual_end`, puis la chaîne s'arrête là.

**c) La matière première n'est pas collectée.** La fonction refuse de résumer une séance sans message ni événement. Or `AcademiaObservability` — qui sait journaliser connexion, déconnexion, erreur et qualité — n'est appelé par **aucun** fichier. Le journal d'événements reste vide par construction.

Le socle, lui, est sain : la table `academia_session_summaries` distingue déjà `audience` ∈ {`student`, `host`} et porte `is_published`, la version hôte contient les statistiques et les notes internes, la version élève ne les contient pas. **La séparation par rôle que vous décrivez existe déjà en base ; c'est la porte d'entrée qui manque.**

Le crédit OpenRouter n'est donc jamais consommé — non par économie, mais parce que rien n'appelle la fonction.

---

## 4. Écrans en double et écrans orphelins

**Une régression sur le consentement.** Le tableau de bord étudiant pointe désormais vers `StudentOrientationTab` (941 lignes, avec test psychotechnique) et non plus vers `OrientationScreen` (1 565 lignes). Or la case *« j'accepte que l'entretien soit enregistré »* ajoutée au lot D vit dans `OrientationScreen`. `StudentOrientationTab` appelle `book()` **sans** le paramètre de consentement : l'élève réserve toujours avec `consent_recording = false`, et l'enregistrement ne pourra jamais s'activer, même si le conseiller le demande.

`OrientationScreen` n'est plus atteint que par une branche morte (`if (orientation.isCounselor)` — or un conseiller est routé vers son propre tableau de bord).

**Autres doublons :**

- `livekit_room_screen.dart` — orphelin, aucun appelant.
- `admin_live_sessions_screen` (crée, `isHost: true`) et `admin_studio_live_screen` (supervise, `isHost: false`) coexistent.
- Le mot **« Studio »** désigne deux dispositifs sans rapport : le Studio Live (LiveKit) et le Studio visuel (RunPod/Blender, tâche `studio-orchestrateur` toutes les trois minutes). Toute consigne parlant du « studio » est ambiguë.

**Couverture des types :** l'enseignant peut créer cours, TD, prépa, masterclass, révision collective — l'orientation en est bien retirée, comme demandé. Mais le filtre de l'onglet Lives étudiant ne connaît pas `revision_collective` : une séance de ce type est créée, publiée, et reste invisible au filtre.

---

## 5. Contrôle d'accès aux salles

Aucun contrôle d'appartenance : quiconque possède un identifiant de session obtient un jeton. Pas de vérification d'inscription, de paiement, ni de capacité maximale. `max_participants` est écrit en base et n'est lu par personne.

---

## 6. Play Store

**Ce qui est en ordre :**

- `ACCESS_FINE_LOCATION` et `AD_ID` explicitement retirés (`tools:node="remove"`) — deux déclarations lourdes évitées.
- `WRITE_EXTERNAL_STORAGE` borné à l'API 28.
- Service au premier plan correctement typé `mediaProjection`.

**Ce qui reste à faire avant publication :**

1. **Déclaration d'usage du partage d'écran** dans la Play Console — `FOREGROUND_SERVICE_MEDIA_PROJECTION` la rend obligatoire. Le dossier et le script de vidéo de démonstration sont prêts (`docs/PLAY_STORE_DECLARATION_MEDIA_PROJECTION.md`).
2. **Formulaire *Sécurité des données*** : l'application collecte audio et vidéo dès que l'enregistrement est activé. Il faut le déclarer, préciser que c'est facultatif et lié à une fonctionnalité. Le double consentement que nous avons mis en place est un argument favorable — il faut le documenter.
3. **Politique de confidentialité** : elle doit mentionner l'envoi du contenu de séance (chat, notes) à un prestataire d'inférence tiers (OpenRouter). C'est une communication de données personnelles à un tiers ; l'omettre est un motif fréquent de rejet.
4. **Contenu destiné aux enfants** : la plateforme vise des collégiens et lycéens. Si la tranche déclarée inclut les mineurs, les règles *Families* s'appliquent — et une visioconférence ouverte entre adultes et mineurs y est particulièrement scrutée. Le mode consultation individuelle adulte↔mineur mérite une position explicite avant soumission.

**Hors Play Store, mais sérieux :** un jeton `service_role` figure en clair dans la commande de la tâche planifiée `studio-orchestrateur`, lisible par quiconque accède à la base. À remplacer par un secret Vault.

---

## 7. Ce que je propose de faire, dans cet ordre

**P1 — Rendre la parole aux participants.** Droits dérivés du type de séance et du rôle du participant, lus depuis `academia_session_participants.role`. Sans cela, l'orientation et le TD ne fonctionnent pas.

**P2 — Une seule source de vérité pour `isHost`.** L'écran lit `is_host` de la réponse du jeton au lieu de le recevoir. Supprime d'un coup la divergence admin.

**P3 — Fermer la boucle de la synthèse.** Trois gestes : brancher `AcademiaObservability` sur les événements de salle ; déclencher la génération à la fin de séance ; ouvrir `SessionSummaryScreen` depuis les quatre rôles, chacun sur sa version (`host` pour l'animateur, `student` pour le participant, et seulement si publiée).

**P4 — Résorber les doublons.** Porter le consentement dans `StudentOrientationTab`, retirer `OrientationScreen` et `livekit_room_screen`, clarifier les deux écrans admin, renommer l'un des deux « Studio ».

**P5 — Contrôle d'accès aux salles** et respect de `max_participants`.

**P6 — Dossier Play Store** : déclaration media projection, sécurité des données, politique de confidentialité, position sur les mineurs.

Dites-moi si cet ordre vous convient, ou si la synthèse IA doit passer devant — c'est faisable, mais elle produira des comptes rendus de séances où l'élève n'a pas pu parler.
