# Onglets Cours et Lives — audit et architecture proposée

**Date** : 26 juillet 2026
**Contexte** : dégel des deux onglets étudiant en vue du premier test réel du Studio Live
**Références** : `RAPPORT_VAGUE_0_STUDIO_LIVE_2026-07-26.md`, `ARCHITECTURE_STUDIO_LIVE_V1.md`, `academia_app/docs/ARCHITECTURE_ACADEMIA_SESSION.md`, `LEARNING_ENGINE_DELIVERABLES.md`

---

## 1. Réponse directe : où en est le gel

Les deux onglets sont **dégelés dans le code** depuis la vague 0 — `StudentComingSoonTab` a été remplacé par `StudentCoursesTab` et `StudentLiveSessionsTab`, sur les branches mobile et desktop.

Mais vous avez raison sur le fond : **tant que l'application n'est pas rebâtie et redéployée, vos utilisateurs voient toujours l'ancienne version gelée.** Le dégel est dans le dépôt, pas encore dans les mains des gens.

Et il y a plus gênant. Le dégel seul ne suffira pas à tester le Studio Live, pour trois raisons que l'audit vient de mettre au jour.

---

## 2. Ce qui existe réellement sous les deux onglets

### 2.1 Onglet Cours — `StudentCoursesTab`

Écran fonctionnel, trois sections, filtres par type et recherche :

| Section | Source | Contenu réel |
|---|---|---|
| Bibliothèque de ressources | `StudentCourseLibraryProvider` | 5 ressources |
| Catalogue de cours en ligne | `OnlineCoursesCatalogProvider` | 3 cours |
| Mes cours | `StudentOnlineCoursesProvider` | 3 inscriptions |

**Ce que l'audit de la base révèle :**

| Table | Lignes |
|---|---|
| `online_courses` | 3 — **toutes avec `is_published = false`** |
| `online_course_sections` | **0** |
| `online_course_lessons` | **0** |
| `online_course_lesson_progress` | **0** |
| `online_course_certificates` | **0** |

Les trois cours s'appellent « actuariat », « math » et « Actuariat ». Aucun n'est publié, aucun n'a la moindre section ni leçon.

**Conséquence** : un étudiant qui ouvre l'onglet Cours aujourd'hui verra un catalogue **vide** — le filtre de publication écarte les trois — et, s'il est inscrit, un cours qui ne contient rien.

### 2.2 Onglet Lives — `StudentLiveSessionsTab`

Écran fonctionnel : grille responsive 1/2/3 colonnes, titre, cours d'origine, fournisseur, horaire, statut, bouton « Rejoindre » ou « LIVE », repli sur lien externe ou replay.

**Mais il lit la mauvaise source.** Il appelle `app_student_list_my_online_course_live_sessions`, qui interroge la table **legacy** `online_course_live_sessions` — 1 ligne, intitulée « exo », programmée le 29 novembre 2025.

Il ne voit pas `academia_sessions`, le moteur unifié.

**Et il fabrique une session factice.** Au clic sur « Rejoindre », il construit à la volée un objet `AcademiaSession` avec `hostId: ''`, `type: course` et `status: running` codés en dur, puis ouvre `AcademiaClassroomScreen`. Cela fonctionne uniquement parce que `livekit-token` retombe sur le chemin legacy. C'est un contournement, pas une intégration.

---

## 3. Le trou architectural, et pourquoi il bloque votre test

Voici le constat central de cet audit.

> **Rien, dans toute l'application, n'écrit dans `academia_sessions`. Et rien, côté étudiant, ne la lit.**

Vérifié appel par appel :

| RPC du moteur unifié | Appelée par |
|---|---|
| `app_learning_upsert_session` (créer) | `AcademiaSessionProvider` — **et ce provider n'est utilisé par aucun écran de création** |
| `app_learning_list_available_sessions` (lister côté étudiant) | `AcademiaSessionProvider` — **jamais appelé depuis un écran** |

Les deux écrans enseignants qui créent des sessions passent par les chemins legacy :

- `instructor_dashboard_screen.dart` → `app_ci_upsert_online_course_live_session` → table `online_course_live_sessions`
- `teacher_prep_live_sessions_screen.dart` → `app_prep_teacher_upsert_live_session` → table `prep_live_sessions`

`AcademiaSessionProvider` n'est branché qu'à un seul endroit : `TdEnrollmentAccessScreen`, en lecture.

**Voilà pourquoi `academia_sessions` compte 0 ligne.** Ce n'est pas un défaut de déploiement : la table n'a simplement aucun producteur ni consommateur.

### Ce que cela implique pour le test

Si vous lancez un live aujourd'hui par le chemin legacy, vous obtiendrez la vidéo et l'audio — le token fonctionne, je l'ai prouvé. Mais :

- **le chat persistant sera rejeté.** Les RPC que j'ai créées en vague 0 vérifient l'appartenance via `academia_sessions`. Une session legacy n'y a pas de ligne, donc `app_learning_send_message` répondra « Vous ne participez pas à cette session. »
- le registre de présence, le suivi de séance, le futur replay et les quiz seront dans le même cas.

Autrement dit : **le chemin legacy teste LiveKit, pas le Studio Live.**

---

## 4. Architecture proposée — onglet Cours

### 4.1 Principe

Aujourd'hui l'onglet est un **catalogue**. Il doit devenir un **espace d'apprentissage** : ce qui compte en haut n'est pas ce qu'on peut acheter, c'est ce qu'on est en train d'apprendre.

Trois niveaux, pas davantage.

```
Niveau 1 — Accueil Cours (hub)
   ├─ Reprendre où j'en étais        ← la seule chose au-dessus de la ligne de flottaison
   ├─ Séance en direct maintenant     ← bandeau rouge, si applicable
   ├─ Mes cours (progression)
   ├─ Catalogue
   └─ Bibliothèque de ressources

Niveau 2 — Détail d'un cours
   ├─ En-tête : titre, formateur, progression, certificat
   ├─ Onglet Programme    : sections → leçons, coché au fur et à mesure
   ├─ Onglet Séances live : à venir · en direct · replays
   ├─ Onglet Ressources   : documents, corrigés
   └─ Onglet Forum        : questions aux autres et au formateur

Niveau 3 — Lecteur de leçon
   ├─ Vidéo, audio ou document selon le type
   ├─ Panneau Notes ancrées au temps
   ├─ Exercices de la leçon
   └─ Bouton « Demander de l'aide »  ← ouvre le Studio en mode consultation
```

### 4.2 Ce qui manque côté données

| Manque | Effet | À faire |
|---|---|---|
| `online_course_sections` et `lessons` vides | Le niveau 3 n'a rien à afficher | Créer un cours de démonstration complet |
| `is_published = false` sur les 3 cours | Catalogue vide pour l'étudiant | Publier au moins un cours |
| `lesson_progress` jamais alimenté | « Reprendre où j'en étais » impossible | Brancher `app_student_update_lesson_progress`, qui **existe déjà** en base |

Bonne nouvelle : les RPC nécessaires au niveau 2 et 3 existent presque toutes — `app_public_get_online_course_detail`, `app_student_update_lesson_progress`, `app_student_list_online_course_forum_threads`, `app_list_course_exercises`. Le travail est d'interface, pas de backend.

### 4.3 Le point de jonction avec le Studio

Chaque leçon et chaque cours porte un appel au Studio, avec son contexte :

```dart
// Depuis le détail du cours — séance planifiée
StudioLauncher.open(mode: classroom,
  origin: {module: 'course', entityId: courseId});

// Depuis le lecteur de leçon — l'étudiant bloque
StudioLauncher.open(mode: consultation,
  origin: {module: 'course', entityId: courseId, lessonId: lessonId});
```

C'est ce qui rend le Studio réutilisable plutôt que dupliqué.

---

## 5. Architecture proposée — onglet Lives

### 5.1 Principe

L'onglet actuel est une liste plate d'un seul type de session. Il doit devenir **le point d'entrée unique de tout ce qui est en direct sur Academia**, quel que soit le module d'origine.

```
┌─────────────────────────────────────────────────────┐
│  ● EN DIRECT MAINTENANT                             │  bandeau rouge, en haut,
│  Correction des exercices · Prof. Sylvie · 28 présents │  seulement s'il y en a
│                                        [ Rejoindre ] │
└─────────────────────────────────────────────────────┘

  Filtres :  Tout · Cours · TD · Prépa concours · Orientation

  AUJOURD'HUI
   18h00  Atelier — préparation du devoir       TD      [Rappel]
   20h30  Révision collective — Bac D           Prépa   [Rappel]

  CETTE SEMAINE
   Jeu 30  Masterclass actuariat                Cours   [Rappel]

  REPLAYS
   21 juil.  Introduction aux suites   1 h 04   ▶ transcript · résumé · quiz
```

### 5.2 Source de données — le changement décisif

| | Aujourd'hui | Proposé |
|---|---|---|
| RPC | `app_student_list_my_online_course_live_sessions` | **`app_learning_list_available_sessions`** |
| Table | `online_course_live_sessions` (legacy) | `academia_sessions` (unifié) |
| Portée | cours en ligne uniquement | cours, TD, prépa, orientation, communauté |
| Session ouverte | objet factice construit dans l'écran | objet réel renvoyé par la base |

`app_learning_list_available_sessions(p_session_type)` **existe déjà** et filtre correctement : un étudiant ne voit que les séances TD de son programme, un enseignant voit les siennes.

Pendant la transition, l'onglet peut fusionner les deux sources et marquer les sessions legacy d'un discret badge — le temps que la convergence prévue en section 5.4 de l'architecture du Studio soit faite.

### 5.3 Ce qui manque côté enseignant

C'est le vrai chaînon absent. Il faut **un écran de création de séance branché sur le moteur unifié** :

```
Créer une séance en direct
├─ Type      : Cours · TD · Prépa concours · Orientation · Masterclass
├─ Rattacher : (le cours ou le programme concerné)
├─ Titre, description
├─ Date et heure de début, durée
├─ Mode      : Classe · Amphi · Atelier · Consultation
├─ Options   : chat · quiz · tableau blanc · partage d'écran · enregistrement
└─ [ Créer ]  →  app_learning_upsert_session
```

`AcademiaSessionProvider.upsertSession` est déjà écrit et fonctionnel. Il ne lui manque qu'un formulaire.

---

## 6. Le chemin le plus court vers votre test

Vous voulez tester le Studio Live. Voici les deux options, honnêtement comparées.

### Option A — test partiel, aujourd'hui, sans code

Créer une séance par l'écran enseignant existant (Cours en ligne), avec `provider = livekit` et statut `approved`.

- ✅ Vidéo, audio, partage d'écran, réactions, tableau blanc, participants
- ❌ Chat persistant, registre de présence, quiz, replay — tout ce qui dépend de `academia_sessions`

**Verdict** : cela teste LiveKit et confirme la bascule Cloud. Cela ne teste pas le Studio.

### Option B — test complet, après une demi-journée de travail

Trois éléments à livrer :

1. **Écran enseignant « Créer une séance »** branché sur `app_learning_upsert_session` (le provider existe, il faut le formulaire)
2. **Onglet Lives** repointé sur `app_learning_list_available_sessions`, avec fusion legacy pendant la transition
3. **Un cours de démonstration publié**, avec 2 sections et 4 leçons, pour que l'onglet Cours ne soit pas vide

- ✅ Tout le Studio, chat persistant compris
- ✅ Le parcours réel que vivront vos utilisateurs

**Verdict** : c'est le test qui a de la valeur. Et ces trois éléments sont de toute façon au programme de la vague 1.

**Ma recommandation : option B.** L'option A vous donnera une belle image vidéo et un faux sentiment de validation — puis le premier vrai usage butera sur le chat.

---

## 7. Plan proposé

### Étape immédiate — rendre le dégel visible (vous)

`flutter analyze`, puis build et déploiement. Sans cela, rien de ce qui précède n'atteint vos utilisateurs.

### Vague 1a — le minimum pour tester (une demi-journée)

1. Écran enseignant « Créer une séance en direct » → moteur unifié
2. Onglet Lives repointé sur `app_learning_list_available_sessions`
3. Jeu de démonstration : 1 cours publié, 2 sections, 4 leçons, 1 séance planifiée

### Vague 1b — le socle Studio (1 à 2 semaines)

4. `StudioLauncher` et la matrice de capacités
5. **Droits de publication** — aujourd'hui `canPublish: isHost`, les étudiants ne peuvent pas parler en classe
6. **Contrôle d'accès aux salles** — aujourd'hui un identifiant suffit pour entrer
7. Refonte de `AcademiaClassroomScreen` en `StudioShell` + modules

### Vague 1c — les deux onglets à leur cible

8. Onglet Cours à trois niveaux, avec « Reprendre où j'en étais »
9. Lecteur de leçon avec notes et bouton d'aide
10. Onglet Lives complet : en direct, à venir, replays, filtres par module

---

## 8. Ce qu'il faut retenir

Le dégel des onglets était nécessaire, il est fait dans le code. Mais il a révélé quelque chose de plus important : **les deux onglets étaient gelés parce qu'ils n'avaient rien à montrer**, et cela reste vrai aujourd'hui.

L'onglet Cours pointe vers trois cours non publiés et sans leçons. L'onglet Lives pointe vers la mauvaise table. Le moteur unifié, que la vague 0 vient de rendre opérationnel de bout en bout jusqu'au SFU, n'a ni écran qui l'alimente ni écran qui le lit.

La bonne nouvelle est que le manquant est petit et bien cerné : un formulaire de création, un changement de RPC dans une liste, et un cours de démonstration. Une demi-journée sépare le projet de son premier vrai live — au sens complet, chat et présence compris.
