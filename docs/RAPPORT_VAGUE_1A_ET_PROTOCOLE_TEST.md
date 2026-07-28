# Vague 1a — Rapport d'exécution et protocole de recette

**Date** : 26 juillet 2026
**Objet** : rendre le Studio Live testable de bout en bout, chat persistant compris
**Méthode** : audit Flutter → audit Supabase → modification → vérification, à chaque étape

---

## 1. Résultat

| Étape | Objet | État |
|---|---|---|
| B.1 | Audit des contrats du moteur unifié | ✅ |
| B.2 | Écran enseignant de création de séance | ✅ |
| B.3 | Onglet Lives repointé sur le moteur unifié | ✅ |
| B.4 | Cours de démonstration publié | ✅ |
| B.5 | Vérification et protocole | ✅ |

**Trois bugs bloquants ont été trouvés en chemin.** Aucun n'était prévu, et chacun rendait impossible une opération que l'interface proposait pourtant.

---

## 2. Les trois bugs découverts

### 2.1 Une séance planifiée ne pouvait jamais être vue

`app_learning_upsert_session` crée la séance avec le statut par défaut de la colonne, soit `draft`, et ne le modifie jamais. Or `app_learning_list_available_sessions` ne retourne que `scheduled`, `approved` et `running`.

Une séance planifiée pour la semaine prochaine restait donc invisible aux étudiants jusqu'à son démarrage effectif. La section « à venir » ne pouvait rien afficher, jamais.

**Correction** : nouvelle RPC `app_learning_set_session_status(p_session_id, p_status)`, réservée à l'hôte, limitée à `draft`, `scheduled` et `cancelled`. Le passage à `running` reste à `start_session` et à `ended` à `end_session`, pour que les horodatages réels soient toujours posés. Une séance en cours ou terminée ne peut pas revenir en arrière.

Choix assumé : ajout additif plutôt que réécriture de l'upsert. Le brouillon reste un état utile — l'enseignant prépare, puis publie.

**Vérifié** par 10 contrôles enchaînés avec simulation de JWT : création en brouillon → invisible (0 séance listée) → publication → visible (1 séance) → un non-hôte ne peut ni publier ni annuler → démarrage → retour arrière refusé.

### 2.2 Aucun cours en ligne ne pouvait être créé

Découvert en tentant d'insérer le cours de démonstration :

```
ERROR 42703: record "new" has no field "is_active"
CONTEXT: app_notify_online_course_created() line 4
```

Le déclencheur `trg_app_online_courses_notify` est `AFTER INSERT FOR EACH ROW` et teste `NEW.is_active` — colonne qui n'existe pas sur `app.online_courses`. La colonne visée était `is_published`.

**Conséquence** : depuis l'existence de ce déclencheur, ni un administrateur ni un formateur ne pouvait créer un cours en ligne. L'écran de création échouait systématiquement.

### 2.3 Aucune leçon ne pouvait être créée

Même famille, en pire. `app_notify_online_course_lesson()` contenait **trois** références erronées :

| Référence | Réalité |
|---|---|
| `NEW.is_active` | la colonne est `is_published` |
| `NEW.course_id` | `online_course_lessons` porte `section_id`, pas `course_id` |
| `e.user_id` | `online_course_enrollments` porte `student_id` |

**Conséquence** : les 0 leçons constatées en base n'étaient pas un oubli de saisie. C'était une impossibilité technique. Personne n'aurait jamais pu en créer une.

**Correction des deux** : colonnes corrigées, résolution du cours via la section, et surtout **notification isolée dans un bloc d'exception**. Une notification qui échoue ne doit jamais empêcher la création de l'objet métier. C'était le vrai défaut de conception : un effet de bord accessoire faisait tomber l'opération principale.

---

## 3. Ce qui a été livré

### 3.1 Écran enseignant — `TeacherLiveSessionsScreen`

Nouveau fichier `lib/features/instructor/teacher_live_sessions_screen.dart`, branché comme troisième sous-onglet « Studio unifié » dans « Mes classes en direct ». Les deux flux existants (Cours en ligne, Prépa concours) sont **inchangés** — aucune régression possible sur des parcours déjà validés.

Cycle de vie exposé :

```
brouillon ──publier──> planifiée ──démarrer──> en cours ──terminer──> terminée
     ^                     │
     └────remettre─────────┘
```

Le formulaire couvre : type de séance (6 choix), rattachement à un cours, titre, description, matière, date et heure, durée, participants maximum, et les six options de séance (chat, quiz, tableau blanc, partage d'écran, main levée, enregistrement).

L'option d'enregistrement porte un avertissement explicite sur le quota de transcodage LiveKit — 60 minutes par mois sur l'offre gratuite. C'est le poste qui déclenchera le passage à l'offre payante, autant que l'enseignant le sache au moment où il coche.

La liste sépare les séances en cours, publiées, brouillons et passées, avec un libellé qui dit exactement ce qui est en jeu : « Brouillons — invisibles pour les étudiants ».

### 3.2 Onglet Lives étudiant — repointé

`StudentLiveSessionsTab` réécrit :

| | Avant | Après |
|---|---|---|
| Source | `app_student_list_my_online_course_live_sessions` | **`app_learning_list_available_sessions`** |
| Portée | cours en ligne seulement | cours, TD, prépa, orientation, masterclass |
| Session ouverte | objet fabriqué à la volée, `hostId` vide | objet réel renvoyé par la base |
| Jointure | aucune | `app_learning_join_session` avant d'entrer |
| Structure | liste plate | en direct · à venir · legacy |

Ajouts : filtres par type, pastilles indiquant les fonctionnalités actives de chaque séance, formulation relative du temps (« aujourd'hui à 18h00 », « demain à 09h00 »).

L'ancienne source est conservée dans une section distincte le temps de la convergence — pas de rupture pour les séances déjà planifiées.

Point important : l'appel à `joinSession` avant d'entrer crée la ligne dans `academia_session_participants`. C'est **ce qui rend le chat persistant fonctionnel** : les RPC de chat livrées en vague 0 vérifient l'appartenance par cette table.

### 3.3 Cours de démonstration

`[DEMO] Analyse — Suites numériques`, publié, 2 chapitres, 4 leçons :

- Chapitre 1 — Définitions et premiers exemples (2 leçons)
- Chapitre 2 — Convergence (2 leçons)

Retrait en une instruction : `tools/cleanup_demo_course.sql`.

---

## 4. Protocole de recette — le premier vrai live

À faire dans cet ordre. Chaque étape valide une couche précise.

### Préalable

`flutter analyze` puis build et déploiement depuis un poste Windows. Le SDK du dépôt est en fins de ligne Windows et ne s'exécute pas sous Linux — mon contrôle statique (équilibrage des délimiteurs, symboles importés) ne remplace pas le compilateur.

### Étape 1 — L'enseignant crée et publie

1. Compte formateur → onglet « Mes classes en direct » → sous-onglet **« Studio unifié »**
2. « Créer une séance » → type **Cours**, rattacher au cours `[DEMO]`, titre libre, début dans 10 minutes, mode Classe, options chat + quiz + tableau blanc activées, **enregistrement désactivé**
3. « Créer en brouillon » → la séance apparaît sous « Brouillons »
4. **« Publier »** → elle bascule sous « Publiées »

*Valide* : `app_learning_upsert_session`, `app_learning_set_session_status`.

### Étape 2 — L'étudiant la voit

5. Compte étudiant, autre appareil → onglet **Lives**
6. La séance doit apparaître sous « À venir », avec le nom de l'enseignant et l'horaire relatif

*Valide* : `app_learning_list_available_sessions`, la correction du statut de publication.

**Si elle n'apparaît pas** : vérifier que le statut est bien `scheduled` et non `draft`.

### Étape 3 — Le live

7. Enseignant → **« Démarrer »** → la salle s'ouvre, caméra active
8. Étudiant → la séance passe en « En direct maintenant » → **« Rejoindre »**

*Valide* : `start_session`, `join_session`, `livekit-token` v46, la bascule LiveKit Cloud, la connexion au SFU.

### Étape 4 — Le Studio lui-même

9. **Chat** : écrire des deux côtés. Les messages doivent apparaître en temps réel **et survivre à une fermeture-réouverture de l'écran** — c'est ce qui distingue le chat persistant du chat éphémère.
10. **Participants** : l'enseignant ouvre le panneau, voit l'étudiant, teste la coupure de micro à distance
11. **Tableau blanc** : l'enseignant écrit, l'étudiant voit
12. **Partage d'écran** côté enseignant

*Valide* : les RPC de chat de la vague 0, `livekit-admin`, les canaux de données LiveKit.

### Étape 5 — Le réseau

13. Passer l'appareil étudiant du wifi aux données mobiles pendant la séance. La vidéo doit se dégrader progressivement, pas se figer — c'est `adaptiveStream` et `dynacast`, activés en vague 0.

### Étape 6 — La fin

14. Enseignant → « Terminer » → la séance passe en « Passées »
15. Consigner le résultat dans `docs/ACADEMIA_CHANGELOG.md`

---

## 5. Ce qui ne marchera pas, et c'est attendu

Ces deux points sont connus, documentés, et relèvent de la vague 1b. Ils ne sont pas des surprises.

**Les étudiants ne pourront ni activer leur micro ni leur caméra.** `livekit-token` accorde `canPublish: isHost`. Les boutons sont visibles côté étudiant et échoueront en silence. C'est le point numéro un de la vague 1b — le modèle de droits de publication appartient à la matrice de capacités, et le modifier sans avoir jamais testé un live réel aurait été un pari.

**N'importe qui connaissant un identifiant de session peut entrer.** `livekit_lookup_academia_session` et `join_session` ne vérifient ni inscription ni invitation. À traiter dans `studio_resolve_session`, avec le modèle de visibilité déjà prévu par l'architecture.

Trois autres limites, moindres :

- Les **replays** n'apparaissent pas : `list_available_sessions` ne retourne pas les séances `ended`. Vague 3.
- Les **quiz** échoueront : les 4 RPC n'existent pas encore. Vague 2.
- L'onglet **Cours** affichera le cours de démonstration et ses 4 leçons, mais le lecteur de leçon reste à construire. Vague 1c.

---

## 6. Ce qui a changé

**Supabase** — 4 migrations

| Migration | Objet |
|---|---|
| `add_academia_session_publish_transition` | RPC de publication |
| `fix_notify_online_course_created_missing_column` | Création de cours débloquée |
| `fix_notify_online_course_lesson_wrong_columns` | Création de leçon débloquée |
| `seed_demo_online_course_for_studio_test` | Cours de démonstration |

**Flutter**

- `lib/features/instructor/teacher_live_sessions_screen.dart` — nouveau
- `lib/features/student/tabs/student_live_sessions_tab.dart` — réécrit
- `lib/providers/academia_session_provider.dart` — méthode `setSessionStatus`
- `lib/features/instructor/instructor_dashboard_screen.dart` — troisième sous-onglet

**Outillage**

- `tools/cleanup_demo_course.sql` — nouveau

Non commité, comme pour la vague 0.

---

## 7. Lecture

La vague 0 avait montré que le problème du Studio Live n'était pas propre au Studio Live. La vague 1a le confirme, sous une autre forme.

Les trois bugs trouvés aujourd'hui partagent une même signature : **un effet de bord accessoire qui fait tomber l'opération principale**. Une notification mal écrite empêche de créer un cours. Une autre empêche de créer une leçon. Un statut par défaut jamais modifié rend invisible tout ce qu'on planifie.

Aucun de ces trois n'aurait été trouvé par un audit statique ou une relecture. Ils ne se révèlent qu'en exécutant réellement le parcours — ce que personne n'avait fait, parce que le parcours n'était pas branché.

C'est l'argument le plus fort en faveur de l'étape suivante : **faire le live pour de vrai**. Il fera tomber en cascade ce qu'aucune lecture de code ne peut voir.
