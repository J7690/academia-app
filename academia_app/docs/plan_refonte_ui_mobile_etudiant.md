# Plan de refonte UI mobile – Utilisateur étudiant

## 0. Contexte et objectif

- Application Academia déjà fonctionnelle (web + mobile).
- Objectif : refonte/amélioration **UI seulement** pour les écrans de téléphone côté étudiant, sans modification :
  - des routes,
  - des modèles de données,
  - des services/API,
  - du comportement web.
- Référence d’inspiration : Khan Academy, Coursera, Udemy, LinkedIn Learning/Jobs, TikTok (challenges vidéo), Pinterest (grilles catalogues).

---

## Étape 1 – Audit & cadrage étudiant (UI + règles internes)

1. Lecture des règles internes dans `.windsurf` :
   - `rules.md`
   - `METHODS_CLEAR_GUIDE.md`
   - `validation_workflow.md` et directives Windsurf associées (WINDSURF_*)
2. Intégration des principes ROL / méthodes de travail dans la façon d’intervenir.
3. Inventaire précis des écrans étudiant :
   - Accueil étudiant
   - Programmes / Formations / Cours
   - Candidatures
   - Opportunités
   - Communautés
   - Challenges + Vidéos challenges
   - Universités partenaires
   - Cours & Formations en ligne
   - Lives
4. Cartographie des fichiers Dart correspondants dans `academia_app/lib/...`.
5. Cartographie « Web vs Mobile » pour chaque écran :
   - comment l’écran est rendu aujourd’hui (web/mobile),
   - où se situe la logique responsive existante (le cas échéant).

---

## Étape 2 – Cadre technique mobile (isMobile, layout de base)

1. Centralisation d’une fonction utilitaire de détection mobile, basée sur `MediaQuery` ou `LayoutBuilder` :
   - `< 600 px` → mise en page **mobile**,
   - `>= 600 px` → mise en page **existante** (web / tablette).
2. Mise en place de composants de base pour le mobile :
   - conteneur mobile standard (fond gris clair, padding, `SafeArea`),
   - layout de page verticale scrollable (`SingleChildScrollView` ou `ListView` correctement contraint),
   - styles de cartes réutilisables (fond blanc, ombre légère, typographie mobile).
3. Encapsulation web vs mobile :
   - identification pour chaque écran du widget actuel (web/commun) et du futur widget mobile dédié (suffixe `Mobile`),
   - mise en place de la sélection `if (isMobile) ... else ...` au bon niveau **sans toucher à la logique métier**.

---

## Étape 3 – Barre de navigation du bas mobile (Option A)

1. Création d’un composant dédié (ex. `MobileBottomNavBarScrollable`) :
   - `ListView` ou `SingleChildScrollView` horizontal,
   - icônes et labels agrandis,
   - padding suffisant pour un confort tactile,
   - gestion de l’état actif (couleur principale Academia).
2. Intégration **uniquement sur mobile** :
   - branchement de la barre scrollable si `isMobile == true`,
   - conservation **telle quelle** de la barre actuelle sur web/tablette.
3. Respect des contraintes :
   - barre fixée en bas, respectant `SafeArea`,
   - ne masque pas de contenu important,
   - navigation (routes, identifiants d’onglets) strictement inchangée.

---

## Étape 4 – Refonte UI mobile de l’accueil étudiant

1. Création d’un widget `StudentHomePageMobile` (nom à ajuster selon le code existant) :
   - sections type Khan Academy / Coursera :
     - Mes formations
     - Mes candidatures
     - Opportunités
     - Challenges
     - Universités partenaires
   - chaque section : titre clair + 2–3 éléments + éventuel lien/bouton « Voir tout ».
2. Layout :
   - page verticale scrollable,
   - fond gris clair, cartes blanches,
   - marges verticales régulières.
3. Brancher `StudentHomePageMobile` **uniquement** sur mobile via `isMobile`, en conservant l’accueil actuel pour le web.

---

## Étape 5 – Refonte UI mobile Programmes / Formations / Cours

1. Création de variantes mobiles des listes (ex. `ProgramsListMobile`, `CoursesListMobile`, etc.).
2. Cartes type Coursera/Udemy :
   - titre du programme,
   - université,
   - ville/pays,
   - niveau (Licence/Master/Doctorat…) sous forme de `Chip` dans un `Wrap`,
   - bouton d’action principal à droite (`Voir`, `Accéder`, `Candidater`).
3. Possibilité de grilles légères à la Pinterest pour les catalogues, en restant sobre et lisible.
4. Respect des règles techniques :
   - éviter les `height`/`width` fixes non nécessaires,
   - `TextOverflow.ellipsis` pour les titres longs,
   - tests sur plusieurs largeurs pour garantir l’absence d’overflow.

---

## Étape 6 – Refonte UI mobile Candidatures & Opportunités

1. Candidatures :
   - listes de cartes compactes avec :
     - titre « Candidature XYZ »,
     - programme + niveau,
     - université,
     - date de création/soumission,
     - badge de statut (Brouillon, Soumise, En étude, Acceptée, etc.).
2. Opportunités (stages/emplois) :
   - cartes type LinkedIn Jobs :
     - titre du poste,
     - organisation,
     - ville/pays,
     - tags (stage, temps plein, etc.),
     - bouton « Postuler ».
3. Réutiliser la logique existante de candidature/postulation (aucun changement métier),
   - uniquement refonte visuelle et ergonomique.

---

## Étape 7 – Refonte UI mobile Communautés & Universités partenaires

1. Communautés :
   - listes avec cartes plus aérées,
   - accent sur titre + type de communauté,
   - éventuellement indicateurs secondaires (membres, activité) en petit.
2. Universités partenaires :
   - cartes façon Coursera :
     - nom,
     - ville/pays,
     - tags (Licence, Master, Doctorat),
     - éventuellement quelques programmes listés en texte compact.
3. Variantes mobiles dédiées branchées via `isMobile`, sans toucher aux écrans web.

---

## Étape 8 – Refonte UI mobile Challenges & Vidéos challenges

1. Liste de challenges :
   - cartes avec :
     - titre,
     - type/catégorie,
     - participants,
     - statut.
2. Vidéos challenges :
   - cartes vidéo inspirées de TikTok mais intégrées à la charte graphique Academia :
     - focus sur la vidéo,
     - titre court,
     - auteur/challenge associé,
     - actions déjà existantes (like, etc.).
   - pas de feed plein écran dans un premier temps.
3. Respect strict des règles techniques (pas de hauteurs fixes brutes, gestion du scroll, `SafeArea`, pas d’overflow).

---

## Étape 9 – Refonte UI mobile Cours/Formations en ligne & Lives

1. Cours / Formations en ligne :
   - séparer clairement dans l’UI :
     - « Mes cours / formations »,
     - « Catalogue ».
   - cartes compactes avec :
     - titre,
     - plateforme/université,
     - état/progression (si disponible),
     - bouton principal (`Ouvrir`, `Accéder`, `Messages`).
2. Lives / Sessions en direct :
   - cartes revues pour :
     - éviter toute erreur `BOTTOM OVERFLOWED BY XX PIXELS`,
     - utiliser `Wrap` pour les tags,
     - ne pas fixer de hauteur brute.
3. Widgets mobiles dédiés, activés uniquement sur mobile.

---

## Étape 10 – Tests responsive finaux & documentation

1. Batterie de tests UI mobile :
   - largeurs cibles : 320 px, 360 px, 390 px, 414 px,
   - correction de tous les :
     - `BOTTOM OVERFLOWED BY XX PIXELS`,
     - overflows horizontaux,
     - truncations problématiques.
2. Vérification de non-régression web (>= 600 px) :
   - rendu identique à l’existant,
   - pas de modification de routes,
   - pas de changement métier.
3. Documentation finale :
   - description des nouveaux widgets mobiles,
   - résumé des règles responsive (isMobile),
   - patterns de cartes/listes,
   - lien explicite avec les règles `.windsurf` / ROL pour les futures évolutions.

---

## État d’avancement – Refonte UI mobile étudiant

- Étapes 1 à 9 : plan définies et implémentées dans le code Flutter côté étudiant (UI uniquement, sans changement métier).
- Les écrans mobiles suivants disposent maintenant de variantes ou d’adaptations dédiées :
  - Accueil étudiant (onglet mobile dédié).
  - Listes de cours / formations et opportunités.
  - Communautés, universités partenaires, challenges.
  - Formations en ligne et lives (validation responsive).
- Les détails techniques et fichiers impactés sont documentés dans `.windsurf/audit/last_audit.md` (sections Étapes 2 à 10).
- Les tests visuels finaux multi-devices (320/360/390/414 px, vrais appareils/émulateurs) restent à réaliser côté développeur pour confirmer l’absence d’overflow dans toutes les configurations réelles.
