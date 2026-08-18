# Candidature — des dialogues qui disent le problème et quoi faire (14/08/2026)

Suite directe de `CANDIDATURE_DOSSIER_INLINE_2026-08-05.md`. Le parcours
« Candidater » était sain dans sa logique (vérification du dossier en amont,
filet en aval) mais muet dans sa communication : les usagers ne comprenaient
pas pourquoi ça bloquait, ni quoi faire.

## Ce qui a été mesuré

- **Tous les retours passaient par des SnackBars** furtifs (4 s, bas d'écran) —
  succès comme échecs (`apply_to_program.dart`, avant modification).
- **Des codes bruts atteignaient l'écran.** Lecture des définitions RPC en
  production (scripts lecture seule `.windsurf/tmp_audit_candidature_rpc_defs.py`
  et `tmp_audit_list_apps_def.py`) : `app_create_application` peut renvoyer
  `verification_failed`, « Profil étudiant introuvable », ou tout `SQLERRM`
  brut ; côté Dart s'ajoutait `e.toString()` pour les erreurs réseau.
- **Aucune protection « déjà candidaté »** : le RPC ne vérifie pas les doublons.
- **Aucun retour visuel** pendant `checkDossier()` et l'envoi (taps répétés sur
  réseau lent).
- **Boutons « Candidater » grisés sans explication** quand `program_id` manque.
- **Impasse onglet partenaires** : la feuille « Programmes proposés » listait
  les formations sans aucune action pour candidater.

## Ce qui a été décidé (validé par Jocelyn le 14/08)

Périmètre **Flutter uniquement**, Supabase intouché.

| Fichier | Changement |
|---|---|
| `application_outcome_dialog.dart` (nouveau) | 3 dialogues : succès (+ « Suivre ma candidature »), « déjà candidaté » (+ re-candidature si refusée/annulée), problème (titre, cause, quoi faire, détail technique replié, « Réessayer ») |
| `apply_to_program.dart` | garde « déjà candidaté » avant toute saisie ; attente visible (`_withProgress`) sur chaque appel réseau ; issue annoncée par dialogue, plus de SnackBar ; traduction des codes serveur (`_describeFailure`) |
| `student_partners_tab.dart` | bouton « Candidater » sur chaque programme de la feuille (appelle `applyToProgram`) |
| `student_home_tab.dart`, `student_university_site_screen.dart` | bouton jamais grisé sans explication : dialogue « Candidature indisponible » quand `program_id` manque |
| `notification_router.dart` | **hors périmètre initial** : retour à `_screenForDomain(domain)` seul — le commit 97bcfce (13/08) appelait `_screenForData(data)` sans committer la méthode, ce qui cassait tout build. Décision de Jocelyn. La navigation fine par `data` reste à réécrire. |

Principe des dialogues : **ce qui s'est passé, pourquoi, quoi faire** — le
détail technique existe mais replié, pour le support, jamais comme message
principal.

## Ce qui a été écarté, avec motif

- **Inverser l'ordre (formulaire d'abord, profil ensuite)** : contredirait la
  décision motivée du 05/08 (« l'étudiant ne saisit jamais pour rien »).
- **Vérification des doublons côté serveur** : toucherait la base ; la garde
  client suffit comme confort, et reste non bloquante si la liste ne charge pas.
- **Drapeau local « déjà vu »** : la source de vérité reste l'état en base
  (décision du 05/08 maintenue).

## Vérification

```
flutter analyze          → 0 erreur sur les fichiers touchés (le dépôt porte
                           des warnings préexistants ailleurs)
flutter build apk --debug → √ Built build\app\outputs\flutter-apk\app-debug.apk (377,7 s)
```

## Reste non vérifié, nommément

- Le **parcours réel** sur un compte étudiant : déjà-candidaté → dialogue ;
  dossier vide → feuille ; envoi → dialogue de succès → « Suivre ma
  candidature » ; coupure réseau → dialogue « Problème de connexion ».
- Le comportement de `_withProgress` si l'écran est démonté pendant l'attente
  (protégé par `navigator.mounted`, non exercé sur appareil).
- La navigation par notification après le retour à `_screenForDomain` (elle
  revient au comportement d'avant le 13/08, supposé fonctionnel).
