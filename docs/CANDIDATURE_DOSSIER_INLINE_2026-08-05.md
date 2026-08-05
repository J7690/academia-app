# Candidature — compléter son dossier sans quitter l'écran (05/08/2026)

## Le problème, mesuré

Un étudiant sur le mini-site d'une université tape « Candidater », remplit les
5 champs de la demande, valide — et reçoit un SnackBar :
`Champs manquants : bepc_mention, study_project_text`. Sa saisie est perdue, le
message nomme des colonnes SQL, et le profil se trouve sur un autre onglet du
tableau de bord. Il doit abandonner sa candidature pour aller le remplir.

Relevé en production le 05/08/2026 :

```
224 étudiants inscrits
  7 ont un dossier complet          (3 %)
217 sont bloqués s'ils candidatent  (97 %)

 31 candidatures au total
  7 étudiants distincts ont candidaté  ← exactement les 7 dossiers complets

135 nouveaux étudiants sur 30 jours → 8 candidatures
```

Le verrou n'était pas un cas limite : personne ne le franchissait sauf ceux qui
l'avaient déjà franchi.

## Où est le verrou

`app_create_application()` appelle `app_is_student_dossier_complete()`, qui
exige **12 champs** non vides :

`full_name` · `date_of_birth` · `bepc_year` · `bepc_institution` ·
`bepc_country` · `bepc_mention` · `bac_year` · `bac_series` · `bac_mention` ·
`bac_institution` · `bac_country` · `study_project_text`

Les documents du dossier sont explicitement **non bloquants** (commentaire dans
la fonction). Téléphone, ville, pays, bio ne bloquent pas non plus — alors que
l'écran profil les présente au même niveau que les 12 autres.

**Aucune modification n'a été faite en base.** `app_is_student_dossier_complete()`
était déjà exécutable par le rôle `authenticated` : l'app peut l'appeler telle
quelle.

## Ce qui a changé

### Le parcours

1. Au tap sur « Candidater », l'app appelle `app_is_student_dossier_complete()`.
2. Dossier complet → rien ne change, le formulaire de candidature s'ouvre.
3. Dossier incomplet → une feuille modale s'ouvre **sur place**, en 3 étapes
   (Identité / BEPC / Bac et projet), n'affichant que les champs réellement
   manquants. Une étape entièrement remplie est sautée.
4. À l'enregistrement, on **redemande au serveur** si le dossier est complet —
   `app_student_update_full_profile` répond « succès » même s'il manque encore
   des champs, donc son succès ne prouve rien.
5. Le formulaire de candidature s'enchaîne immédiatement.

**Filet en aval** : si le serveur refuse quand même à l'envoi, la même feuille
s'ouvre, puis **la candidature déjà saisie est renvoyée telle quelle**. Une
seule reprise, pas de boucle.

**Dégradation gracieuse** : si la vérification n'aboutit pas (réseau, RPC), on
laisse passer. Le serveur reste l'arbitre à l'envoi et le filet rattrape. Un
garde-fou qui bloque un étudiant hors ligne est pire que le mal.

**« Une seule fois » = l'état en base**, pas un drapeau local. Aucun booléen
« déjà vu » : si l'étudiant abandonne en cours de route, il doit revoir la
feuille.

### Décisions retenues

- **Mentions** : liste déroulante `Sans mention / Passable / Assez bien / Bien /
  Très bien`. Un étudiant simplement admis n'est plus bloqué par un champ libre
  qu'il ne sait pas remplir.
- **Libellés** : `bepc_mention` → « Mention du BEPC ». Plus aucun nom de colonne
  affiché à un étudiant.
- **Années bornées** (1950 → année courante + 1) : `app_student_update_full_profile`
  applique un COALESCE, une faute de frappe ne peut plus être effacée ensuite,
  seulement écrasée.

### Fichiers

| | |
|---|---|
| Nouveau | `academia_app/lib/features/student/dossier_fields.dart` — libellés, étapes, mentions |
| Nouveau | `academia_app/lib/features/student/dossier_completion_sheet.dart` — la feuille 3 étapes |
| Nouveau | `academia_app/lib/features/student/apply_to_program.dart` — l'orchestration, écrite une seule fois |
| Modifié | `academia_app/lib/providers/student_profile_provider.dart` — `DossierStatus`, `checkDossier()` |
| Modifié | `academia_app/lib/providers/student_applications_provider.dart` — `dossierIncomplete`, `missingFields` |
| Modifié | `academia_app/lib/features/student/student_university_site_screen.dart` |
| Modifié | `academia_app/lib/features/student/tabs/student_home_tab.dart` |

Les deux écrans portaient **deux copies du même bloc de 45 lignes**, qu'il
fallait corriger deux fois. Elles ont été remplacées par un appel à
`applyToProgram()`.

### Une source de vérité, et une seule

Les 12 règles ne sont **pas** réécrites en Dart. `dossier_fields.dart` ne fait
que nommer et regrouper ce que le serveur signale. Si le verrou change en base
et exige un champ inconnu du formulaire, celui-ci **le dit** (« Information
supplémentaire demandée : … ») au lieu de l'ignorer en silence.

## Vérification

```
flutter analyze  → 0 erreur ; 0 remarque sur les 3 nouveaux fichiers
                   (les 4 restantes sur les fichiers modifiés sont préexistantes)
flutter build apk --debug → Built build\app\outputs\flutter-apk\app-debug.apk (298,6 s)
```

**Reste à faire, et non fait ici** : le parcours réel sur un compte de test à
dossier vide — candidater, remplir la feuille, vérifier que la candidature
part sans re-saisie. Aucune de ces deux commandes ne prouve le comportement.

## Dettes repérées, laissées en l'état

- `app_create_application` existe en **deux surcharges** en production : celle à
  8 arguments (utilisée) et une ancienne à 2 arguments (morte). L'app vise la
  première par ses paramètres nommés.
- `app_student_update_full_profile` applique `COALESCE(p_x, s.x)` : **un champ
  ne peut jamais être vidé** une fois saisi, seulement écrasé. C'est la raison
  du bornage des années côté formulaire.
