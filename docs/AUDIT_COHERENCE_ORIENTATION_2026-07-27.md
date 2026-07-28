# Audit de cohérence — module Orientation

**Date :** 27 juillet 2026
**Périmètre :** conseiller ↔ Supabase, conseiller ↔ interface administrateur, conseiller ↔ parcours élève.

---

## 1. Ce qui a été vérifié, et comment

L'audit ne s'est pas contenté de lire le code : chaque maillon a été éprouvé
en base, en se plaçant successivement dans la peau de l'élève, du conseiller
et de l'administrateur (jeton JWT simulé), puis le jeu d'essai a été détruit.

| Axe | Méthode | Résultat |
|---|---|---|
| Contrat Dart → Supabase | Extraction des 697 appels `rpc()` du code Flutter et des Edge Functions, confrontés au catalogue réel | **17/17** RPC d'orientation présentes |
| Grants et RLS | Inspection des privilèges sur les 4 tables d'orientation | Conformes à la convention du schéma `app` |
| Chaîne élève → conseiller | Réservation réelle jouée de bout en bout | **10/10** étapes validées |
| Interface administrateur | Vérification des actions réellement câblées | 2 défauts corrigés |
| Parcours élève | Recherche du point d'entrée dans la navigation | **1 défaut bloquant corrigé** |

Les 6 RPC absentes du catalogue (`app_learning_quiz_*`, `app_learning_*replay*`)
sont les chantiers déjà planifiés des vagues 2 et 3 — hors périmètre.

---

## 2. Le défaut bloquant : l'élève n'avait aucun accès à l'orientation

`orientation_screen.dart` — 1 565 lignes, entièrement fonctionnelles —
n'était importé par **aucun** fichier de l'application. L'écran existait, les
RPC répondaient, le conseiller disposait de son tableau de bord, mais aucun
élève ne pouvait atteindre le module. Toute la chaîne aboutissait à une
impasse.

**Correction.** L'orientation devient l'onglet 10 du tableau de bord élève,
présent dans les deux barres de navigation (mobile et large écran), avec son
libellé enregistré pour le suivi d'usage.

C'est le genre de rupture qu'aucun test unitaire ne signale : chaque pièce
fonctionne, seul le raccordement manque.

---

## 3. Chaîne élève → conseiller : validée de bout en bout

Une réservation complète a été jouée en base puis effacée.

| # | Étape | Résultat |
|---|---|---|
| 1 | L'élève reçoit les créneaux du conseiller | `2026-07-27 10:30+00` |
| 2 | La réservation est créée | ✔ |
| 3 | La consultation apparaît dans l'onglet **Lives** de l'élève | ✔ |
| 4 | Elle figure dans « mes rendez-vous » côté élève | 1 |
| 5 | Elle figure dans « mes rendez-vous » côté conseiller | 1 |
| 6 | Le conseiller peut ouvrir le dossier de l'élève | ✔ |
| 7 | Les statistiques du conseiller se mettent à jour | `a_venir: 1, aujourdhui: 1, plages_hebdo: 5` |
| 8 | L'élève est inscrit comme participant de la salle | ✔ |
| 9 | La session est créée au bon type, hébergée par le conseiller | `type=orientation`, hôte = conseiller |
| 10 | Nettoyage | 0 ligne résiduelle |

Le point 8 mérite d'être souligné : sans cette inscription, le contrôle
d'appartenance du salon persistant aurait rejeté l'élève à l'entrée de sa
propre consultation.

---

## 4. Interface administrateur : deux angles morts

### 4.1 L'administrateur ne voyait que des comptes, jamais des conseillers

L'onglet « Conseillers » listait les comptes d'authentification portant le
rôle. Il ne disait rien de l'état métier : profil rempli, créneaux posés,
conseiller actif. Autrement dit, l'administrateur pouvait créer un conseiller
sans jamais savoir s'il était réellement réservable — et c'est précisément le
cas de `conseille@gmail.com`, actif mais sans aucun créneau, donc invisible
des élèves.

**Correction.** Nouvelle RPC `app_admin_list_orientation_counselors`, qui
croise le compte, le profil d'orientation, les créneaux, les rendez-vous, les
fiches et le solde. L'onglet affiche désormais une pastille **Réservable /
Non réservable** et explique ce qui manque le cas échéant.

### 4.2 Une RPC existait sans commande pour l'appeler

`app_admin_set_orientation_counselor_active` était en base depuis la création
du module, appelée par aucune ligne de Dart. L'administrateur pouvait créer un
conseiller mais jamais le retirer de la recherche des élèves.

**Correction.** Bouton Désactiver / Réactiver, avec confirmation explicite sur
ce que l'action entraîne (disparition de la recherche, conservation des
rendez-vous et des fiches).

---

## 5. Dérives de cohérence corrigées

**Libellés dupliqués.** Les tables de correspondance des types de conseiller,
des spécialités et des langues étaient redéfinies six fois dans le formulaire
administrateur, en double du fichier `orientation_theme.dart`. Un ajout d'un
seul côté aurait produit un libellé vide chez l'autre. Les six copies sont
supprimées au profit de `OrientationLabels`.

**Débordements sur écran étroit.** Deux boîtes de dialogue de l'administrateur
conservaient une largeur fixe (400 et 420 px) : sur un téléphone de 320 dp,
elles débordaient. Remplacées par `double.maxFinite`, qui laisse la boîte de
dialogue imposer sa contrainte.

---

## 6. Points sains confirmés

- **Grants.** Les 4 tables d'orientation portent exactement les privilèges des
  tables sœurs du schéma `app`. RLS actif sans politique : l'accès passe
  uniquement par les fonctions `SECURITY DEFINER`, comme prévu.
- **Créneaux.** `app_orientation_set_my_availability` purge avant d'insérer :
  aucun risque de doublon, malgré l'absence de contrainte d'unicité.
- **Séparation des rôles.** Zéro compte portant le rôle sans profil, zéro
  profil sans le rôle. La création et la promotion laissent la base cohérente.
- **Studio de live.** Le conseiller entre dans la salle en hôte
  (`isHost: true`), avec le tableau blanc ; l'élève y entre en participant.
- **Providers.** Les quatre providers du parcours sont enregistrés.

---

## 7. Ce qui reste à faire, côté humain

1. **`flutter pub get` puis `flutter analyze`** depuis Windows — le SDK du dépôt
   ne s'exécute pas dans l'environnement Linux.
2. **`conseille@gmail.com` n'est pas encore réservable** : 0 spécialité, 0
   créneau. Le conseiller doit compléter son profil et poser ses créneaux
   depuis son propre compte. L'onglet administrateur le signale désormais.
3. **Une session d'orientation orpheline** subsiste (`Original`, terminée,
   créée le 26 juillet) : vestige d'un essai manuel avec l'ancien formulaire
   enseignant. Sans effet, l'orientation ayant été retirée de ce menu.

---

## 8. Fichiers touchés

**Base de données**

- `add_admin_orientation_counselors_supervision`
- `fix_admin_orientation_counselors_raise`

**Flutter**

- `lib/features/student/student_dashboard_screen.dart` — onglet Orientation raccordé
- `lib/features/admin/admin_accounts_screen.dart` — supervision, activation, libellés unifiés, largeurs fixes
