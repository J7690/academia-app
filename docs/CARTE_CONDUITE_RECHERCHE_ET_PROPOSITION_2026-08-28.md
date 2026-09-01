# Carte de conduite — candidats auto-école : recherche et proposition (28/08/2026)

> ## ⛔ PARTIELLEMENT RÉFUTÉ LE JOUR MÊME — ne pas implémenter §3
>
> Quelques heures après la rédaction de ce document, Jocelyn a fourni les
> **photos d'une carte de conduite papier réelle** (Harmonie Auto École, Nioko 2,
> Ouagadougou). L'objet réel **contredit la §3 de ce document** :
>
> | Ce que §3 proposait | Ce que la carte réelle contient |
> |---|---|
> | grille à 4 compétences (Codes Rousseau) | **aucune compétence** |
> | barème *Acquis / En cours / Non acquis* | **aucun barème** |
> | table `driving_skills`, référentiel | **rien de tel** |
> | heures requises (35 h) | **aucun total, aucun objectif affiché** |
> | catégories type « Permis B » | **deux cases : PL et VL** |
> | — | un tableau à **3 colonnes** : `DATE / HEURES / OBSERVATIONS` |
> | — | titre réel : **« RENDEZ-VOUS LEÇON DE CONDUITE »** |
> | — | emplacement **photo d'identité** collée |
> | — | couverture = **support de marque** (logo, camion, slogan, contacts) |
>
> **Cause de l'erreur** : la §4 de ce document nommait déjà l'angle terrain comme
> manquant (« aucune auto-école partenaire n'a été interrogée »). La proposition
> a quand même été rendue en important le standard français. Un manque signalé
> n'est pas un manque compensé.
>
> **Ce qui reste valable ici** : §1 (l'existant Academia), §2 (la veille — les
> sources et le constat que l'offre numérique burkinabè s'arrête à la théorie),
> §4 (les limites d'accès mesurées). **Ce qui est mort : §3 et §5.**
>
> ➡️ **Proposition qui fait foi** : voir le document daté qui lui succède, rédigé
> à partir de l'objet réel.

> Statut : **proposition, rien d'implémenté**. Aucune table créée, aucun écran
> touché. Ce document sert à ce qu'une prochaine séance ne refasse pas la
> recherche, et à ce que Jocelyn arbitre les points ouverts en §5.

## 0. Le sujet, tel que compris

Demande orale (28/08) : une fonctionnalité pour les candidats d'une auto-école
partenaire — une « carte de conduite » qui permet de **noter les séances
d'entraînement du candidat** — précédée d'une recherche sur comment les autres
auto-écoles (Burkina Faso, et par comparaison le marché plus mûr) présentent
cet objet, pour situer Academia par rapport à elles.

C'est un sujet **neuf** : aucune décision passée ne le concerne, aucun code
existant ne le couvre (cf. §1). Ce n'est pas une extension du Smart Whiteboard
ni du Studio 3D — c'est une troisième brique, sur le pan « auto-école » du
système de candidature qui existe déjà.

## 1. Ce qui existe déjà dans Academia — à ne pas reconstruire

| Existant | Où | Depuis |
|---|---|---|
| Un type de partenaire `partner_type` (`university` par défaut, `auto_ecole`) | migration citée dans `git show a3875b3` | 05/08/2026 |
| Onglet étudiant qui filtre établissements/offres par type, avec le vocabulaire « Permis de conduire », recherche « Permis B, Permis C... » | [student_partners_tab.dart](academia_app/lib/features/student/tabs/student_partners_tab.dart) | 05/08/2026 |
| Tout le parcours de candidature (dossier en 3 étapes, `apply_to_program()`, statuts `accepted`/`rejected`) — **générique**, déjà utilisé tel quel par les auto-écoles, sans code spécifique | [apply_to_program.dart](academia_app/lib/features/student/apply_to_program.dart), [admin_application_status.dart](academia_app/lib/features/admin/admin_application_status.dart) | 05/08/2026, cf. `docs/CANDIDATURE_DOSSIER_INLINE_2026-08-05.md` |
| Un tableau de bord partenaire déjà livré aux auto-écoles (même écran que les universités, aucune distinction de rôle) | [university_dashboard_screen.dart](academia_app/lib/features/university/university_dashboard_screen.dart) | avant 05/08/2026 |

Ce qui **n'existe pas** : toute notion de séance, de carnet, de compétence, de
moniteur, d'heures de conduite. Recherche exhaustive (`grep -i` sur tout le
dépôt pour `carte de conduite`, `moniteur`, `permis de conduire`, `séance
d'entraînement`, `carnet de formation`, `driving school/card/logbook`) : zéro
résultat applicatif. Aucune décision passée à contredire ici — le terrain est
libre, ce qui simplifie l'arbitrage mais ne dispense pas de le faire (§5).

**Compte partenaire unique** : le compte auto-école est aujourd'hui le même
compte « université » recyclé — pas de compte « moniteur » séparé. Toute
proposition qui suppose plusieurs comptes par instructeur ajoute une couche
qui n'existe pas encore (cf. §4, phasage).

## 2. Recherche externe — quatre angles

### 2.1 Le Burkina Faso aujourd'hui

**Cadre réglementaire** — DGTTM (Direction Générale des Transports Terrestres
et Maritimes) publie le *Programme National d'Enseignement du Permis de
Conduire* ; l'ONASER (Office National de la Sécurité Routière) forme et
sensibilise. Le parcours candidat : code de la route → créneau/manœuvre →
conduite, avec un **minimum de 35 h** de formation et un permis provisoire de
6 mois à l'issue.
Sources : [DGTTM — annexe programme national](https://dgttm.bf/images/_dgttm/_prod/doc_a_telecharger/reglementation_transport_routier/annexe_1_Programme_National_Enseignement_PC_VF.pdf) (citée par la recherche, **non lue** — voir limite ci-dessous), [Guide du Code de la Route Burkina Faso](https://www.scribd.com/document/467137922/Cours-de-code-2Ed4-pdf).

⚠️ **Limite mesurée, pas supposée** : le domaine `dgttm.bf` a échoué en DNS
(`getaddrinfo ENOTFOUND`) à deux tentatives distinctes depuis cet
environnement — inaccessible, pas « vide ». Même récupéré autrement, le PDF de
la fiche de suivi française équivalente (`azur-auto-ecole.com/doc/fiche_suivi.pdf`,
récupérée avec succès) s'est révélé être un **scan image**, illisible par
l'outil d'extraction disponible. **Les 35 h et les catégories d'examen
ci-dessus viennent des extraits indexés par la recherche web, pas d'une
lecture directe du texte réglementaire.** À confirmer avant d'en faire une
contrainte dure dans le produit (ex. jauge « 35 h requises »).

**Offres numériques existantes, recensées** :

| Offre | Ce qu'elle fait | Suivi de séances pratiques ? |
|---|---|---|
| [burkinapermis.com](http://www.burkinapermis.com/) | Cours de code en ligne, tests, inscription en auto-école, renouvellement de permis, forum | **Non** — aucune mention, confirmé par lecture de la page |
| [BF Auto École (Google Play)](https://play.google.com/store/apps/details?id=com.digagi.bf_auto_ecole) | Préparation à l'examen théorique (slides officielles) | Non — 100 % théorie |
| [Auto-École Kanaga](https://www.autoecolekanaga.com/), [Faso Auto-Moto](https://www.fasoauto-moto.com/auto-moto-ecole) | Sites vitrine, inscription en ligne | Non |
| [Code et Conduite 2025 (Stych)](https://apps.apple.com/fr/app/code-et-conduite-2025-by-stych/id1556454758) | Révision code (app francophone générique, pas spécifique BF) | Non |

**Constat, croisé sur les quatre sources** : chaque offre numérique burkinabè
trouvée s'arrête à la théorie et à l'administratif. Aucune ne fait ce que
demande la fonctionnalité visée — noter, séance après séance, la progression
pratique d'un candidat. Ce n'est pas une conclusion « il n'existe pas », c'est
une conclusion « non trouvée dans cette recherche » : une auto-école pourrait
tenir ce suivi en interne, sur papier, sans présence web — angle terrain
manquant, cf. §5.

### 2.2 Le marché mûr — France (référence utile : réglementé, documenté, comparable en langue)

Le **livret d'apprentissage numérique est obligatoire depuis le 1ᵉʳ janvier
2024** en France (remplace le papier). Trois éditeurs, trois angles :

- **Codes Rousseau** (quasi-institutionnel) — structure la formation autour de
  **4 compétences** : maîtriser le maniement du véhicule · appréhender la
  route en conditions normales · circuler en conditions difficiles ·
  pratiquer une conduite autonome, sûre et économique. Enregistre heures,
  moyen (boîte manuelle/automatique/simulateur), formule choisie.
  [Source](https://public.codesrousseau.fr/supports-apprentissage/conduite-en-voiture/le-livret-d-apprentissage-numerique/), consultée 28/08/2026.
- **Klaxo** (éditeur SaaS pour auto-écoles) — barème à **3 états par
  compétence et par séance** : *Acquis / En cours / Non acquis*, commentaire
  libre du moniteur, heures comptées automatiquement, examens blancs,
  émargement depuis le téléphone, facturation intégrée.
  [Source](https://klaxo.fr/livret-numerique-auto-ecole/), consultée 28/08/2026.
- **Mounki** — **trois applications séparées** : *Copilot* (élève, lecture
  seule de sa progression), *Assistant* (moniteur, saisie rapide synchronisée
  séance par séance), *Cockpit* (direction, pilotage et archivage).
  [Source](https://www.mounki.com/), consultée 28/08/2026.

Egalement recensé, la pratique papier qu'un livret numérique remplace : une
**fiche de suivi par élève**, conservée par l'auto-école, identité + catégorie
de permis + tableau chronologique des séances (référentiel dit « REMC »).
[Exemple (ENPC-Ediser)](https://www.enpc-ediser.com/produits/fiches-de-suivi-b-aac-cs-remc-reference-a4-20-fiches-par-paquet.html).
Un PDF concret d'une auto-école (`azur-auto-ecole.com`) a été récupéré mais
s'est avéré être un scan — non exploitable en détail, cf. limite en §2.1.

### 2.3 Le marché logiciel générique (hors francophonie)

Zutobi, Learnr Driver, drivinginstructormanager.com et comparables (marché
anglophone) convergent sur le même socle : *drive sheets*, heures de conduite
horodatées, notes d'instructeur, tableau de bord partagé élève/parent,
rappels automatiques ; quelques-uns ajoutent GPS et note vocale.
[Source (GetApp, comparatif)](https://www.getapp.com/education-childcare-software/driving-school/f/progress-tracking/), consultée 28/08/2026.

**Ce qui est confirmé en le croisant avec 2.2** : le socle (séance → heures +
compétences + commentaire, visible par l'élève) est stable sur deux marchés
indépendants (francophone réglementé, anglophone concurrentiel). Ce n'est pas
propre à la France ; ça généralise.

### 2.4 Dépôts publics / littérature

Angle pauvre : aucun dépôt open source de gestion de séances de conduite
identifiable comme référence pendant cette recherche, et aucune littérature
académique spécifique au sous-domaine (le sujet est un produit métier, pas un
champ de recherche). Le dit honnêtement plutôt que de le forcer — voir
`veille-externe` sur ce point.

## 3. Ce que je propose

### 3.1 Où ça s'accroche dans l'existant

Une carte de conduite se crée pour une candidature **déjà acceptée**
(`status = 'accepted'`) sur une offre dont l'institution a
`partner_type = 'auto_ecole'` — pas avant, pour rester cohérent avec le
verrou de dossier déjà en place (`docs/CANDIDATURE_DOSSIER_INLINE_2026-08-05.md`) :
on ne fait pas suivre un entraînement à quelqu'un qui n'est pas encore admis.

- **Côté auto-école** : un nouvel onglet dans le tableau de bord partenaire
  existant ([university_dashboard_screen.dart](academia_app/lib/features/university/university_dashboard_screen.dart)),
  listant ses candidats acceptés en formation, et permettant d'ajouter une
  séance en fin de leçon.
- **Côté étudiant** : une entrée « Ma carte de conduite », visible dès
  l'acceptation, à côté des onglets existants (`StudentApplicationsTab`).

### 3.2 Modèle de données (schéma `app.*`, à valider — rien d'exécuté)

Noms en anglais pour rester cohérent avec le schéma existant (`partner_type`,
`program_title`, `degree_level` sont tous en anglais alors que l'app est
francophone) :

```
app.driving_cards
  id, application_id (FK unique — une carte par candidature acceptée),
  student_id, institution_id, permit_category (text libre, ex: "B"),
  hours_required (int, valeur par défaut à confirmer — cf. limite §2.1),
  hours_completed (calculé depuis driving_sessions),
  status ('in_progress' | 'ready_for_exam' | 'completed'),
  created_at

app.driving_sessions
  id, card_id (FK), session_date, duration_minutes,
  vehicle_type ('manual' | 'automatic'),
  instructor_name (text libre — pas de table instructeur, cf. §1),
  skills (jsonb: [{skill_code, status: 'not_acquired'|'in_progress'|'acquired'}]),
  instructor_comment (text),
  created_by (auth.uid du compte partenaire), created_at

app.driving_skills   -- référentiel, pré-rempli, éditable sans déploiement
  code, label, category, sort_order
```

`driving_skills` démarre avec la grille à 4 axes de Codes Rousseau (§2.2),
**explicitement marquée comme provisoire** jusqu'à confrontation avec le
programme officiel burkinabè (§2.1, non lu). C'est une hypothèse de départ,
pas une conclusion.

### 3.3 Barème : reprendre le triptyque, pas inventer une note chiffrée

*Non acquis / En cours / Acquis* — c'est le choix convergent de Klaxo et du
livret français obligatoire (§2.2), plus rapide à saisir au téléphone en fin
de leçon qu'une note sur 10 ou 20, et plus lisible pour un candidat que de la
littérature ne compare pas à un examen classant.

### 3.4 Écrans

- **Fin de séance (compte auto-école)** : formulaire court — candidat (liste
  des acceptés), date pré-remplie, durée, compétences travaillées (puces à
  3 états), commentaire libre, enregistrer. Objectif : saisissable en moins
  d'une minute, sur le modèle de Mounki Assistant (§2.2) — sinon le moniteur
  ne l'utilisera pas.
- **Carte du candidat (compte étudiant)** : jauge heures faites/requises,
  grille des compétences avec statut coloré, historique des séances
  dépliables (commentaire du moniteur lisible). C'est l'objet qui justifie le
  nom « carte » — une vue de synthèse, pas seulement un journal.
- Notification push à l'enregistrement d'une séance : le pipeline existe déjà
  ([push_notification_service.dart](academia_app/lib/services/push_notification_service.dart)) — pas de nouvelle brique.

### 3.5 En quoi ça distingue Academia des autres écoles au Burkina Faso

D'après la recherche §2.1, **aucune offre numérique locale trouvée ne fait de
suivi de séances pratiques** — toutes s'arrêtent au code de la route et à
l'administratif. Le vide n'est pas comblé en copiant un concurrent burkinabè
(il n'y en a pas sur ce terrain précis, à date de cette recherche) mais en
importrant un standard déjà mûr ailleurs (§2.2/§2.3) et en le branchant sur
ce qu'Academia a déjà construit : le candidat n'installe rien de plus, ne
recrée pas de compte — la carte est la suite naturelle d'une candidature déjà
acceptée dans la même application. Les outils matures cités (Mounki, Klaxo)
sont au contraire des produits que l'auto-école doit acheter et faire adopter
séparément de son inscription.

### 3.6 Phasage suggéré

1. **MVP** : `driving_cards` + `driving_sessions`, compétences en texte libre
   (pas de référentiel figé) — pour apprendre si les auto-écoles s'en servent
   avant d'investir dans un référentiel validé.
2. **Référentiel validé** : `driving_skills` confronté au programme officiel
   burkinabè (nécessite d'avoir lu le PDF, §2.1) ; jauge d'heures fiable.
3. **Optionnel, si la demande existe** : comptes moniteurs multiples,
   émargement, examens blancs — fonctionnalités de Klaxo/Mounki non
   reprises ici faute de rôle « moniteur » existant (§1).

## 4. Ce qui reste non vérifié — à ne pas présenter comme tranché

- **Le programme officiel burkinabè n'a pas été lu** (domaine injoignable,
  puis PDF-scan illisible). Les 35 h et le référentiel à 4 axes sont des
  hypothèses de démarrage, pas une conformité vérifiée.
- **Aucune auto-école partenaire n'a été interrogée** sur sa pratique actuelle
  (carnet papier ? rien du tout ?) — recherche documentaire uniquement,
  l'angle « terrain » manque. Vaut la peine avant de figer l'écran de saisie.
- **Le volume d'auto-écoles agréées au Burkina Faso** (liste DGTTM) n'a pas pu
  être consulté — même blocage DNS. Utile pour dimensionner l'effort.

## 5. Décisions pour Jocelyn

1. **Nom** : garder « carte de conduite » (le mot du besoin exprimé), ou
   « carnet » — plus juste pour un journal de plusieurs séances, « carte »
   évoquant plutôt la vue de synthèse unique (§3.4 propose de garder les
   deux : une carte de synthèse, alimentée par un carnet de séances).
2. **Compte moniteur** : rester sur le compte partenaire unique (§1, plus
   rapide) ou ouvrir un chantier de comptes multiples par instructeur avant
   la V1 ?
3. **Référentiel de compétences** : démarrer en texte libre (phase 1, §3.6)
   ou attendre d'avoir le programme officiel avant d'écrire quoi que ce soit
   dans `driving_skills` ?
4. **Qui obtient le PDF DGTTM** — moi (autre voie que cet environnement) ou
   Jocelyn (contact direct DGTTM/ONASER, ou capture depuis un poste qui
   résout le domaine) ?

Rien de ce qui précède n'a été codé, migré ni committé.
